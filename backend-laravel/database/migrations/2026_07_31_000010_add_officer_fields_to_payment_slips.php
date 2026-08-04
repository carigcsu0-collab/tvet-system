<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payment_slips', function (Blueprint $table) {
            $table->string('officer_name')->nullable()->after('section');
            $table->string('officer_designations')->nullable()->after('officer_name');
        });
    }

    public function down(): void
    {
        Schema::table('payment_slips', function (Blueprint $table) {
            $table->dropColumn(['officer_name', 'officer_designations']);
        });
    }
};
