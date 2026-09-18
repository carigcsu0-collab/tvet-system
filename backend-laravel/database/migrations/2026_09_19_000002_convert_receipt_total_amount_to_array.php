<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reimbursements', function (Blueprint $table) {
            $table->json('receipt_amounts')->nullable()->after('receipt_total_amount');
        });

        // Backfill: move the single receipt_total_amount value into a
        // one-item array so existing records keep their data.
        DB::table('reimbursements')
            ->whereNotNull('receipt_total_amount')
            ->orderBy('id')
            ->each(function ($row) {
                DB::table('reimbursements')
                    ->where('id', $row->id)
                    ->update(['receipt_amounts' => json_encode([(float) $row->receipt_total_amount])]);
            });

        Schema::table('reimbursements', function (Blueprint $table) {
            $table->dropColumn('receipt_total_amount');
        });
    }

    public function down(): void
    {
        Schema::table('reimbursements', function (Blueprint $table) {
            $table->decimal('receipt_total_amount', 12, 2)->nullable()->after('total_amount');
        });

        DB::table('reimbursements')
            ->whereNotNull('receipt_amounts')
            ->orderBy('id')
            ->each(function ($row) {
                $amounts = json_decode($row->receipt_amounts, true) ?? [];
                DB::table('reimbursements')
                    ->where('id', $row->id)
                    ->update(['receipt_total_amount' => array_sum($amounts)]);
            });

        Schema::table('reimbursements', function (Blueprint $table) {
            $table->dropColumn('receipt_amounts');
        });
    }
};
