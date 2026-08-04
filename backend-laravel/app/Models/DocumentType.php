<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class DocumentType extends Model
{
    use HasFactory;

    protected $fillable = [
        'slug',
        'name',
        'prefix',
        'padding',
        'active_year',
        'active_template_id',
    ];

    protected $casts = [
        'padding' => 'integer',
        'active_year' => 'integer',
    ];

    public function codeYear(): int
    {
        return $this->active_year ?: (int) now()->year;
    }

    public function formatCode(int $number, ?int $year = null): string
    {
        $pad = max(1, (int) ($this->padding ?: 3));

        return sprintf(
            '%s-%d-%s',
            $this->prefix,
            $year ?? $this->codeYear(),
            str_pad((string) $number, $pad, '0', STR_PAD_LEFT)
        );
    }

    public function activeTemplate(): BelongsTo
    {
        return $this->belongsTo(DocumentTemplate::class, 'active_template_id');
    }

    public function templates(): HasMany
    {
        return $this->hasMany(DocumentTemplate::class);
    }

    public function records(): HasMany
    {
        return $this->hasMany(DocumentRecord::class);
    }

    public function sequences(): HasMany
    {
        return $this->hasMany(DocumentSequence::class);
    }
}
