<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class TrainingBatch extends Model
{
    protected $fillable = [
        'center_id',
        'qualification',
        'trainer_name',
        'nttc_no',
        'location',
        'duration_hours',
        'date_started',
        'date_finished',
    ];

    public function center(): BelongsTo
    {
        return $this->belongsTo(Center::class, 'center_id');
    }

    public function trainees(): HasMany
    {
        return $this->hasMany(Assessee::class, 'training_batch_id');
    }

    public function attendanceRecords(): HasMany
    {
        return $this->hasMany(TrainingAttendanceRecord::class);
    }
}
