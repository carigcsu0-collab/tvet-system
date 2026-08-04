<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('centers', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('type')->default('assessment');
            $table->string('address')->nullable();
            $table->decimal('assessment_fee', 12, 2)->default(0);
            $table->decimal('training_fee', 12, 2)->default(0);
            $table->timestamps();
        });

        Schema::create('assessees', function (Blueprint $table) {
            $table->id();
            $table->foreignId('assessment_center_id')->constrained('centers')->cascadeOnDelete();
            $table->string('name');
            $table->string('qualification')->nullable();
            $table->string('competency')->default('not_yet_competent');
            $table->boolean('assessment_fee_paid')->default(false);
            $table->boolean('processing_fee_paid')->default(false);
            $table->string('official_receipt')->nullable();
            $table->string('receipt_date')->nullable();
            $table->string('assessor')->nullable();
            $table->string('assessment_date')->nullable();
            $table->timestamps();

            $table->index('assessment_date');
            $table->index('assessor');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('assessees');
        Schema::dropIfExists('centers');
    }
};
