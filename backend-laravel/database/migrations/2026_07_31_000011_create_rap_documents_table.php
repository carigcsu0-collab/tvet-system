<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('rap_documents', function (Blueprint $table) {
            $table->id();
            $table->foreignId('assessor_id')->nullable()->constrained('assessors')->nullOnDelete();
            $table->string('document_code')->nullable();
            $table->string('qualification')->nullable();
            $table->string('accreditation_number')->nullable();
            $table->string('assessment_date')->nullable();
            $table->string('number_of_candidates')->nullable();
            $table->string('date')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('rap_documents');
    }
};
