<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Assessor;
use Illuminate\Http\Request;

class AssessorController extends Controller
{
    public function index()
    {
        return response()->json(Assessor::with('center:id,name,type,qualifications')->orderBy('name')->get());
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'center_id' => ['nullable', 'integer', 'exists:centers,id'],
            'name' => ['required', 'string', 'max:255'],
            'qualifications' => ['nullable', 'array'],
            'qualifications.*' => ['nullable', 'string', 'max:255'],
            'accreditation_number' => ['nullable', 'string', 'max:255'],
            'mobile_number' => ['nullable', 'string', 'max:255'],
        ]);

        // Filter out empty qualifications
        if (isset($validated['qualifications']) && is_array($validated['qualifications'])) {
            $validated['qualifications'] = array_filter($validated['qualifications'], function($value) {
                return !empty(trim($value));
            });
            if (empty($validated['qualifications'])) {
                $validated['qualifications'] = null;
            }
        }

        $assessor = Assessor::create($validated);

        ActivityLog::record(
            'assessor.created',
            "Created assessor: {$assessor->name}" . ($assessor->center ? " for {$assessor->center->name}" : '')
        );

        return response()->json($assessor->load('center:id,name,qualifications'), 201);
    }

    public function update(Request $request, Assessor $assessor)
    {
        $validated = $request->validate([
            'center_id' => ['nullable', 'integer', 'exists:centers,id'],
            'name' => ['required', 'string', 'max:255'],
            'qualifications' => ['nullable', 'array'],
            'qualifications.*' => ['nullable', 'string', 'max:255'],
            'accreditation_number' => ['nullable', 'string', 'max:255'],
            'mobile_number' => ['nullable', 'string', 'max:255'],
        ]);

        // Filter out empty qualifications
        if (isset($validated['qualifications']) && is_array($validated['qualifications'])) {
            $validated['qualifications'] = array_filter($validated['qualifications'], function($value) {
                return !empty(trim($value));
            });
            if (empty($validated['qualifications'])) {
                $validated['qualifications'] = null;
            }
        }

        $assessor->update($validated);

        ActivityLog::record(
            'assessor.updated',
            "Updated assessor: {$assessor->name}" . ($assessor->center ? " for {$assessor->center->name}" : '')
        );

        return response()->json($assessor->load('center:id,name,qualifications'));
    }

    public function destroy(Assessor $assessor)
    {
        $name = $assessor->name;
        $assessor->delete();

        ActivityLog::record(
            'assessor.deleted',
            "Deleted assessor: {$name}"
        );

        return response()->json(['message' => 'Assessor deleted']);
    }
}
