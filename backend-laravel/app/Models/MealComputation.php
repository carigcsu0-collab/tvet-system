<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class MealComputation extends Model
{
    protected $fillable = [
        'title',
        'venue',
        'date_start',
        'date_end',
        'pax',
        'days',
        'lunch_rate',
        'snack_rate',
        'snacks_per_day',
        'remarks',
    ];

    protected $appends = ['lunch_total', 'snacks_total', 'grand_total'];

    // NOTE: no 'date' casts — plain Y-m-d strings serialize as-is, avoiding
    // the timezone shift that made dates appear one day behind in the app.

    public function getLunchTotalAttribute(): float
    {
        return $this->pax * $this->days * (float) $this->lunch_rate;
    }

    public function getSnacksTotalAttribute(): float
    {
        return $this->pax * $this->days * $this->snacks_per_day * (float) $this->snack_rate;
    }

    public function getGrandTotalAttribute(): float
    {
        return $this->lunch_total + $this->snacks_total;
    }
}
