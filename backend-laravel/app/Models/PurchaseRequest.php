<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PurchaseRequest extends Model
{
    protected $fillable = [
        'date_of_creation',
        'purpose',
        'total_amount',
        'purchase_order',
        'status',
        'receiving_office',
        'remarks',
    ];

    protected $casts = [
        'date_of_creation' => 'date',
        'total_amount' => 'decimal:2',
    ];
}
