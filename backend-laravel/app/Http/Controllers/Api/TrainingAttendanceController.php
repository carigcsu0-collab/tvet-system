<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\TrainingAttendanceRecord;
use App\Models\TrainingBatch;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class TrainingAttendanceController extends Controller
{
    /**
     * Return the attendance matrix for a batch: trainees, the distinct
     * session dates, and the status of every trainee/date cell.
     */
    public function show(TrainingBatch $trainingBatch)
    {
        $trainees = $trainingBatch->trainees()->orderBy('name')->get(['id', 'name']);

        $records = TrainingAttendanceRecord::where('training_batch_id', $trainingBatch->id)->get();

        $dates = $records->pluck('date')
            ->map(fn ($d) => (string) $d)
            ->unique()
            ->sort()
            ->values();

        $grid = [];
        foreach ($records as $record) {
            $grid[$record->assessee_id][(string) $record->date] = $record->status;
        }

        return response()->json([
            'trainees' => $trainees,
            'dates' => $dates,
            'records' => $grid,
        ]);
    }

    /**
     * Add a new session date column: creates a default 'present' record
     * for every trainee currently assigned to the batch.
     */
    public function addDate(Request $request, TrainingBatch $trainingBatch)
    {
        $validated = $request->validate([
            'date' => ['required', 'date'],
        ]);

        $trainees = $trainingBatch->trainees()->pluck('id');

        foreach ($trainees as $assesseeId) {
            TrainingAttendanceRecord::firstOrCreate(
                [
                    'training_batch_id' => $trainingBatch->id,
                    'assessee_id' => $assesseeId,
                    'date' => $validated['date'],
                ],
                ['status' => 'present']
            );
        }

        ActivityLog::record(
            'training_attendance.date_added',
            "Added attendance date {$validated['date']} to batch: {$trainingBatch->qualification}"
        );

        return response()->json(['message' => 'Date added']);
    }

    public function removeDate(Request $request, TrainingBatch $trainingBatch)
    {
        $validated = $request->validate([
            'date' => ['required', 'date'],
        ]);

        TrainingAttendanceRecord::where('training_batch_id', $trainingBatch->id)
            ->where('date', $validated['date'])
            ->delete();

        ActivityLog::record(
            'training_attendance.date_removed',
            "Removed attendance date {$validated['date']} from batch: {$trainingBatch->qualification}"
        );

        return response()->json(['message' => 'Date removed']);
    }

    /**
     * Set the status for one trainee/date cell (creates the record if the
     * trainee was added to the batch after the date column already existed).
     */
    public function updateRecord(Request $request, TrainingBatch $trainingBatch)
    {
        $validated = $request->validate([
            'assessee_id' => ['required', 'integer', 'exists:assessee_trainees,id'],
            'date' => ['required', 'date'],
            'status' => ['required', Rule::in(['present', 'half_day', 'absent'])],
        ]);

        TrainingAttendanceRecord::updateOrCreate(
            [
                'training_batch_id' => $trainingBatch->id,
                'assessee_id' => $validated['assessee_id'],
                'date' => $validated['date'],
            ],
            ['status' => $validated['status']]
        );

        return response()->json(['message' => 'Attendance updated']);
    }
}
