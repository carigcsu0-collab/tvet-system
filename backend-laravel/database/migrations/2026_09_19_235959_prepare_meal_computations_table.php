<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('meal_computations')) {
            $migration = require __DIR__.'/2026_10_01_000001_create_meal_computations_table.php';
            $migration->up();
        }
    }

    public function down(): void
    {
        // The original migration owns the table's rollback.
    }
};
