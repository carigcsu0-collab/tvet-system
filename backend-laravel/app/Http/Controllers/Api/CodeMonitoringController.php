<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\CodeMonitoringRecord;
use Illuminate\Http\Request;

class CodeMonitoringController extends Controller
{
    private function validatedData(Request $request): array
    {
        return $request->validate([
            'type' => ['required', 'in:IC,EC,MEMO,CA'],
            'code' => ['required', 'string', 'max:255'],
            'title' => ['required', 'string', 'max:255'],
            'date' => ['required', 'date_format:Y-m-d'],
        ]);
    }

    public function index()
    {
        return response()->json(
            CodeMonitoringRecord::orderByDesc('date')->orderByDesc('id')->get()
        );
    }

    public function store(Request $request)
    {
        $record = CodeMonitoringRecord::create($this->validatedData($request));
        ActivityLog::record('code_monitoring.created', "Added code monitoring record: {$record->code}");

        return response()->json($record, 201);
    }

    public function update(Request $request, CodeMonitoringRecord $codeMonitoring)
    {
        $codeMonitoring->update($this->validatedData($request));
        ActivityLog::record('code_monitoring.updated', "Updated code monitoring record: {$codeMonitoring->code}");

        return response()->json($codeMonitoring);
    }

    public function destroy(CodeMonitoringRecord $codeMonitoring)
    {
        $code = $codeMonitoring->code;
        $codeMonitoring->delete();
        ActivityLog::record('code_monitoring.deleted', "Deleted code monitoring record: {$code}");

        return response()->json(['message' => 'Code monitoring record deleted']);
    }
}
