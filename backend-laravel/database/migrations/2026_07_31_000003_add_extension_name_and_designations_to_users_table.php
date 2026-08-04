<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (! Schema::hasColumn('users', 'extension_name')) {
                $table->string('extension_name')->nullable()->after('name');
            }
            if (! Schema::hasColumn('users', 'designations')) {
                $table->json('designations')->nullable()->after('extension_name');
            }
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['extension_name', 'designations']);
        });
    }
};
