<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('assessee_trainees', function (Blueprint $table) {
            $table->foreignId('training_batch_id')->nullable()
                ->after('assessment_center_id')
                ->constrained('training_batches')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('assessee_trainees', function (Blueprint $table) {
            $table->dropConstrainedForeignId('training_batch_id');
        });
    }
};
