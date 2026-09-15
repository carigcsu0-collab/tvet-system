<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Internal & External Communications share one table with a type column.
        Schema::create('communication_records', function (Blueprint $table) {
            $table->id();
            $table->string('type')->default('internal'); // internal | external
            $table->string('document_code')->nullable();
            $table->string('document_title')->nullable();
            $table->date('date')->nullable();
            $table->string('status')->default('Pending');
            $table->string('office_received')->nullable();
            $table->date('received_date')->nullable();
            $table->text('remarks')->nullable();
            $table->timestamps();

            $table->index('type');
            $table->index('status');
        });

        Schema::create('purchase_requests', function (Blueprint $table) {
            $table->id();
            $table->date('date_of_creation')->nullable();
            $table->text('purpose')->nullable();
            $table->decimal('total_amount', 12, 2)->default(0);
            $table->string('purchase_order')->nullable();
            $table->string('status')->default('Pending');
            $table->string('receiving_office')->nullable();
            $table->text('remarks')->nullable();
            $table->timestamps();

            $table->index('status');
        });

        Schema::create('reimbursements', function (Blueprint $table) {
            $table->id();
            $table->date('date_of_creation')->nullable();
            $table->text('purpose')->nullable();
            $table->decimal('total_amount', 12, 2)->default(0);
            $table->string('purchase_order')->nullable();
            $table->string('status')->default('Pending');
            $table->string('receiving_office')->nullable();
            $table->text('remarks')->nullable();
            $table->date('or_date')->nullable();
            $table->boolean('or_received_original')->default(false);
            $table->date('attendance_received_date')->nullable();
            $table->boolean('received')->default(false);
            $table->timestamps();

            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reimbursements');
        Schema::dropIfExists('purchase_requests');
        Schema::dropIfExists('communication_records');
    }
};
