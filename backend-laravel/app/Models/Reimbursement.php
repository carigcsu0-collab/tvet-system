<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Reimbursement extends Model
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
        'or_date',
        'or_received_original',
        'attendance_received_date',
        'received',
    ];

    protected $casts = [
        'date_of_creation' => 'date',
        'date_issued' => 'date',
        'total_amount' => 'decimal:2',
        'or_date' => 'date',
        'attendance_received_date' => 'date',
        'or_received_original' => 'boolean',
        'received' => 'boolean',
    ];
}
