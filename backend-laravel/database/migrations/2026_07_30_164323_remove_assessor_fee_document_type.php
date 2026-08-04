<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $type = DB::table('document_types')->where('slug', 'assessor-fee')->first();
        if ($type) {
            DB::table('document_sequences')->where('document_type_id', $type->id)->delete();
            DB::table('document_records')->where('document_type_id', $type->id)->delete();
            DB::table('document_templates')->where('document_type_id', $type->id)->delete();
            DB::table('document_types')->where('id', $type->id)->delete();
        }
    }

    public function down(): void
    {
        // Cannot restore deleted records
    }
};
