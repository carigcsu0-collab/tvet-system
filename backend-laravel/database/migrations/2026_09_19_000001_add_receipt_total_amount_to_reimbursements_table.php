<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reimbursements', function (Blueprint $table) {
            $table->decimal('receipt_total_amount', 12, 2)->nullable()->after('total_amount');
        });
    }

    public function down(): void
    {
        Schema::table('reimbursements', function (Blueprint $table) {
            $table->dropColumn('receipt_total_amount');
        });
    }
};
