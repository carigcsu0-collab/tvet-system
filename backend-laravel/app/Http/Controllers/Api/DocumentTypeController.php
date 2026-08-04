<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DocumentSequence;
use App\Models\DocumentType;

class DocumentTypeController extends Controller
{
    public function index()
    {
        return response()->json(
            DocumentType::with('activeTemplate:id,original_name,is_active')->orderBy('name')->get()
        );
    }

    public function show(string $slug)
    {
        return response()->json(
            DocumentType::where('slug', $slug)->with('activeTemplate:id,original_name,is_active,path')->firstOrFail()
        );
    }

    public function nextCode(string $slug)
    {
        $type = DocumentType::where('slug', $slug)->firstOrFail();
        $year = $type->codeYear();

        $sequence = DocumentSequence::firstOrCreate(
            ['document_type_id' => $type->id, 'year' => $year],
            ['next_number' => 1]
        );

        return response()->json([
            'prefix' => $type->prefix,
            'active_year' => $type->active_year,
            'year' => $year,
            'padding' => $type->padding,
            'number' => $sequence->next_number,
            'code' => $type->formatCode($sequence->next_number),
        ]);
    }
}
