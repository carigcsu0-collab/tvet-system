<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TesdaBilling extends Model
{
    public const STATUSES = ['pending', 'paid', 'cancelled'];

    protected $fillable = [
        'billing_date',
        'center_id',
        'center_type',
        'qualification',
        'amount',
        'pax',
        'status',
        'record_date',
        'received_date',
    ];

    protected function casts(): array
    {
        return [
            'billing_date' => 'date:Y-m-d',
            'record_date' => 'date:Y-m-d',
            'received_date' => 'date:Y-m-d',
            'amount' => 'decimal:2',
            'pax' => 'integer',
        ];
    }

    public function center(): BelongsTo
    {
        return $this->belongsTo(Center::class);
    }
}
