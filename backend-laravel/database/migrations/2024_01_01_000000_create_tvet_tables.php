<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('offices', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->string('code')->nullable();
            $table->string('coordinator_name');
            $table->string('coordinator_title')->default('TVET Coordinator');
            $table->timestamps();
        });

        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('email')->unique();
            $table->string('password');
            $table->string('api_token', 80)->nullable()->unique();
            $table->string('role')->default('STAFF');
            $table->foreignId('office_id')->nullable()->constrained()->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('document_types', function (Blueprint $table) {
            $table->id();
            $table->string('slug')->unique();
            $table->string('name');
            $table->string('prefix');
            $table->foreignId('active_template_id')->nullable()->unique()->constrained('document_templates')->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('document_templates', function (Blueprint $table) {
            $table->id();
            $table->foreignId('document_type_id')->constrained()->cascadeOnDelete();
            $table->string('original_name');
            $table->string('file_name');
            $table->string('mime_type');
            $table->string('path');
            $table->boolean('is_active')->default(false);
            $table->timestamps();
        });

        Schema::create('document_records', function (Blueprint $table) {
            $table->id();
            $table->string('code');
            $table->integer('year');
            $table->foreignId('document_type_id')->constrained()->cascadeOnDelete();
            $table->foreignId('template_id')->constrained('document_templates')->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->json('payload');
            $table->string('file_path');
            $table->string('file_url');
            $table->timestamps();
        });

        Schema::create('document_sequences', function (Blueprint $table) {
            $table->id();
            $table->foreignId('document_type_id')->constrained()->cascadeOnDelete();
            $table->integer('year');
            $table->integer('next_number')->default(1);
            $table->timestamps();

            $table->unique(['document_type_id', 'year']);
        });

        Schema::create('settings', function (Blueprint $table) {
            $table->id();
            $table->string('key')->unique();
            $table->text('value');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('settings');
        Schema::dropIfExists('document_sequences');
        Schema::dropIfExists('document_records');
        Schema::dropIfExists('document_templates');
        Schema::dropIfExists('document_types');
        Schema::dropIfExists('users');
        Schema::dropIfExists('offices');
    }
};
