<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('meal_computations', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->string('venue')->nullable();
            $table->date('date_start')->nullable();
            $table->date('date_end')->nullable();
            $table->unsignedInteger('pax')->default(0);
            $table->unsignedInteger('days')->default(1);
            $table->decimal('lunch_rate', 10, 2)->default(0);
            $table->decimal('snack_rate', 10, 2)->default(0);
            $table->unsignedTinyInteger('snacks_per_day')->default(2);
            $table->text('remarks')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('meal_computations');
    }
};
