<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Assessee;
use App\Models\Center;
use Illuminate\Http\Request;

class AssesseeController extends Controller
{
    public function index(Request $request)
    {
        $query = Assessee::with('center:id,name,type,assessment_fee,training_fee');

        if ($request->filled('assessment_date')) {
            $query->where('assessment_date', $request->input('assessment_date'));
        }

        if ($request->filled('assessment_date_from')) {
            $query->where('assessment_date', '>=', $request->input('assessment_date_from'));
        }

        if ($request->filled('assessment_date_to')) {
            $query->where('assessment_date', '<=', $request->input('assessment_date_to'));
        }

        if ($request->filled('assessment_center_id')) {
            $query->where('assessment_center_id', $request->input('assessment_center_id'));
        }

        if ($request->filled('type')) {
            $type = $request->input('type');
            $centerIds = Center::where('type', $type)->pluck('id');
            $query->whereIn('assessment_center_id', $centerIds);
        }

        return response()->json($query->orderBy('name')->get());
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'assessment_center_id' => ['required', 'integer', 'exists:centers,id'],
            'last_name' => ['required', 'string', 'max:255'],
            'first_name' => ['required', 'string', 'max:255'],
            'middle_name' => ['nullable', 'string', 'max:255'],
            'extension_name' => ['nullable', 'string', 'max:255'],
            'birthday' => ['required', 'string', 'max:255'],
            'age' => ['required', 'integer', 'min:0'],
            'uli' => ['nullable', 'string', 'max:255'],
            'reference_number' => ['nullable', 'string', 'max:255'],
            'contact_number' => ['nullable', 'string', 'max:255'],
            'email' => ['nullable', 'string', 'email', 'max:255'],
            'qualification' => ['required', 'string', 'max:255'],
            'competency' => ['nullable', 'string', 'max:255'],
            'assessment_fee_paid' => ['nullable', 'boolean'],
            'processing_fee_paid' => ['nullable', 'boolean'],
            'official_receipt' => ['nullable', 'string', 'max:255'],
            'receipt_date' => ['nullable', 'string', 'max:255'],
            'assessor' => ['nullable', 'string', 'max:255'],
            'assessment_date' => ['nullable', 'string', 'max:255'],
            'last_school_attended' => ['nullable', 'string', 'max:255'],
            'registration_form' => ['nullable', 'boolean'],
            'medical_certificate' => ['nullable', 'boolean'],
            'brgy_indigency' => ['nullable', 'boolean'],
            'brgy_clearance' => ['nullable', 'boolean'],
            'tor_form137_138' => ['nullable', 'boolean'],
        ]);

        $validated['name'] = trim(
            $validated['last_name'] . ', ' . $validated['first_name'] .
            (empty($validated['middle_name']) ? '' : ' ' . $validated['middle_name']) .
            (empty($validated['extension_name'] ?? '') ? '' : ' ' . $validated['extension_name'])
        );

        $validated['competency'] = $validated['competency'] ?? 'Pending';
        $validated['assessment_fee_paid'] = $validated['assessment_fee_paid'] ?? false;
        $validated['processing_fee_paid'] = $validated['processing_fee_paid'] ?? false;
        $validated['registration_form'] = $validated['registration_form'] ?? false;
        $validated['medical_certificate'] = $validated['medical_certificate'] ?? false;
        $validated['brgy_indigency'] = $validated['brgy_indigency'] ?? false;
        $validated['brgy_clearance'] = $validated['brgy_clearance'] ?? false;
        $validated['tor_form137_138'] = $validated['tor_form137_138'] ?? false;

        $assessee = Assessee::create($validated);

        ActivityLog::record(
            'assessee.created',
            "Added assessee: {$assessee->name} to center " .
            ($assessee->center?->name ?? '')
        );

        return response()->json($assessee->load('center:id,name'), 201);
    }

    public function bulkUpdate(Request $request)
    {
        $validated = $request->validate([
            'ids' => ['required', 'array'],
            'ids.*' => ['integer', 'exists:assessees,id'],
            'assessor' => ['nullable', 'string', 'max:255'],
            'assessment_date' => ['nullable', 'string', 'max:255'],
        ]);

        $update = [];
        if (array_key_exists('assessor', $validated)) {
            $update['assessor'] = $validated['assessor'];
        }
        if (array_key_exists('assessment_date', $validated)) {
            $update['assessment_date'] = $validated['assessment_date'];
        }

        if ($update === []) {
            return response()->json(['updated' => 0]);
        }

        $count = Assessee::whereIn('id', $validated['ids'])->update($update);

        ActivityLog::record(
            'assessee.bulk_updated',
            "Bulk updated {$count} assessees"
        );

        return response()->json(['updated' => $count]);
    }

    public function update(Request $request, Assessee $assessee)
    {
        $validated = $request->validate([
            'assessment_center_id' => ['required', 'integer', 'exists:centers,id'],
            'last_name' => ['required', 'string', 'max:255'],
            'first_name' => ['required', 'string', 'max:255'],
            'middle_name' => ['nullable', 'string', 'max:255'],
            'extension_name' => ['nullable', 'string', 'max:255'],
            'birthday' => ['required', 'string', 'max:255'],
            'age' => ['required', 'integer', 'min:0'],
            'uli' => ['nullable', 'string', 'max:255'],
            'reference_number' => ['nullable', 'string', 'max:255'],
            'contact_number' => ['nullable', 'string', 'max:255'],
            'email' => ['nullable', 'string', 'email', 'max:255'],
            'qualification' => ['required', 'string', 'max:255'],
            'competency' => ['nullable', 'string', 'max:255'],
            'assessment_fee_paid' => ['nullable', 'boolean'],
            'processing_fee_paid' => ['nullable', 'boolean'],
            'official_receipt' => ['nullable', 'string', 'max:255'],
            'receipt_date' => ['nullable', 'string', 'max:255'],
            'assessor' => ['nullable', 'string', 'max:255'],
            'assessment_date' => ['nullable', 'string', 'max:255'],
            'last_school_attended' => ['nullable', 'string', 'max:255'],
            'registration_form' => ['nullable', 'boolean'],
            'medical_certificate' => ['nullable', 'boolean'],
            'brgy_indigency' => ['nullable', 'boolean'],
            'brgy_clearance' => ['nullable', 'boolean'],
            'tor_form137_138' => ['nullable', 'boolean'],
        ]);

        $validated['name'] = trim(
            $validated['last_name'] . ', ' . $validated['first_name'] .
            (empty($validated['middle_name']) ? '' : ' ' . $validated['middle_name']) .
            (empty($validated['extension_name'] ?? '') ? '' : ' ' . $validated['extension_name'])
        );

        $validated['competency'] = $validated['competency'] ?? 'Pending';
        $validated['assessment_fee_paid'] = $validated['assessment_fee_paid'] ?? false;
        $validated['processing_fee_paid'] = $validated['processing_fee_paid'] ?? false;
        $validated['registration_form'] = $validated['registration_form'] ?? false;
        $validated['medical_certificate'] = $validated['medical_certificate'] ?? false;
        $validated['brgy_indigency'] = $validated['brgy_indigency'] ?? false;
        $validated['brgy_clearance'] = $validated['brgy_clearance'] ?? false;
        $validated['tor_form137_138'] = $validated['tor_form137_138'] ?? false;

        $assessee->update($validated);

        ActivityLog::record(
            'assessee.updated',
            "Updated assessee: {$assessee->name}"
        );

        return response()->json($assessee->load('center:id,name'));
    }

    public function destroy(Assessee $assessee)
    {
        $name = $assessee->name;
        $assessee->delete();

        ActivityLog::record(
            'assessee.deleted',
            "Deleted assessee: {$name}"
        );

        return response()->json(['message' => 'Assessee deleted']);
    }
}
