<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PeiDocument extends Model
{
    use HasFactory;

    protected $table = 'pei_documents';

    protected $fillable = [
        'assessor_id',
        'document_code',
        'qualification',
        'accreditation_number',
        'date',
        'respondent_name1',
        'date_accomplished1',
        'final_rating1',
        'evaluator_remarks1',
        'respondent_name2',
        'date_accomplished2',
        'final_rating2',
        'evaluator_remarks2',
    ];

    public function assessor(): BelongsTo
    {
        return $this->belongsTo(Assessor::class);
    }
}
