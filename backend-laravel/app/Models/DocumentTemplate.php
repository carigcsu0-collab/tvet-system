<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class DocumentTemplate extends Model
{
    use HasFactory;

    protected $fillable = [
        'document_type_id',
        'original_name',
        'file_name',
        'mime_type',
        'path',
        'is_active',
    ];

    protected $casts = [
        'is_active' => 'boolean',
    ];

    public function documentType(): BelongsTo
    {
        return $this->belongsTo(DocumentType::class);
    }

    public function activeForType(): HasOne
    {
        return $this->hasOne(DocumentType::class, 'active_template_id');
    }

    public function records(): HasMany
    {
        return $this->hasMany(DocumentRecord::class);
    }
}
