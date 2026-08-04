<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Center extends Model
{
    use HasFactory;

    protected $appends = ['status'];

    protected $fillable = [
        'name',
        'accreditation_number',
        'type',
        'address',
        'assessment_fee',
        'training_fee',
        'qualifications',
        'expiration_date',
        'audit_date',
        'audit_completed_at',
    ];

    protected $casts = [
        'assessment_fee' => 'float',
        'training_fee' => 'float',
        'qualifications' => 'array',
        'expiration_date' => 'date',
        'audit_date' => 'date',
        'audit_completed_at' => 'datetime',
    ];

    public function getStatusAttribute(): string
    {
        if ($this->audit_completed_at !== null) {
            return 'Complete';
        }

        if (! $this->relationLoaded('assessees')) {
            return 'Complete';
        }

        $pending = $this->assessees->contains(function ($a) {
            return $a->competency === null
                || $a->competency === ''
                || $a->competency === 'not_yet_competent'
                || $a->competency === 'Pending';
        });

        return $pending ? 'Pending' : 'Complete';
    }

    public function assessees(): HasMany
    {
        return $this->hasMany(Assessee::class, 'assessment_center_id');
    }
}
