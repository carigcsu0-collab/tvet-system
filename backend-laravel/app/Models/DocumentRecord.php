<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DocumentRecord extends Model
{
    use HasFactory;

    protected $fillable = [
        'code',
        'year',
        'document_type_id',
        'template_id',
        'user_id',
        'payload',
        'file_path',
        'file_url',
        'received_at',
        'status',
        'received_by_office',
        'special_order_number',
        'special_order_date',
        'voucher_received',
    ];

    protected $casts = [
        'payload' => 'array',
        'received_at' => 'datetime',
        'special_order_date' => 'datetime',
        'voucher_received' => 'boolean',
    ];

    public function documentType(): BelongsTo
    {
        return $this->belongsTo(DocumentType::class);
    }

    public function template(): BelongsTo
    {
        return $this->belongsTo(DocumentTemplate::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
