<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Assessor;
use App\Models\Center;
use App\Models\DocumentRecord;
use App\Models\DocumentSequence;
use App\Models\DocumentTemplate;
use App\Models\DocumentType;
use App\Models\PeiDocument;
use App\Models\RapDocument;
use App\Models\Setting;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;
use PhpOffice\PhpWord\TemplateProcessor;

class DocumentController extends Controller
{
    public function index(Request $request)
    {
        $query = DocumentRecord::with(['documentType:id,slug,name', 'user:id,name,email'])
            ->orderByDesc('created_at');

        if ($request->has('typeSlug')) {
            $type = DocumentType::where('slug', $request->input('typeSlug'))->first();
            if ($type) {
                $query->where('document_type_id', $type->id);
            }
        }

        return response()->json($query->get());
    }

    public function show(string $code)
    {
        $record = DocumentRecord::with('documentType:id,slug,name')->where('code', $code)->firstOrFail();
        return response()->json($record);
    }

    public function update(Request $request, string $code)
    {
        $record = DocumentRecord::where('code', $code)->firstOrFail();

        $validated = $request->validate([
            'payload' => 'sometimes|array',
            'received_at' => 'nullable|date',
        ]);

        if (isset($validated['payload'])) {
            $validated['payload'] = array_merge($record->payload ?? [], $validated['payload']);
        }

        $record->fill($validated);
        $record->save();

        return response()->json($record->load('documentType:id,slug,name'));
    }

    public function generate(Request $request, string $typeSlug)
    {
        $type = DocumentType::where('slug', $typeSlug)
            ->with('activeTemplate')
            ->firstOrFail();

        if (! $type->activeTemplate) {
            return response()->json(['error' => 'No active template for this document type'], 400);
        }

        $year = $type->codeYear();

        $number = $this->allocateNumber($type, $year);

        $code = $type->formatCode($number);

        $defaultCoordinator = Cache::remember('setting:DEFAULT_COORDINATOR_NAME', now()->addHours(1), fn () => Setting::where('key', 'DEFAULT_COORDINATOR_NAME')->value('value'))
            ?? 'TVET Coordinator';
        $defaultCoordinatorTitle = Cache::remember('setting:DEFAULT_COORDINATOR_TITLE', now()->addHours(1), fn () => Setting::where('key', 'DEFAULT_COORDINATOR_TITLE')->value('value'))
            ?? 'TVET Coordinator';
        $coordinatorName = $request->filled('coordinatorName')
            ? $request->input('coordinatorName')
            : $defaultCoordinator;
        $coordinatorTitle = $request->filled('coordinatorTitle')
            ? $request->input('coordinatorTitle')
            : $defaultCoordinatorTitle;

        $data = array_merge($request->all(), [
            'code' => $code,
            'year' => $year,
            'date' => $request->filled('date')
                ? $request->input('date')
                : now()->format('F j, Y'),
            'coordinatorName' => $coordinatorName,
            'coordinatorTitle' => $coordinatorTitle,
        ]);
        $data = $this->enrichAssessorLinkedPayload($type->slug, $data);

        $templatePath = Storage::path($type->activeTemplate->path);
        $outputFile = 'generated/'.$code.'-'.time().'.docx';
        $outputPath = Storage::path($outputFile);

        $processor = new TemplateProcessor($templatePath);
        foreach ($data as $key => $value) {
            $processor->setValue($key, (string) $value);
        }
        $processor->saveAs($outputPath);

        $record = DocumentRecord::create([
            'code' => $code,
            'year' => $year,
            'document_type_id' => $type->id,
            'template_id' => $type->activeTemplate->id,
            'user_id' => Auth::id(),
            'payload' => $data,
            'file_path' => $outputFile,
            'file_url' => '',
        ]);

        $record->file_url = '/api/v1/documents/'.$record->id.'/download';
        $record->save();

        $this->syncRelationalDocument($type->slug, $data, $record->code);

        ActivityLog::record(
            'document.generated',
            "Generated document {$record->code} ({$type->name})"
        );

        return response()->json($record->load('documentType:id,slug,name'), 201);
    }

    public function store(Request $request, string $typeSlug)
    {
        $type = DocumentType::where('slug', $typeSlug)
            ->with('activeTemplate')
            ->firstOrFail();

        $templateId = $type->activeTemplate?->id
            ?? DocumentTemplate::where('document_type_id', $type->id)->value('id')
            ?? 1;

        $year = $type->codeYear();

        $number = $this->allocateNumber($type, $year);

        $code = $type->formatCode($number);

        $defaultCoordinator = Cache::remember('setting:DEFAULT_COORDINATOR_NAME', now()->addHours(1), fn () => Setting::where('key', 'DEFAULT_COORDINATOR_NAME')->value('value'))
            ?? 'TVET Coordinator';
        $defaultCoordinatorTitle = Cache::remember('setting:DEFAULT_COORDINATOR_TITLE', now()->addHours(1), fn () => Setting::where('key', 'DEFAULT_COORDINATOR_TITLE')->value('value'))
            ?? 'TVET Coordinator';
        $coordinatorName = $request->filled('coordinatorName')
            ? $request->input('coordinatorName')
            : $defaultCoordinator;
        $coordinatorTitle = $request->filled('coordinatorTitle')
            ? $request->input('coordinatorTitle')
            : $defaultCoordinatorTitle;

        $payload = array_merge($request->all(), [
            'code' => $code,
            'year' => $year,
            'date' => $request->filled('date')
                ? $request->input('date')
                : now()->format('F j, Y'),
            'coordinatorName' => $coordinatorName,
            'coordinatorTitle' => $coordinatorTitle,
        ]);
        $payload = $this->enrichAssessorLinkedPayload($type->slug, $payload);

        $record = DocumentRecord::create([
            'code' => $code,
            'year' => $year,
            'document_type_id' => $type->id,
            'template_id' => $templateId,
            'user_id' => Auth::id(),
            'payload' => $payload,
            'file_path' => '',
            'file_url' => '',
        ]);

        $this->syncRelationalDocument($type->slug, $payload, $record->code);

        ActivityLog::record(
            'document.created',
            "Created document {$record->code} ({$type->name})"
        );

        return response()->json($record->load('documentType:id,slug,name'), 201);
    }

    public function download(string $code)
    {
        $record = DocumentRecord::where('code', $code)->firstOrFail();

        if (! Storage::exists($record->file_path)) {
            return response()->json(['error' => 'Generated file missing'], 404);
        }

        return Storage::download($record->file_path, $record->code.'.docx');
    }

    public function receive(Request $request, string $code)
    {
        $validated = $request->validate([
            'received_at' => 'nullable|date',
            'received_by_office' => 'nullable|string|max:255',
        ]);

        $record = DocumentRecord::where('code', $code)->firstOrFail();
        $record->received_at = $validated['received_at'] ?? now();
        $record->status = 'received';
        if (isset($validated['received_by_office'])) {
            $record->received_by_office = $validated['received_by_office'];
        }
        $record->save();

        ActivityLog::record(
            'document.received',
            "Marked document {$record->code} as received"
        );

        return response()->json($record->load('documentType:id,slug,name'));
    }

    public function updateStatus(Request $request, string $code)
    {
        $validated = $request->validate([
            'status' => ['required', 'string', 'in:saved,received,special_order,voucher_received'],
            'received_by_office' => ['nullable', 'string', 'max:255'],
            'special_order_number' => ['nullable', 'string', 'max:255'],
            'special_order_date' => ['nullable', 'date'],
            'voucher_received' => ['nullable', 'boolean'],
        ]);

        $record = DocumentRecord::where('code', $code)->firstOrFail();
        $record->status = $validated['status'];

        if (isset($validated['received_by_office'])) {
            $record->received_by_office = $validated['received_by_office'];
        }
        if (isset($validated['special_order_number'])) {
            $record->special_order_number = $validated['special_order_number'];
        }
        if (isset($validated['special_order_date'])) {
            $record->special_order_date = $validated['special_order_date'];
        }
        if (isset($validated['voucher_received'])) {
            $record->voucher_received = $validated['voucher_received'];
            if ($validated['voucher_received']) {
                $record->status = 'voucher_received';
            }
        }

        if ($validated['status'] === 'received' && ! $record->received_at) {
            $record->received_at = now();
        }

        $record->save();

        ActivityLog::record(
            'document.status_updated',
            "Updated status of {$record->code} to {$record->status}"
        );

        return response()->json($record->load('documentType:id,slug,name'));
    }

    public function destroy(string $code)
    {
        $record = DocumentRecord::where('code', $code)->firstOrFail();

        if ($record->received_at !== null) {
            return response()->json([
                'error' => 'Cannot delete a document that has already been received.',
            ], 422);
        }

        // Only the last document in the sequence can be deleted
        $parts = explode('-', $record->code);
        $recordNumber = (int) end($parts);

        $maxUsedNumber = (int) DocumentRecord::where('document_type_id', $record->document_type_id)
            ->where('year', $record->year)
            ->max(DB::raw('CAST(SUBSTRING_INDEX(code, "-", -1) AS UNSIGNED)'));

        if ($recordNumber !== $maxUsedNumber) {
            return response()->json([
                'error' => 'Only the last document in the sequence can be deleted.',
            ], 422);
        }

        if ($record->file_path && Storage::exists($record->file_path)) {
            Storage::delete($record->file_path);
        }

        $typeId = $record->document_type_id;
        $year = $record->year;

        $record->delete();

        // Recalculate the sequence based on actual records so the counter decreases properly
        $this->recalculateSequence($typeId, $year);

        ActivityLog::record(
            'document.deleted',
            "Deleted document {$record->code}"
        );

        return response()->json(['message' => 'Deleted'], 204);
    }

    /**
     * Allocates the next document number based on actual DocumentRecord
     * entries, ensuring the counter stays in sync with real data.
     */
    private function allocateNumber(DocumentType $type, int $year): int
    {
        return DB::transaction(function () use ($type, $year) {
            $maxUsedNumber = (int) DocumentRecord::where('document_type_id', $type->id)
                ->where('year', $year)
                ->max(DB::raw('CAST(SUBSTRING_INDEX(code, "-", -1) AS UNSIGNED)'));

            $seq = DocumentSequence::where('document_type_id', $type->id)
                ->where('year', $year)
                ->lockForUpdate()
                ->first();

            $savedNext = $seq?->next_number ?? 1;

            // Use the higher of (last used + 1) and (saved next_number)
            // so settings are respected but we never overwrite existing documents
            $number = max($maxUsedNumber + 1, $savedNext);

            if ($seq) {
                $seq->next_number = $number + 1;
                $seq->save();
            } else {
                DocumentSequence::create([
                    'document_type_id' => $type->id,
                    'year' => $year,
                    'next_number' => $number + 1,
                ]);
            }

            return $number;
        });
    }

    /**
     * Recalculates the next_number for a document type + year based on
     * the actual DocumentRecord entries, so deleted codes become reusable.
     */
    private function recalculateSequence(int $typeId, int $year): void
    {
        $maxUsedNumber = (int) DocumentRecord::where('document_type_id', $typeId)
            ->where('year', $year)
            ->max(DB::raw('CAST(SUBSTRING_INDEX(code, "-", -1) AS UNSIGNED)'));

        $nextNumber = $maxUsedNumber + 1;

        $seq = DocumentSequence::where('document_type_id', $typeId)
            ->where('year', $year)
            ->first();

        if ($seq) {
            $seq->next_number = $nextNumber;
            $seq->save();
        } else {
            DocumentSequence::create([
                'document_type_id' => $typeId,
                'year' => $year,
                'next_number' => $nextNumber,
            ]);
        }
    }

    private function enrichAssessorLinkedPayload(string $typeSlug, array $payload): array
    {
        if (! in_array($typeSlug, ['report-on-assessment-proceedings', 'performance-evaluation-instrument'], true)) {
            return $payload;
        }

        $assessorId = (int) ($payload['assessorId'] ?? 0);
        if ($assessorId <= 0) {
            throw ValidationException::withMessages([
                'assessorId' => ['Please select an assessor.'],
            ]);
        }

        $assessor = Assessor::find($assessorId);
        if (! $assessor) {
            throw ValidationException::withMessages([
                'assessorId' => ['Selected assessor does not exist.'],
            ]);
        }

        $qualification = trim((string) ($payload['qualification'] ?? $payload['qualificationTitle'] ?? ''));
        if ($qualification === '') {
            throw ValidationException::withMessages([
                'qualification' => ['Please select a qualification.'],
            ]);
        }

        $assessorQualifications = collect($assessor->qualifications ?? [])
            ->map(fn ($q) => trim((string) $q))
            ->filter()
            ->values();

        if (! $assessorQualifications->contains($qualification)) {
            throw ValidationException::withMessages([
                'qualification' => ['Selected qualification is not assigned to the selected assessor.'],
            ]);
        }

        $qualificationAccreditation = Center::where('type', 'assessment')
            ->whereJsonContains('qualifications', $qualification)
            ->first(['accreditation_number', 'qualifications']);

        $payload['assessorId'] = $assessor->id;
        $payload['assessorName'] = $assessor->name;
        $payload['accreditationNumber'] = $qualificationAccreditation?->accreditation_number ?? '';
        $payload['qualification'] = $qualification;
        if ($typeSlug === 'report-on-assessment-proceedings') {
            $payload['qualificationTitle'] = $qualification;
        }

        return $payload;
    }

    private function syncRelationalDocument(string $typeSlug, array $payload, string $code): void
    {
        if ($typeSlug === 'report-on-assessment-proceedings') {
            RapDocument::updateOrCreate(
                ['document_code' => $code],
                [
                    'assessor_id' => (int) ($payload['assessorId'] ?? 0) ?: null,
                    'qualification' => $payload['qualification'] ?? $payload['qualificationTitle'] ?? null,
                    'accreditation_number' => $payload['accreditationNumber'] ?? null,
                    'assessment_date' => $payload['assessmentDate'] ?? $payload['assessment_date'] ?? null,
                    'number_of_candidates' => $payload['numberOfCandidates'] ?? $payload['number_of_candidates'] ?? null,
                    'date' => $payload['date'] ?? null,
                ]
            );

            return;
        }

        if ($typeSlug === 'performance-evaluation-instrument') {
            PeiDocument::updateOrCreate(
                ['document_code' => $code],
                [
                    'assessor_id' => (int) ($payload['assessorId'] ?? 0) ?: null,
                    'qualification' => $payload['qualification'] ?? null,
                    'accreditation_number' => $payload['accreditationNumber'] ?? null,
                    'date' => $payload['date'] ?? null,
                    'respondent_name1' => $payload['respondentName1'] ?? $payload['respondent_name1'] ?? null,
                    'date_accomplished1' => $payload['dateAccomplished1'] ?? $payload['date_accomplished1'] ?? null,
                    'final_rating1' => $payload['finalRating1'] ?? $payload['final_rating1'] ?? null,
                    'evaluator_remarks1' => $payload['evaluatorRemarks1'] ?? $payload['evaluator_remarks1'] ?? null,
                    'respondent_name2' => $payload['respondentName2'] ?? $payload['respondent_name2'] ?? null,
                    'date_accomplished2' => $payload['dateAccomplished2'] ?? $payload['date_accomplished2'] ?? null,
                    'final_rating2' => $payload['finalRating2'] ?? $payload['final_rating2'] ?? null,
                    'evaluator_remarks2' => $payload['evaluatorRemarks2'] ?? $payload['evaluator_remarks2'] ?? null,
                ]
            );
        }
    }
}
