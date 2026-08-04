<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payment_slips', function (Blueprint $table) {
            $table->string('student_id')->nullable()->change();
            $table->string('last_name')->nullable()->change();
            $table->string('first_name')->nullable()->change();
            $table->string('middle_name')->nullable()->change();
            $table->string('course')->nullable()->change();
            $table->string('section')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('payment_slips', function (Blueprint $table) {
            $table->string('student_id')->nullable(false)->change();
            $table->string('last_name')->nullable(false)->change();
            $table->string('first_name')->nullable(false)->change();
            $table->string('middle_name')->nullable(false)->change();
            $table->string('course')->nullable(false)->change();
            $table->string('section')->nullable(false)->change();
        });
    }
};
