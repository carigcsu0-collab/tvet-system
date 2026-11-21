<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::dropIfExists('meal_items');
        Schema::dropIfExists('meal_funds');
        Schema::dropIfExists('meal_computations');
    }

    public function down(): void
    {
        // Rollback restores empty tables, not the deleted data.
        $computations = require __DIR__.'/2026_10_01_000001_create_meal_computations_table.php';
        $details = require __DIR__.'/2026_09_20_000001_create_meal_funds_and_items_tables.php';
        $computations->up();
        $details->up();
    }
};
