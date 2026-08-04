<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('assessors', function (Blueprint $table) {
            if (! Schema::hasColumn('assessors', 'center_id')) {
                $table->foreignId('center_id')->nullable()->after('id')->constrained('centers')->nullOnDelete();
            }
        });
    }

    public function down(): void
    {
        Schema::table('assessors', function (Blueprint $table) {
            $table->dropForeign(['center_id']);
            $table->dropColumn('center_id');
        });
    }
};
