<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Adds an expires_at column to api_tokens so sessions can have a 15-day
     * sliding expiration. Existing tokens get backfilled to 15 days from now
     * so nobody gets logged out by the migration itself.
     */
    public function up(): void
    {
        Schema::table('api_tokens', function (Blueprint $table) {
            $table->timestamp('expires_at')->nullable()->after('last_used_at');
            $table->index('expires_at');
        });

        // Backfill existing tokens so they don't immediately expire.
        \Illuminate\Support\Facades\DB::table('api_tokens')
            ->whereNull('expires_at')
            ->update(['expires_at' => now()->addDays(15)]);
    }

    public function down(): void
    {
        Schema::table('api_tokens', function (Blueprint $table) {
            $table->dropIndex(['expires_at']);
            $table->dropColumn('expires_at');
        });
    }
};
