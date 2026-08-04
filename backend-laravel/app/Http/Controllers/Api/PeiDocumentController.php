<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\PeiDocument;
use Illuminate\Http\Request;

class PeiDocumentController extends Controller
{
    public function index()
    {
        return response()->json(
            PeiDocument::with('assessor:id,name,accreditation_number,qualifications')
                ->orderByDesc('created_at')
                ->get()
        );
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'assessor_id' => ['nullable', 'integer', 'exists:assessors,id'],
            'document_code' => ['nullable', 'string', 'max:255'],
            'qualification' => ['nullable', 'string', 'max:255'],
            'accreditation_number' => ['nullable', 'string', 'max:255'],
            'date' => ['nullable', 'string', 'max:255'],
            'respondent_name1' => ['nullable', 'string', 'max:255'],
            'date_accomplished1' => ['nullable', 'string', 'max:255'],
            'final_rating1' => ['nullable', 'string', 'max:255'],
            'evaluator_remarks1' => ['nullable', 'string'],
            'respondent_name2' => ['nullable', 'string', 'max:255'],
            'date_accomplished2' => ['nullable', 'string', 'max:255'],
            'final_rating2' => ['nullable', 'string', 'max:255'],
            'evaluator_remarks2' => ['nullable', 'string'],
        ]);

        $pei = PeiDocument::create($validated);

        ActivityLog::record(
            'pei_document.created',
            "Created PEI document" . ($pei->assessor ? " for {$pei->assessor->name}" : '')
        );

        return response()->json($pei->load('assessor:id,name,accreditation_number'), 201);
    }

    public function show(PeiDocument $peiDocument)
    {
        return response()->json($peiDocument->load('assessor:id,name,accreditation_number'));
    }

    public function update(Request $request, PeiDocument $peiDocument)
    {
        $validated = $request->validate([
            'assessor_id' => ['nullable', 'integer', 'exists:assessors,id'],
            'document_code' => ['nullable', 'string', 'max:255'],
            'qualification' => ['nullable', 'string', 'max:255'],
            'accreditation_number' => ['nullable', 'string', 'max:255'],
            'date' => ['nullable', 'string', 'max:255'],
            'respondent_name1' => ['nullable', 'string', 'max:255'],
            'date_accomplished1' => ['nullable', 'string', 'max:255'],
            'final_rating1' => ['nullable', 'string', 'max:255'],
            'evaluator_remarks1' => ['nullable', 'string'],
            'respondent_name2' => ['nullable', 'string', 'max:255'],
            'date_accomplished2' => ['nullable', 'string', 'max:255'],
            'final_rating2' => ['nullable', 'string', 'max:255'],
            'evaluator_remarks2' => ['nullable', 'string'],
        ]);

        $peiDocument->update($validated);

        ActivityLog::record(
            'pei_document.updated',
            "Updated PEI document" . ($peiDocument->assessor ? " for {$peiDocument->assessor->name}" : '')
        );

        return response()->json($peiDocument->load('assessor:id,name,accreditation_number'));
    }

    public function destroy(PeiDocument $peiDocument)
    {
        $peiDocument->delete();

        ActivityLog::record(
            'pei_document.deleted',
            "Deleted PEI document"
        );

        return response()->json(['message' => 'PEI document deleted']);
    }
}
