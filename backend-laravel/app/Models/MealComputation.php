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

    protected $appends = [
        'lunch_total',
        'snacks_total',
        'grand_total',
        'funds_total',
        'spent_total',
        'remaining_balance',
    ];

    // NOTE: no 'date' casts — plain Y-m-d strings serialize as-is, avoiding
    // the timezone shift that made dates appear one day behind in the app.

    public function items()
    {
        return $this->hasMany(MealItem::class);
    }

    public function funds()
    {
        return $this->hasMany(MealFund::class);
    }

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

    public function getFundsTotalAttribute(): float
    {
        return (float) $this->funds->sum('amount');
    }

    public function getSpentTotalAttribute(): float
    {
        return (float) $this->items->sum(
            fn ($item) => (float) $item->quantity * (float) $item->unit_price
        );
    }

    public function getRemainingBalanceAttribute(): float
    {
        return $this->funds_total - $this->spent_total;
    }
}
