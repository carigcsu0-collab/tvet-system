<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Assessor extends Model
{
    use HasFactory;

    protected $fillable = [
        'center_id',
        'name',
        'qualifications',
        'accreditation_number',
        'mobile_number',
    ];

    protected $casts = [
        'qualifications' => 'array',
    ];

    public function center(): BelongsTo
    {
        return $this->belongsTo(Center::class);
    }

    public function rapDocuments(): HasMany
    {
        return $this->hasMany(RapDocument::class);
    }

    public function peiDocuments(): HasMany
    {
        return $this->hasMany(PeiDocument::class);
    }
}
