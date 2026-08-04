<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('centers', function (Blueprint $table) {
            if (! Schema::hasColumn('centers', 'audit_completed_at')) {
                $table->datetime('audit_completed_at')->nullable()->after('audit_date');
            }
        });
    }

    public function down(): void
    {
        Schema::table('centers', function (Blueprint $table) {
            $table->dropColumn('audit_completed_at');
        });
    }
};
