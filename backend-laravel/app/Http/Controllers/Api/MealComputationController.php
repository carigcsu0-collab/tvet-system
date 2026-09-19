<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\MealComputation;
use Illuminate\Http\Request;

class MealComputationController extends Controller
{
    private function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:255'],
            'venue' => ['nullable', 'string', 'max:255'],
            'date_start' => ['nullable', 'date'],
            'date_end' => ['nullable', 'date'],
            'pax' => ['required', 'integer', 'min:0'],
            'days' => ['required', 'integer', 'min:1'],
            'lunch_rate' => ['required', 'numeric', 'min:0'],
            'snack_rate' => ['required', 'numeric', 'min:0'],
            'snacks_per_day' => ['required', 'integer', 'min:0', 'max:10'],
            'remarks' => ['nullable', 'string'],
        ];
    }

    public function index()
    {
        return response()->json(MealComputation::orderByDesc('id')->get());
    }

    public function store(Request $request)
    {
        $record = MealComputation::create($request->validate($this->rules()));

        ActivityLog::record(
            'meal_computation.created',
            "Created meal computation: {$record->title}"
        );

        return response()->json($record, 201);
    }

    public function update(Request $request, MealComputation $mealComputation)
    {
        $mealComputation->update($request->validate($this->rules()));

        ActivityLog::record(
            'meal_computation.updated',
            "Updated meal computation: {$mealComputation->title}"
        );

        return response()->json($mealComputation);
    }

    public function destroy(MealComputation $mealComputation)
    {
        $title = $mealComputation->title;
        $mealComputation->delete();

        ActivityLog::record(
            'meal_computation.deleted',
            "Deleted meal computation: {$title}"
        );

        return response()->json(['message' => 'Record deleted']);
    }
}
