<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TrainingAttendanceRecord extends Model
{
    protected $fillable = [
        'training_batch_id',
        'assessee_id',
        'date',
        'status',
    ];

    public function batch(): BelongsTo
    {
        return $this->belongsTo(TrainingBatch::class, 'training_batch_id');
    }

    public function assessee(): BelongsTo
    {
        return $this->belongsTo(Assessee::class, 'assessee_id');
    }
}
