<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pei_documents', function (Blueprint $table) {
            $table->id();
            $table->foreignId('assessor_id')->nullable()->constrained('assessors')->nullOnDelete();
            $table->string('document_code')->nullable();
            $table->string('qualification')->nullable();
            $table->string('accreditation_number')->nullable();
            $table->string('date')->nullable();
            // Form 1 — By Candidate (F29)
            $table->string('respondent_name1')->nullable();
            $table->string('date_accomplished1')->nullable();
            $table->string('final_rating1')->nullable();
            $table->text('evaluator_remarks1')->nullable();
            // Form 2 — By AC Manager (F30)
            $table->string('respondent_name2')->nullable();
            $table->string('date_accomplished2')->nullable();
            $table->string('final_rating2')->nullable();
            $table->text('evaluator_remarks2')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pei_documents');
    }
};
