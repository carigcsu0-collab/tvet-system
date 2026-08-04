<?php

namespace Database\Seeders;

use App\Models\DocumentRecord;
use App\Models\DocumentTemplate;
use App\Models\DocumentType;
use App\Models\Office;
use App\Models\Setting;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $office = Office::firstOrCreate(
            ['name' => 'TVET Main Office'],
            [
                'code' => null,
                'coordinator_name' => 'Engr. Juan Dela Cruz',
                'coordinator_title' => 'TVET Coordinator',
            ]
        );

        User::firstOrCreate(
            ['email' => 'coordinator@tvet.gov'],
            [
                'name' => 'TVET Coordinator',
                'password' => Hash::make('password'),
                'api_token' => Str::random(80),
                'role' => 'COORDINATOR',
                'office_id' => $office->id,
            ]
        );

        $desiredTypes = [
            'certificate-of-appearance' => 'Certificate of Appearance',
            'internal-communication' => 'Internal Communication',
            'external-communication' => 'External Communication',
            'endorsement-communication' => 'Endorsement',
            'report-on-assessment-proceedings' => 'Report on Assessment Proceedings',
            'performance-evaluation-instrument' => 'Performance Evaluation Instrument',
        ];

        foreach ($desiredTypes as $slug => $name) {
            $matches = DocumentType::where('name', $name)
                ->orderBy('id')
                ->get();

            $canonical = $matches->firstWhere('slug', $slug);

            if (! $canonical) {
                $canonical = $matches->first();
                if ($canonical) {
                    $canonical->slug = $slug;
                    $canonical->save();
                }
            }

            foreach ($matches as $match) {
                if ($canonical && $match->id === $canonical->id) {
                    continue;
                }
                if ($canonical) {
                    DocumentRecord::where('document_type_id', $match->id)
                        ->update(['document_type_id' => $canonical->id]);
                }
                $match->delete();
            }

            DocumentType::updateOrCreate(
                ['slug' => $slug],
                [
                    'name' => $name,
                    'prefix' => match ($slug) {
                        'certificate-of-appearance' => 'TVET-25281',
                        'internal-communication' => 'TVET-25273',
                        'external-communication' => 'TVET-25270',
                        'endorsement-communication' => 'TVET-END',
                        'report-on-assessment-proceedings' => 'TVET-RAP',
                        'performance-evaluation-instrument' => 'TVET-PEI',
                        default => 'TVET',
                    },
                    'padding' => 3,
                    'active_year' => null,
                ]
            );
        }

        $coa = DocumentType::where('slug', 'certificate-of-appearance')->first();

        Setting::firstOrCreate(
            ['key' => 'DEFAULT_COORDINATOR_NAME'],
            ['value' => 'Engr. Juan Dela Cruz']
        );

        Setting::firstOrCreate(
            ['key' => 'DEFAULT_COORDINATOR_TITLE'],
            ['value' => 'TVET Coordinator']
        );

        Setting::firstOrCreate(
            ['key' => 'DEFAULT_CAMPUS_NAME'],
            ['value' => 'Cagayan State University - Carig Campus']
        );

        Setting::firstOrCreate(
            ['key' => 'DEFAULT_ISSUED_AT'],
            ['value' => 'Cagayan State University - Carig Campus']
        );

        $template = DocumentTemplate::firstOrCreate(
            ['document_type_id' => $coa->id, 'original_name' => 'certificate_of_appearance.docx'],
            [
                'file_name' => 'certificate_of_appearance.docx',
                'mime_type' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                'path' => 'templates/certificate_of_appearance.docx',
                'is_active' => true,
            ]
        );

        if ($coa->wasRecentlyCreated || $coa->active_template_id === null) {
            $coa->update(['active_template_id' => $template->id]);
        }

        $rap = DocumentType::where('slug', 'report-on-assessment-proceedings')->first();
        if ($rap) {
            $rapTemplate = DocumentTemplate::firstOrCreate(
                ['document_type_id' => $rap->id, 'original_name' => 'report_on_assessment_proceedings.docx'],
                [
                    'file_name' => 'report_on_assessment_proceedings.docx',
                    'mime_type' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                    'path' => 'templates/report_on_assessment_proceedings.docx',
                    'is_active' => true,
                ]
            );

            if ($rap->wasRecentlyCreated || $rap->active_template_id === null) {
                $rap->update(['active_template_id' => $rapTemplate->id]);
            }
        }

        $pei = DocumentType::where('slug', 'performance-evaluation-instrument')->first();
        if ($pei) {
            $peiTemplate = DocumentTemplate::firstOrCreate(
                ['document_type_id' => $pei->id, 'original_name' => 'performance_evaluation_instrument.docx'],
                [
                    'file_name' => 'performance_evaluation_instrument.docx',
                    'mime_type' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                    'path' => 'templates/performance_evaluation_instrument.docx',
                    'is_active' => true,
                ]
            );

            if ($pei->wasRecentlyCreated || $pei->active_template_id === null) {
                $pei->update(['active_template_id' => $peiTemplate->id]);
            }
        }
    }
}
