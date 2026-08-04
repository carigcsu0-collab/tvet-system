<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PaymentSlip extends Model
{
    use HasFactory;

    protected $fillable = [
        'student_id',
        'last_name',
        'first_name',
        'middle_name',
        'course',
        'section',
        'officer_name',
        'officer_designations',
        'items',
        'total_amount',
        'printed_count',
        'released_count',
    ];

    protected $casts = [
        'items' => 'array',
        'total_amount' => 'float',
        'printed_count' => 'integer',
        'released_count' => 'integer',
    ];
}
