<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Assessee;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ScholarBillingController extends Controller
{
    public function receiveBankCheck(Request $request)
    {
        $validated = $request->validate([
            'billing_type' => ['required', 'in:assessment,training'],
            'ids' => ['required', 'array', 'min:1'],
            'ids.*' => ['required', 'integer', 'distinct', 'exists:assessee_trainees,id'],
            'training_batch_id' => ['required_if:billing_type,training', 'nullable', 'integer', 'exists:training_batches,id'],
        ]);

        return DB::transaction(function () use ($validated) {
            $query = Assessee::whereIn('id', $validated['ids']);

            if ($validated['billing_type'] === 'assessment') {
                $query->where('assessment_candidate_type', 'external_scholar');
            } else {
                $query->where('training_candidate_type', 'scholar')
                    ->where('training_batch_id', $validated['training_batch_id']);
            }

            if ($query->count() !== count($validated['ids'])) {
                throw ValidationException::withMessages([
                    'ids' => ['The selected records do not match this scholar billing.'],
                ]);
            }

            $updated = $query->where('assessment_fee_paid', false)
                ->update(['assessment_fee_paid' => true]);

            ActivityLog::record(
                'scholar_billing.bank_check_received',
                'Received bank check for ' . $updated . ' ' .
                ($validated['billing_type'] === 'assessment' ? 'assessment' : 'training') .
                ' scholar(s)'
            );

            return response()->json(['updated' => $updated]);
        });
    }
}
