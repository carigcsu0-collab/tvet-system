<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class MealItem extends Model
{
    protected $fillable = [
        'meal_computation_id',
        'item_date',
        'name',
        'quantity',
        'unit_price',
    ];

    protected $appends = ['total'];

    public function getTotalAttribute(): float
    {
        return (float) $this->quantity * (float) $this->unit_price;
    }

    public function mealComputation()
    {
        return $this->belongsTo(MealComputation::class);
    }
}
