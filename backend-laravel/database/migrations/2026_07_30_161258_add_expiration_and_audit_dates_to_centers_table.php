<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('centers', function (Blueprint $table) {
            if (! Schema::hasColumn('centers', 'expiration_date')) {
                $table->date('expiration_date')->nullable()->after('qualifications');
            }
            if (! Schema::hasColumn('centers', 'audit_date')) {
                $table->date('audit_date')->nullable()->after('expiration_date');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('centers', function (Blueprint $table) {
            $table->dropColumn(['expiration_date', 'audit_date']);
        });
    }
};
