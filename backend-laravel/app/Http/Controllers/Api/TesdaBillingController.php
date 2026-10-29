<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Center;
use App\Models\TesdaBilling;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class TesdaBillingController extends Controller
{
    private function rules(): array
    {
        return [
            'billing_date' => ['required', 'date'],
            'center_id' => ['required', 'integer', Rule::exists('centers', 'id')],
            'qualification' => ['required', 'string', 'max:255'],
            'amount' => ['required', 'numeric', 'min:0'],
            'pax' => ['required', 'integer', 'min:0'],
            'status' => ['required', Rule::in(TesdaBilling::STATUSES)],
            'record_date' => ['nullable', 'date'],
            'received_date' => ['nullable', 'date'],
        ];
    }

    /**
     * Validates the payload and ensures the qualification is one the selected
     * center offers. The center type is stored from the center itself.
     */
    private function validatedData(Request $request): array
    {
        $data = $request->validate($this->rules());
        $center = Center::findOrFail($data['center_id']);
        $qualification = trim($data['qualification']);
        $offered = array_map(fn ($q) => trim((string) $q), $center->qualifications ?? []);

        if (! in_array($qualification, $offered, true)) {
            throw ValidationException::withMessages([
                'qualification' => ['The selected center does not offer this qualification.'],
            ]);
        }

        $data['qualification'] = $qualification;
        $data['center_type'] = $center->type;

        return $data;
    }

    public function index()
    {
        return response()->json(
            TesdaBilling::with('center:id,name,address,type')
                ->orderByDesc('billing_date')
                ->orderByDesc('id')
                ->get()
        );
    }

    public function store(Request $request)
    {
        $record = TesdaBilling::create($this->validatedData($request));

        ActivityLog::record(
            'tesda_billing.created',
            "Created TESDA billing: {$record->qualification}"
        );

        return response()->json($record->load('center:id,name,address,type'), 201);
    }

    public function update(Request $request, TesdaBilling $tesdaBilling)
    {
        $tesdaBilling->update($this->validatedData($request));

        ActivityLog::record(
            'tesda_billing.updated',
            "Updated TESDA billing: {$tesdaBilling->qualification} ({$tesdaBilling->status})"
        );

        return response()->json($tesdaBilling->load('center:id,name,address,type'));
    }

    public function destroy(TesdaBilling $tesdaBilling)
    {
        $qualification = $tesdaBilling->qualification;
        $tesdaBilling->delete();

        ActivityLog::record(
            'tesda_billing.deleted',
            "Deleted TESDA billing: {$qualification}"
        );

        return response()->json(['message' => 'TESDA billing deleted']);
    }
}
