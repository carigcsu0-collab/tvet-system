<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class MealFund extends Model
{
    protected $fillable = [
        'meal_computation_id',
        'label',
        'amount',
        'received_date',
    ];

    public function mealComputation()
    {
        return $this->belongsTo(MealComputation::class);
    }
}
