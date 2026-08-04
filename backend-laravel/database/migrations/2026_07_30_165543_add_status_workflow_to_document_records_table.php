<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('document_records', function (Blueprint $table) {
            if (! Schema::hasColumn('document_records', 'status')) {
                $table->string('status')->default('saved')->after('received_at');
            }
            if (! Schema::hasColumn('document_records', 'received_by_office')) {
                $table->string('received_by_office')->nullable()->after('status');
            }
            if (! Schema::hasColumn('document_records', 'special_order_number')) {
                $table->string('special_order_number')->nullable()->after('received_by_office');
            }
            if (! Schema::hasColumn('document_records', 'special_order_date')) {
                $table->datetime('special_order_date')->nullable()->after('special_order_number');
            }
            if (! Schema::hasColumn('document_records', 'voucher_received')) {
                $table->boolean('voucher_received')->default(false)->after('special_order_date');
            }
        });
    }

    public function down(): void
    {
        Schema::table('document_records', function (Blueprint $table) {
            $table->dropColumn([
                'status', 'received_by_office', 'special_order_number',
                'special_order_date', 'voucher_received',
            ]);
        });
    }
};
