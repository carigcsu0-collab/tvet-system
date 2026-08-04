<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        if (Schema::hasTable('assessees') && ! Schema::hasTable('assessee_trainees')) {
            Schema::rename('assessees', 'assessee_trainees');
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasTable('assessee_trainees') && ! Schema::hasTable('assessees')) {
            Schema::rename('assessee_trainees', 'assessees');
        }
    }
};
