<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('assessors', function (Blueprint $table) {
            if (! Schema::hasColumn('assessors', 'mobile_number')) {
                $table->string('mobile_number')->nullable()->after('accreditation_number');
            }
        });
    }

    public function down(): void
    {
        Schema::table('assessors', function (Blueprint $table) {
            $table->dropColumn('mobile_number');
        });
    }
};
