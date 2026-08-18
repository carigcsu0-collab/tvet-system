<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('assessee_trainees', function (Blueprint $table) {
            if (! Schema::hasColumn('assessee_trainees', 'extension_name')) {
                $table->string('extension_name')->nullable()->after('middle_name');
            }
        });
    }

    public function down(): void
    {
        Schema::table('assessee_trainees', function (Blueprint $table) {
            if (Schema::hasColumn('assessee_trainees', 'extension_name')) {
                $table->dropColumn('extension_name');
            }
        });
    }
};
