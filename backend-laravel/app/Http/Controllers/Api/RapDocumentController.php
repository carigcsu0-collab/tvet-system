<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\RapDocument;
use Illuminate\Http\Request;

class RapDocumentController extends Controller
{
    public function index()
    {
        return response()->json(
            RapDocument::with('assessor:id,name,accreditation_number,qualifications')
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
            'assessment_date' => ['nullable', 'string', 'max:255'],
            'number_of_candidates' => ['nullable', 'string', 'max:255'],
            'date' => ['nullable', 'string', 'max:255'],
        ]);

        $rap = RapDocument::create($validated);

        ActivityLog::record(
            'rap_document.created',
            "Created RAP document" . ($rap->assessor ? " for {$rap->assessor->name}" : '')
        );

        return response()->json($rap->load('assessor:id,name,accreditation_number'), 201);
    }

    public function show(RapDocument $rapDocument)
    {
        return response()->json($rapDocument->load('assessor:id,name,accreditation_number'));
    }

    public function update(Request $request, RapDocument $rapDocument)
    {
        $validated = $request->validate([
            'assessor_id' => ['nullable', 'integer', 'exists:assessors,id'],
            'document_code' => ['nullable', 'string', 'max:255'],
            'qualification' => ['nullable', 'string', 'max:255'],
            'accreditation_number' => ['nullable', 'string', 'max:255'],
            'assessment_date' => ['nullable', 'string', 'max:255'],
            'number_of_candidates' => ['nullable', 'string', 'max:255'],
            'date' => ['nullable', 'string', 'max:255'],
        ]);

        $rapDocument->update($validated);

        ActivityLog::record(
            'rap_document.updated',
            "Updated RAP document" . ($rapDocument->assessor ? " for {$rapDocument->assessor->name}" : '')
        );

        return response()->json($rapDocument->load('assessor:id,name,accreditation_number'));
    }

    public function destroy(RapDocument $rapDocument)
    {
        $rapDocument->delete();

        ActivityLog::record(
            'rap_document.deleted',
            "Deleted RAP document"
        );

        return response()->json(['message' => 'RAP document deleted']);
    }
}
