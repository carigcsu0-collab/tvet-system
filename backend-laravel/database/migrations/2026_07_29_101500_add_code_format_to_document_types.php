<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('document_types', function (Blueprint $table) {
            $table->unsignedTinyInteger('padding')->default(3)->after('prefix');
            $table->unsignedSmallInteger('active_year')->nullable()->after('padding');
        });
    }

    public function down(): void
    {
        Schema::table('document_types', function (Blueprint $table) {
            $table->dropColumn(['padding', 'active_year']);
        });
    }
};
