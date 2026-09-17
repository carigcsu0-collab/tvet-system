<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CommunicationRecord extends Model
{
    protected $fillable = [
        'type',
        'document_code',
        'document_title',
        'date',
        'status',
        'office_received',
        'received_date',
        'remarks',
    ];

    protected $casts = [
    ];
}
