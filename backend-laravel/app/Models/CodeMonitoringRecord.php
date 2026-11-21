<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CodeMonitoringRecord extends Model
{
    protected $fillable = ['type', 'code', 'title', 'date'];
}
