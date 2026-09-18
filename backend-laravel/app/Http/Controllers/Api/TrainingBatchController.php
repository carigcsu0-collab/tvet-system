<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Assessee;
use App\Models\TrainingBatch;
use Illuminate\Http\Request;

class TrainingBatchController extends Controller
{
    public function index(Request $request)
    {
        $query = TrainingBatch::with('center:id,name,type,training_fee')
            ->withCount('trainees');

        if ($request->filled('center_id')) {
            $query->where('center_id', $request->input('center_id'));
        }

        return response()->json($query->orderByDesc('id')->get());
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'center_id' => ['required', 'integer', 'exists:centers,id'],
            'qualification' => ['required', 'string', 'max:255'],
            'trainer_name' => ['nullable', 'string', 'max:255'],
            'nttc_no' => ['nullable', 'string', 'max:255'],
            'location' => ['nullable', 'string', 'max:255'],
            'duration_hours' => ['nullable', 'string', 'max:255'],
            'date_started' => ['nullable', 'date'],
            'date_finished' => ['nullable', 'date'],
        ]);

        $batch = TrainingBatch::create($validated);

        ActivityLog::record(
            'training_batch.created',
            "Created training batch: {$batch->qualification}"
        );

        return response()->json($batch->load('center:id,name,type,training_fee'), 201);
    }

    public function update(Request $request, TrainingBatch $trainingBatch)
    {
        $validated = $request->validate([
            'center_id' => ['required', 'integer', 'exists:centers,id'],
            'qualification' => ['required', 'string', 'max:255'],
            'trainer_name' => ['nullable', 'string', 'max:255'],
            'nttc_no' => ['nullable', 'string', 'max:255'],
            'location' => ['nullable', 'string', 'max:255'],
            'duration_hours' => ['nullable', 'string', 'max:255'],
            'date_started' => ['nullable', 'date'],
            'date_finished' => ['nullable', 'date'],
        ]);

        $trainingBatch->update($validated);

        ActivityLog::record(
            'training_batch.updated',
            "Updated training batch: {$trainingBatch->qualification}"
        );

        return response()->json($trainingBatch->load('center:id,name,type,training_fee'));
    }

    public function destroy(TrainingBatch $trainingBatch)
    {
        $qualification = $trainingBatch->qualification;
        $trainingBatch->delete();

        ActivityLog::record(
            'training_batch.deleted',
            "Deleted training batch: {$qualification}"
        );

        return response()->json(['message' => 'Training batch deleted']);
    }

    public function trainees(TrainingBatch $trainingBatch)
    {
        return response()->json(
            $trainingBatch->trainees()->orderBy('name')->get()
        );
    }

    public function availableTrainees(TrainingBatch $trainingBatch)
    {
        $trainees = Assessee::where('assessment_center_id', $trainingBatch->center_id)
            ->where(function ($q) use ($trainingBatch) {
                $q->whereNull('training_batch_id')
                    ->orWhere('training_batch_id', $trainingBatch->id);
            })
            ->orderBy('name')
            ->get();

        return response()->json($trainees);
    }

    public function assignTrainees(Request $request, TrainingBatch $trainingBatch)
    {
        $validated = $request->validate([
            'assessee_ids' => ['required', 'array'],
            'assessee_ids.*' => ['integer', 'exists:assessee_trainees,id'],
        ]);

        Assessee::where('assessment_center_id', $trainingBatch->center_id)
            ->whereIn('id', $validated['assessee_ids'])
            ->update(['training_batch_id' => $trainingBatch->id]);

        ActivityLog::record(
            'training_batch.trainees_assigned',
            'Assigned ' . count($validated['assessee_ids']) . " trainee(s) to batch: {$trainingBatch->qualification}"
        );

        return response()->json($trainingBatch->trainees()->orderBy('name')->get());
    }

    public function unassignTrainee(TrainingBatch $trainingBatch, Assessee $assessee)
    {
        if ($assessee->training_batch_id === $trainingBatch->id) {
            $assessee->update(['training_batch_id' => null]);
        }

        ActivityLog::record(
            'training_batch.trainee_unassigned',
            "Removed {$assessee->name} from batch: {$trainingBatch->qualification}"
        );

        return response()->json(['message' => 'Trainee removed from batch']);
    }

    public function billing(TrainingBatch $trainingBatch)
    {
        $trainingBatch->load('center:id,name,type,training_fee');
        $trainees = $trainingBatch->trainees()->orderBy('name')->get();
        $fee = (float) ($trainingBatch->center->training_fee ?? 0);

        return response()->json([
            'batch' => $trainingBatch,
            'fee' => $fee,
            'trainees' => $trainees,
            'total' => $fee * $trainees->count(),
        ]);
    }
}
