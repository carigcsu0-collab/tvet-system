<?php

namespace Tests\Feature;

use App\Http\Middleware\ApiAuth;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Foundation\Testing\TestCase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class ScholarBillingSessionTest extends TestCase
{
    public function createApplication()
    {
        $app = require __DIR__.'/../../bootstrap/app.php';
        $app->make(\Illuminate\Contracts\Console\Kernel::class)->bootstrap();

        return $app;
    }

    protected function setUp(): void
    {
        parent::setUp();

        config(['database.default' => 'sqlite', 'database.connections.sqlite.database' => ':memory:']);
        DB::purge('sqlite');
        $this->withoutMiddleware(ApiAuth::class);

        Schema::create('centers', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('type');
        });
        Schema::create('training_batches', function (Blueprint $table) {
            $table->id();
        });
        Schema::create('assessee_trainees', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('assessment_center_id');
            $table->unsignedBigInteger('training_batch_id')->nullable();
            $table->string('assessment_candidate_type')->nullable();
            $table->string('training_candidate_type')->nullable();
            $table->string('name');
            $table->string('last_name')->nullable();
            $table->string('first_name')->nullable();
            $table->string('middle_name')->nullable();
            $table->string('extension_name')->nullable();
            $table->string('birthday')->nullable();
            $table->integer('age')->nullable();
            $table->string('qualification');
            $table->string('competency')->nullable();
            $table->boolean('assessment_fee_paid')->default(false);
            $table->boolean('processing_fee_paid')->default(false);
            $table->boolean('registration_form')->default(false);
            $table->boolean('medical_certificate')->default(false);
            $table->boolean('brgy_indigency')->default(false);
            $table->boolean('brgy_clearance')->default(false);
            $table->boolean('tor_form137_138')->default(false);
            $table->timestamps();
        });
        Schema::create('activity_logs', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('user_id')->nullable();
            $table->string('action');
            $table->text('description')->nullable();
            $table->string('ip_address')->nullable();
            $table->timestamps();
        });
        $migration = require __DIR__.'/../../database/migrations/2026_11_20_000001_add_assessment_session_to_assessee_trainees.php';
        $migration->up();
        $codeMigration = require __DIR__.'/../../database/migrations/2026_11_20_000003_create_code_monitoring_records_table.php';
        $codeMigration->up();
        DB::table('centers')->insert(['id' => 1, 'name' => 'Center', 'type' => 'assessment']);
    }

    public function test_session_is_saved_validated_and_can_be_cleared_in_bulk(): void
    {
        $data = [
            'assessment_center_id' => 1,
            'assessment_candidate_type' => 'external_scholar',
            'first_name' => 'A',
            'last_name' => 'Scholar',
            'birthday' => '2000-01-01',
            'age' => 26,
            'qualification' => 'EIM',
            'assessment_session' => 'AM',
        ];

        $id = $this->postJson('/api/v1/assessees', $data)
            ->assertCreated()->assertJsonPath('assessment_session', 'AM')->json('id');
        $this->putJson("/api/v1/assessees/{$id}", [...$data, 'assessment_session' => 'PM'])
            ->assertOk()->assertJsonPath('assessment_session', 'PM');
        $this->postJson('/api/v1/assessees/bulk-update', [
            'ids' => [$id], 'assessment_session' => null,
        ])->assertOk()->assertJsonPath('updated', 1);
        $this->assertDatabaseHas('assessee_trainees', ['id' => $id, 'assessment_session' => null]);
        $this->postJson('/api/v1/assessees', [...$data, 'assessment_session' => 'night'])
            ->assertUnprocessable()->assertJsonValidationErrors('assessment_session');
    }

    public function test_receipt_only_marks_selected_external_scholars_paid(): void
    {
        DB::table('assessee_trainees')->insert([
            ['id' => 1, 'assessment_center_id' => 1, 'name' => 'Scholar', 'qualification' => 'EIM', 'assessment_candidate_type' => 'external_scholar'],
            ['id' => 2, 'assessment_center_id' => 1, 'name' => 'Walk-in', 'qualification' => 'EIM', 'assessment_candidate_type' => 'external_walk_in'],
            ['id' => 3, 'assessment_center_id' => 1, 'name' => 'Other scholar', 'qualification' => 'EIM', 'assessment_candidate_type' => 'external_scholar'],
            ['id' => 4, 'assessment_center_id' => 1, 'name' => 'Unselected scholar', 'qualification' => 'EIM', 'assessment_candidate_type' => 'external_scholar'],
        ]);
        $this->postJson('/api/v1/scholar-billings/receive-bank-check', [
            'billing_type' => 'assessment', 'ids' => [1, 2],
        ])->assertUnprocessable();
        $this->assertDatabaseHas('assessee_trainees', ['id' => 1, 'assessment_fee_paid' => false]);

        $this->postJson('/api/v1/scholar-billings/receive-bank-check', [
            'billing_type' => 'assessment', 'ids' => [1, 3],
        ])->assertOk()->assertJsonPath('updated', 2);
        $this->assertDatabaseHas('assessee_trainees', ['id' => 1, 'assessment_fee_paid' => true]);
        $this->assertDatabaseHas('assessee_trainees', ['id' => 2, 'assessment_fee_paid' => false]);
        $this->assertDatabaseHas('assessee_trainees', ['id' => 3, 'assessment_fee_paid' => true]);
        $this->assertDatabaseHas('assessee_trainees', ['id' => 4, 'assessment_fee_paid' => false]);
    }

    public function test_manual_codes_can_be_monitored_without_generating_documents(): void
    {
        $data = ['type' => 'IC', 'code' => 'IC-026', 'title' => 'Letter', 'date' => '2026-11-20'];
        $id = $this->postJson('/api/v1/code-monitoring', $data)
            ->assertCreated()->assertJsonPath('code', 'IC-026')->json('id');
        $this->getJson('/api/v1/code-monitoring')
            ->assertOk()->assertJsonFragment($data);
        $this->putJson("/api/v1/code-monitoring/{$id}", [...$data, 'type' => 'CA', 'title' => 'Certificate'])
            ->assertOk()->assertJsonPath('type', 'CA')->assertJsonPath('title', 'Certificate');
        $this->postJson('/api/v1/code-monitoring', [...$data, 'type' => 'OTHER'])
            ->assertUnprocessable()->assertJsonValidationErrors('type');
        $this->postJson('/api/v1/code-monitoring', [...$data, 'date' => '2026-02-31'])
            ->assertUnprocessable()->assertJsonValidationErrors('date');
        $this->deleteJson("/api/v1/code-monitoring/{$id}")->assertOk();
        $this->assertDatabaseMissing('code_monitoring_records', ['id' => $id]);
    }

    public function test_meal_removal_drops_all_related_tables_and_rollback_restores_empty_schema(): void
    {
        $prepare = require __DIR__.'/../../database/migrations/2026_09_19_235959_prepare_meal_computations_table.php';
        $details = require __DIR__.'/../../database/migrations/2026_09_20_000001_create_meal_funds_and_items_tables.php';
        $remove = require __DIR__.'/../../database/migrations/2026_11_20_000002_remove_meal_computations_tables.php';
        $prepare->up();
        $details->up();
        DB::table('meal_computations')->insert(['id' => 1, 'title' => 'Meals']);
        DB::table('meal_funds')->insert(['meal_computation_id' => 1, 'amount' => 100]);
        DB::table('meal_items')->insert(['meal_computation_id' => 1, 'name' => 'Lunch']);

        $remove->up();
        foreach (['meal_computations', 'meal_funds', 'meal_items'] as $table) {
            $this->assertFalse(Schema::hasTable($table));
        }
        $remove->down();
        foreach (['meal_computations', 'meal_funds', 'meal_items'] as $table) {
            $this->assertTrue(Schema::hasTable($table));
            $this->assertSame(0, DB::table($table)->count());
        }
    }
}
