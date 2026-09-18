<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('training_attendance_records', function (Blueprint $table) {
            $table->id();
            $table->foreignId('training_batch_id')->constrained('training_batches')->cascadeOnDelete();
            $table->foreignId('assessee_id')->constrained('assessee_trainees')->cascadeOnDelete();
            $table->date('date');
            $table->string('status')->default('present'); // present | half_day | absent
            $table->timestamps();

            $table->unique(['training_batch_id', 'assessee_id', 'date']);
            $table->index(['training_batch_id', 'date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('training_attendance_records');
    }
};
