<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Rename purchase_order -> purchase_request_number and add date_issued
        Schema::table('purchase_requests', function (Blueprint $table) {
            $table->renameColumn('purchase_order', 'purchase_request_number');
            $table->date('date_issued')->nullable()->after('purchase_request_number');
        });

        Schema::table('reimbursements', function (Blueprint $table) {
            $table->renameColumn('purchase_order', 'purchase_request_number');
            $table->date('date_issued')->nullable()->after('purchase_request_number');
        });
    }

    public function down(): void
    {
        Schema::table('reimbursements', function (Blueprint $table) {
            $table->dropColumn('date_issued');
            $table->renameColumn('purchase_request_number', 'purchase_order');
        });

        Schema::table('purchase_requests', function (Blueprint $table) {
            $table->dropColumn('date_issued');
            $table->renameColumn('purchase_request_number', 'purchase_order');
        });
    }
};
