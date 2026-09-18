<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('training_batches', function (Blueprint $table) {
            $table->id();
            $table->foreignId('center_id')->constrained('centers')->cascadeOnDelete();
            $table->string('qualification');
            $table->string('trainer_name')->nullable();
            $table->string('nttc_no')->nullable();
            $table->string('location')->nullable();
            $table->string('duration_hours')->nullable();
            $table->date('date_started')->nullable();
            $table->date('date_finished')->nullable();
            $table->timestamps();

            $table->index('center_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('training_batches');
    }
};
