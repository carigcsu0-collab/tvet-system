<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Center;
use Illuminate\Http\Request;

class CenterController extends Controller
{
    public function index()
    {
        return response()->json(Center::orderBy('name')->get());
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'accreditation_number' => ['nullable', 'string', 'max:255'],
            'type' => ['required', 'string', 'in:assessment,training'],
            'address' => ['nullable', 'string', 'max:255'],
            'assessment_fee' => ['nullable', 'numeric', 'min:0'],
            'training_fee' => ['nullable', 'numeric', 'min:0'],
            'qualifications' => ['nullable', 'string', 'max:1000'],
            'expiration_date' => ['nullable', 'date'],
            'audit_date' => ['nullable', 'date'],
        ]);

        if (! empty($validated['qualifications'])) {
            $validated['qualifications'] = array_values(array_filter(array_map(
                'trim',
                explode(',', $validated['qualifications'])
            )));
        } else {
            $validated['qualifications'] = [];
        }

        $center = Center::create($validated);

        ActivityLog::record(
            'center.created',
            "Created {$center->type} center: {$center->name}"
        );

        return response()->json($center, 201);
    }

    public function update(Request $request, Center $center)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'accreditation_number' => ['nullable', 'string', 'max:255'],
            'type' => ['required', 'string', 'in:assessment,training'],
            'address' => ['nullable', 'string', 'max:255'],
            'assessment_fee' => ['nullable', 'numeric', 'min:0'],
            'training_fee' => ['nullable', 'numeric', 'min:0'],
            'qualifications' => ['nullable', 'string', 'max:1000'],
            'expiration_date' => ['nullable', 'date'],
            'audit_date' => ['nullable', 'date'],
        ]);

        if (! empty($validated['qualifications'])) {
            $validated['qualifications'] = array_values(array_filter(array_map(
                'trim',
                explode(',', $validated['qualifications'])
            )));
        } else {
            $validated['qualifications'] = [];
        }

        $center->update($validated);

        ActivityLog::record(
            'center.updated',
            "Updated {$center->type} center: {$center->name}"
        );

        return response()->json($center);
    }

    public function destroy(Center $center)
    {
        $name = $center->name;
        $type = $center->type;
        $center->delete();

        ActivityLog::record(
            'center.deleted',
            "Deleted {$type} center: {$name}"
        );

        return response()->json(['message' => 'Center deleted']);
    }

    public function completeAudit(Request $request, Center $center)
    {
        $validated = $request->validate([
            'audit_completed_at' => 'nullable|date',
        ]);

        $center->audit_completed_at = $validated['audit_completed_at'] ?? now();
        $center->save();

        ActivityLog::record(
            'center.audit_completed',
            "Marked audit completed for {$center->type} center: {$center->name}"
        );

        return response()->json($center->load('assessees'));
    }
}
