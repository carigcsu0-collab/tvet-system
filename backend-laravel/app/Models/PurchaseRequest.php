<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PurchaseRequest extends Model
{
    protected $fillable = [
        'date_of_creation',
        'purpose',
        'total_amount',
        'purchase_request_number',
        'date_issued',
        'status',
        'receiving_office',
        'remarks',
    ];

    protected $casts = [
        'total_amount' => 'decimal:2',
    ];
}
