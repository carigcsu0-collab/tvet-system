<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\PurchaseRequest;
use Illuminate\Http\Request;

class PurchaseRequestController extends Controller
{
    public function index()
    {
        return response()->json(PurchaseRequest::orderByDesc('id')->get());
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'date_of_creation' => ['nullable', 'date'],
            'purpose' => ['nullable', 'string'],
            'total_amount' => ['nullable', 'numeric', 'min:0'],
            'purchase_order' => ['nullable', 'string', 'max:255'],
            'status' => ['nullable', 'string', 'max:255'],
            'receiving_office' => ['nullable', 'string', 'max:255'],
            'remarks' => ['nullable', 'string'],
        ]);

        $record = PurchaseRequest::create($validated);

        ActivityLog::record(
            'purchase_request.created',
            "Created purchase request: {$record->purpose}"
        );

        return response()->json($record, 201);
    }

    public function update(Request $request, PurchaseRequest $purchaseRequest)
    {
        $validated = $request->validate([
            'date_of_creation' => ['nullable', 'date'],
            'purpose' => ['nullable', 'string'],
            'total_amount' => ['nullable', 'numeric', 'min:0'],
            'purchase_order' => ['nullable', 'string', 'max:255'],
            'status' => ['nullable', 'string', 'max:255'],
            'receiving_office' => ['nullable', 'string', 'max:255'],
            'remarks' => ['nullable', 'string'],
        ]);

        $purchaseRequest->update($validated);

        ActivityLog::record(
            'purchase_request.updated',
            "Updated purchase request: {$purchaseRequest->purpose}"
        );

        return response()->json($purchaseRequest);
    }

    public function destroy(PurchaseRequest $purchaseRequest)
    {
        $purpose = $purchaseRequest->purpose;
        $purchaseRequest->delete();

        ActivityLog::record(
            'purchase_request.deleted',
            "Deleted purchase request: {$purpose}"
        );

        return response()->json(['message' => 'Record deleted']);
    }
}
