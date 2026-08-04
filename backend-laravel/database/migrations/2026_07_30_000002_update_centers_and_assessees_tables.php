<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('centers', function (Blueprint $table) {
            if (! Schema::hasColumn('centers', 'qualifications')) {
                $table->text('qualifications')->nullable()->after('training_fee');
            }
            if (! Schema::hasColumn('centers', 'expiration_date')) {
                $table->date('expiration_date')->nullable()->after('qualifications');
            }
            if (! Schema::hasColumn('centers', 'audit_date')) {
                $table->date('audit_date')->nullable()->after('expiration_date');
            }
        });

        $assesseeTable = Schema::hasTable('assessee_trainees') ? 'assessee_trainees' : 'assessees';
        Schema::table($assesseeTable, function (Blueprint $table) use ($assesseeTable) {
            if (! Schema::hasColumn($assesseeTable, 'last_name')) {
                $table->string('last_name')->nullable()->after('name');
                $table->string('first_name')->nullable()->after('last_name');
                $table->string('middle_name')->nullable()->after('first_name');
                $table->string('birthday')->nullable()->after('middle_name');
                $table->integer('age')->nullable()->after('birthday');
                $table->string('uli')->nullable()->after('age');
                $table->string('reference_number')->nullable()->after('uli');
                $table->string('contact_number')->nullable()->after('reference_number');
                $table->string('email')->nullable()->after('contact_number');
                $table->string('last_school_attended')->nullable()->after('email');
                $table->boolean('registration_form')->default(false)->after('last_school_attended');
                $table->boolean('medical_certificate')->default(false)->after('registration_form');
                $table->boolean('brgy_indigency')->default(false)->after('medical_certificate');
                $table->boolean('brgy_clearance')->default(false)->after('brgy_indigency');
                $table->boolean('tor_form137_138')->default(false)->after('brgy_clearance');
            }
        });
    }

    public function down(): void
    {
        Schema::table('centers', function (Blueprint $table) {
            $table->dropColumn(['qualifications', 'expiration_date', 'audit_date']);
        });

        $assesseeTable = Schema::hasTable('assessee_trainees') ? 'assessee_trainees' : 'assessees';
        Schema::table($assesseeTable, function (Blueprint $table) {
            $table->dropColumn([
                'last_name', 'first_name', 'middle_name', 'birthday', 'age',
                'uli', 'reference_number', 'contact_number', 'email',
                'last_school_attended', 'registration_form', 'medical_certificate',
                'brgy_indigency', 'brgy_clearance', 'tor_form137_138',
            ]);
        });
    }
};
