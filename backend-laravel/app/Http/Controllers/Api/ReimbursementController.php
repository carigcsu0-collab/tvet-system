<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Reimbursement;
use Illuminate\Http\Request;

class ReimbursementController extends Controller
{
    public function index()
    {
        return response()->json(Reimbursement::orderByDesc('id')->get());
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'date_of_creation' => ['nullable', 'date'],
            'purpose' => ['nullable', 'string'],
            'total_amount' => ['nullable', 'numeric', 'min:0'],
            'purchase_request_number' => ['nullable', 'string', 'max:255'],
            'date_issued' => ['nullable', 'date'],
            'status' => ['nullable', 'string', 'max:255'],
            'receiving_office' => ['nullable', 'string', 'max:255'],
            'remarks' => ['nullable', 'string'],
            'or_date' => ['nullable', 'date'],
            'or_received_original' => ['nullable', 'boolean'],
            'attendance_received_date' => ['nullable', 'date'],
            'received' => ['nullable', 'boolean'],
        ]);

        $record = Reimbursement::create($validated);

        ActivityLog::record(
            'reimbursement.created',
            "Created reimbursement: {$record->purpose}"
        );

        return response()->json($record, 201);
    }

    public function update(Request $request, Reimbursement $reimbursement)
    {
        $validated = $request->validate([
            'date_of_creation' => ['nullable', 'date'],
            'purpose' => ['nullable', 'string'],
            'total_amount' => ['nullable', 'numeric', 'min:0'],
            'purchase_request_number' => ['nullable', 'string', 'max:255'],
            'date_issued' => ['nullable', 'date'],
            'status' => ['nullable', 'string', 'max:255'],
            'receiving_office' => ['nullable', 'string', 'max:255'],
            'remarks' => ['nullable', 'string'],
            'or_date' => ['nullable', 'date'],
            'or_received_original' => ['nullable', 'boolean'],
            'attendance_received_date' => ['nullable', 'date'],
            'received' => ['nullable', 'boolean'],
        ]);

        $reimbursement->update($validated);

        ActivityLog::record(
            'reimbursement.updated',
            "Updated reimbursement: {$reimbursement->purpose}"
        );

        return response()->json($reimbursement);
    }

    public function destroy(Reimbursement $reimbursement)
    {
        $purpose = $reimbursement->purpose;
        $reimbursement->delete();

        ActivityLog::record(
            'reimbursement.deleted',
            "Deleted reimbursement: {$purpose}"
        );

        return response()->json(['message' => 'Record deleted']);
    }
}
