<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Assessee extends Model
{
    use HasFactory;

    protected $table = 'assessee_trainees';

    protected $fillable = [
        'assessment_center_id',
        'name',
        'last_name',
        'first_name',
        'middle_name',
        'extension_name',
        'birthday',
        'age',
        'uli',
        'reference_number',
        'contact_number',
        'email',
        'last_school_attended',
        'qualification',
        'competency',
        'assessment_fee_paid',
        'processing_fee_paid',
        'official_receipt',
        'receipt_date',
        'assessor',
        'assessment_date',
        'registration_form',
        'medical_certificate',
        'brgy_indigency',
        'brgy_clearance',
        'tor_form137_138',
    ];

    protected $casts = [
        'assessment_fee_paid' => 'boolean',
        'processing_fee_paid' => 'boolean',
        'registration_form' => 'boolean',
        'medical_certificate' => 'boolean',
        'brgy_indigency' => 'boolean',
        'brgy_clearance' => 'boolean',
        'tor_form137_138' => 'boolean',
    ];

    public function center(): BelongsTo
    {
        return $this->belongsTo(Center::class, 'assessment_center_id');
    }
}
