<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('centers', function (Blueprint $table) {
            if (! Schema::hasColumn('centers', 'accreditation_number')) {
                $table->string('accreditation_number')->nullable()->after('name');
            }
        });
    }

    public function down(): void
    {
        Schema::table('centers', function (Blueprint $table) {
            $table->dropColumn('accreditation_number');
        });
    }
};
