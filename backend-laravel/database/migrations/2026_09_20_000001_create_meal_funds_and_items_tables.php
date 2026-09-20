<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Money transactions per document ("funds"). When the money runs out,
        // a new fund row is added and the balance draws from the combined pool.
        if (!Schema::hasTable('meal_funds')) {
            Schema::create('meal_funds', function (Blueprint $table) {
                $table->id();
                $table->foreignId('meal_computation_id')->constrained('meal_computations')->cascadeOnDelete();
                $table->string('label')->nullable();
                $table->decimal('amount', 12, 2)->default(0);
                $table->date('received_date')->nullable();
                $table->timestamps();
            });
        }

        // Per-day receipt items: name (Lunch / AM Snack / PM Snack / Dinner /
        // custom), quantity (e.g. pax), unit price. Line total = qty x price.
        if (!Schema::hasTable('meal_items')) {
            Schema::create('meal_items', function (Blueprint $table) {
                $table->id();
                $table->foreignId('meal_computation_id')->constrained('meal_computations')->cascadeOnDelete();
                $table->date('item_date')->nullable();
                $table->string('name');
                $table->decimal('quantity', 10, 2)->default(0);
                $table->decimal('unit_price', 10, 2)->default(0);
                $table->timestamps();

                $table->index(['meal_computation_id', 'item_date']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('meal_items');
        Schema::dropIfExists('meal_funds');
    }
};
