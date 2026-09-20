<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\MealComputation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class MealComputationController extends Controller
{
    private function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:255'],
            'venue' => ['nullable', 'string', 'max:255'],
            'date_start' => ['nullable', 'date'],
            'date_end' => ['nullable', 'date'],
            'pax' => ['nullable', 'integer', 'min:0'],
            'days' => ['nullable', 'integer', 'min:0'],
            'lunch_rate' => ['nullable', 'numeric', 'min:0'],
            'snack_rate' => ['nullable', 'numeric', 'min:0'],
            'snacks_per_day' => ['nullable', 'integer', 'min:0', 'max:10'],
            'remarks' => ['nullable', 'string'],
        ];
    }

    public function index()
    {
        return response()->json(
            MealComputation::with(['items', 'funds'])->orderByDesc('id')->get()
        );
    }

    public function show(MealComputation $mealComputation)
    {
        return response()->json(
            $mealComputation->load([
                'items' => fn ($q) => $q->orderBy('item_date')->orderBy('id'),
                'funds' => fn ($q) => $q->orderBy('received_date')->orderBy('id'),
            ])
        );
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

    /**
     * Replace the document's funds and per-day items in one transaction.
     * The detail editor saves the whole worksheet at once.
     */
    public function updateDetail(Request $request, MealComputation $mealComputation)
    {
        $validated = $request->validate([
            'funds' => ['nullable', 'array'],
            'funds.*.label' => ['nullable', 'string', 'max:255'],
            'funds.*.amount' => ['required', 'numeric', 'min:0'],
            'funds.*.received_date' => ['nullable', 'date'],
            'items' => ['nullable', 'array'],
            'items.*.item_date' => ['nullable', 'date'],
            'items.*.name' => ['required', 'string', 'max:255'],
            'items.*.quantity' => ['required', 'numeric', 'min:0'],
            'items.*.unit_price' => ['required', 'numeric', 'min:0'],
        ]);

        DB::transaction(function () use ($mealComputation, $validated) {
            $mealComputation->funds()->delete();
            foreach ($validated['funds'] ?? [] as $fund) {
                $mealComputation->funds()->create($fund);
            }

            $mealComputation->items()->delete();
            foreach ($validated['items'] ?? [] as $item) {
                $mealComputation->items()->create($item);
            }
        });

        return response()->json(
            $mealComputation->fresh()->load([
                'items' => fn ($q) => $q->orderBy('item_date')->orderBy('id'),
                'funds' => fn ($q) => $q->orderBy('received_date')->orderBy('id'),
            ])
        );
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
