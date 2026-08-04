<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RapDocument extends Model
{
    use HasFactory;

    protected $table = 'rap_documents';

    protected $fillable = [
        'assessor_id',
        'document_code',
        'qualification',
        'accreditation_number',
        'assessment_date',
        'number_of_candidates',
        'date',
    ];

    public function assessor(): BelongsTo
    {
        return $this->belongsTo(Assessor::class);
    }
}
