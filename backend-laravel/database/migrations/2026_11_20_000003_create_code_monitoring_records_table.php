<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('code_monitoring_records', function (Blueprint $table) {
            $table->id();
            $table->string('type', 10);
            $table->string('code');
            $table->string('title');
            $table->date('date');
            $table->timestamps();

            $table->index(['type', 'date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('code_monitoring_records');
    }
};
