<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('assessee_trainees', function (Blueprint $table) {
            $table->string('external_school')->nullable()
                ->after('assessment_candidate_type');
        });
    }

    public function down(): void
    {
        Schema::table('assessee_trainees', function (Blueprint $table) {
            $table->dropColumn('external_school');
        });
    }
};
