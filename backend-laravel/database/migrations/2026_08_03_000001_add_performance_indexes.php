<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // document_records — looked up by code, filtered by type+year, ordered by created_at
        Schema::table('document_records', function (Blueprint $table) {
            $table->index('code');
            $table->index(['document_type_id', 'year']);
            $table->index('created_at');
        });

        // centers — filtered by type, ordered by name
        Schema::table('centers', function (Blueprint $table) {
            $table->index('type');
            $table->index('name');
        });

        // assessee_trainees — FK lookups, ordered by name, filtered by assessment_date
        Schema::table('assessee_trainees', function (Blueprint $table) {
            $table->index('assessment_center_id');
            $table->index('name');
        });

        // assessors — FK lookups, ordered by name
        Schema::table('assessors', function (Blueprint $table) {
            $table->index('center_id');
            $table->index('name');
        });

        // document_templates — filtered by document_type_id + is_active
        Schema::table('document_templates', function (Blueprint $table) {
            $table->index(['document_type_id', 'is_active']);
        });

        // payment_slips — ordered by created_at
        Schema::table('payment_slips', function (Blueprint $table) {
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::table('payment_slips', function (Blueprint $table) {
            $table->dropIndex(['created_at']);
        });
        Schema::table('document_templates', function (Blueprint $table) {
            $table->dropIndex(['document_type_id', 'is_active']);
        });
        Schema::table('assessors', function (Blueprint $table) {
            $table->dropIndex(['name']);
            $table->dropIndex(['center_id']);
        });
        Schema::table('assessee_trainees', function (Blueprint $table) {
            $table->dropIndex(['name']);
            $table->dropIndex(['assessment_center_id']);
        });
        Schema::table('centers', function (Blueprint $table) {
            $table->dropIndex(['name']);
            $table->dropIndex(['type']);
        });
        Schema::table('document_records', function (Blueprint $table) {
            $table->dropIndex(['created_at']);
            $table->dropIndex(['document_type_id', 'year']);
            $table->dropIndex(['code']);
        });
    }
};
