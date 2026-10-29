<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('tesda_billings')) {
            return;
        }

        Schema::create('tesda_billings', function (Blueprint $table) {
            $table->id();
            $table->date('billing_date');
            $table->foreignId('center_id')->nullable()->constrained('centers')->nullOnDelete();
            $table->string('center_type', 20)->nullable();
            $table->string('qualification');
            $table->decimal('amount', 12, 2)->default(0);
            $table->unsignedInteger('pax')->default(0);
            $table->string('status', 20)->default('pending');
            $table->date('record_date')->nullable();
            $table->date('received_date')->nullable();
            $table->timestamps();

            $table->index('billing_date');
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tesda_billings');
    }
};
