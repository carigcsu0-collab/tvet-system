<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Reimbursement extends Model
{
    protected $appends = ['receipt_total'];

    protected $fillable = [
        'date_of_creation',
        'purpose',
        'total_amount',
        'receipt_amounts',
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
        'total_amount' => 'decimal:2',
        'receipt_amounts' => 'array',
        'or_received_original' => 'boolean',
        'received' => 'boolean',
    ];

    /**
     * Sum of the individual receipt amounts (up to 10 entries).
     */
    public function getReceiptTotalAttribute(): float
    {
        return array_sum($this->receipt_amounts ?? []);
    }
}
