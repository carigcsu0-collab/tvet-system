<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DocumentSequence;
use App\Models\DocumentType;
use Illuminate\Http\Request;

class DocumentCodeSettingController extends Controller
{
    public function index(Request $request)
    {
        $types = DocumentType::orderBy('name')->get();

        $data = $types->map(function (DocumentType $type) {
            $year = $type->codeYear();
            $sequence = DocumentSequence::firstOrCreate(
                ['document_type_id' => $type->id, 'year' => $year],
                ['next_number' => 1]
            );

            return [
                'slug' => $type->slug,
                'name' => $type->name,
                'prefix' => $type->prefix,
                'active_year' => $type->active_year,
                'year' => $year,
                'padding' => $type->padding,
                'next_number' => $sequence->next_number,
                'preview_code' => $type->formatCode($sequence->next_number),
            ];
        });

        return response()->json($data->values());
    }

    public function update(Request $request, string $slug)
    {
        $validated = $request->validate([
            'prefix' => ['required', 'string', 'max:50'],
            'active_year' => ['nullable', 'integer', 'min:2000', 'max:2999'],
            'padding' => ['required', 'integer', 'min:1', 'max:10'],
            'next_number' => ['required', 'integer', 'min:1'],
        ]);

        $type = DocumentType::where('slug', $slug)->firstOrFail();
        $type->prefix = $validated['prefix'];
        $type->padding = $validated['padding'];
        $type->active_year = $validated['active_year'] ?? null;
        $type->save();

        $year = $type->codeYear();
        $sequence = DocumentSequence::firstOrCreate(
            ['document_type_id' => $type->id, 'year' => $year],
            ['next_number' => $validated['next_number']]
        );
        $sequence->next_number = $validated['next_number'];
        $sequence->save();

        return response()->json([
            'slug' => $type->slug,
            'name' => $type->name,
            'prefix' => $type->prefix,
            'active_year' => $type->active_year,
            'year' => $year,
            'padding' => $type->padding,
            'next_number' => $sequence->next_number,
            'preview_code' => $type->formatCode($sequence->next_number),
        ]);
    }
}
