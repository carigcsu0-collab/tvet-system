<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\CommunicationRecord;
use Illuminate\Http\Request;

class CommunicationRecordController extends Controller
{
    public function index(Request $request)
    {
        $query = CommunicationRecord::query();

        if ($request->filled('type')) {
            $query->where('type', $request->input('type'));
        }

        return response()->json($query->orderByDesc('id')->get());
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'type' => ['required', 'string', 'in:internal,external'],
            'document_code' => ['nullable', 'string', 'max:255'],
            'document_title' => ['nullable', 'string', 'max:255'],
            'date' => ['nullable', 'date'],
            'status' => ['nullable', 'string', 'max:255'],
            'office_received' => ['nullable', 'string', 'max:255'],
            'received_date' => ['nullable', 'date'],
            'remarks' => ['nullable', 'string'],
        ]);

        $record = CommunicationRecord::create($validated);

        ActivityLog::record(
            'communication.created',
            "Created {$record->type} communication: {$record->document_title}"
        );

        return response()->json($record, 201);
    }

    public function update(Request $request, CommunicationRecord $communicationRecord)
    {
        $validated = $request->validate([
            'type' => ['nullable', 'string', 'in:internal,external'],
            'document_code' => ['nullable', 'string', 'max:255'],
            'document_title' => ['nullable', 'string', 'max:255'],
            'date' => ['nullable', 'date'],
            'status' => ['nullable', 'string', 'max:255'],
            'office_received' => ['nullable', 'string', 'max:255'],
            'received_date' => ['nullable', 'date'],
            'remarks' => ['nullable', 'string'],
        ]);

        $communicationRecord->update($validated);

        ActivityLog::record(
            'communication.updated',
            "Updated {$communicationRecord->type} communication: {$communicationRecord->document_title}"
        );

        return response()->json($communicationRecord);
    }

    public function destroy(CommunicationRecord $communicationRecord)
    {
        $title = $communicationRecord->document_title;
        $type = $communicationRecord->type;
        $communicationRecord->delete();

        ActivityLog::record(
            'communication.deleted',
            "Deleted {$type} communication: {$title}"
        );

        return response()->json(['message' => 'Record deleted']);
    }
}
