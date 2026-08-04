<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\PaymentSlip;
use Illuminate\Http\Request;

class PaymentSlipController extends Controller
{
    public function index()
    {
        return response()->json(
            PaymentSlip::orderByDesc('created_at')->get()
        );
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'student_id' => ['nullable', 'string', 'max:255'],
            'last_name' => ['nullable', 'string', 'max:255'],
            'first_name' => ['nullable', 'string', 'max:255'],
            'middle_name' => ['nullable', 'string', 'max:255'],
            'course' => ['nullable', 'string', 'max:255'],
            'section' => ['nullable', 'string', 'max:255'],
            'officer_name' => ['nullable', 'string', 'max:255'],
            'officer_designations' => ['nullable', 'string', 'max:255'],
            'items' => ['required', 'array'],
            'items.*.qualification' => ['required', 'string'],
            'items.*.amount' => ['required', 'numeric', 'min:0'],
            'total_amount' => ['required', 'numeric', 'min:0'],
        ]);

        $slip = PaymentSlip::create($validated);

        ActivityLog::record(
            'payment_slip.created',
            "Created payment slip for {$slip->last_name}, {$slip->first_name} ({$slip->student_id})"
        );

        return response()->json($slip, 201);
    }

    public function show(PaymentSlip $paymentSlip)
    {
        return response()->json($paymentSlip);
    }

    public function update(Request $request, PaymentSlip $paymentSlip)
    {
        $validated = $request->validate([
            'student_id' => ['sometimes', 'string', 'max:255'],
            'last_name' => ['sometimes', 'string', 'max:255'],
            'first_name' => ['sometimes', 'string', 'max:255'],
            'middle_name' => ['nullable', 'string', 'max:255'],
            'course' => ['sometimes', 'string', 'max:255'],
            'section' => ['sometimes', 'string', 'max:255'],
            'officer_name' => ['nullable', 'string', 'max:255'],
            'officer_designations' => ['nullable', 'string', 'max:255'],
            'items' => ['sometimes', 'array'],
            'items.*.qualification' => ['required', 'string'],
            'items.*.amount' => ['required', 'numeric', 'min:0'],
            'total_amount' => ['sometimes', 'numeric', 'min:0'],
        ]);

        $paymentSlip->update($validated);

        return response()->json($paymentSlip);
    }

    public function destroy(PaymentSlip $paymentSlip)
    {
        $name = "{$paymentSlip->last_name}, {$paymentSlip->first_name}";
        $paymentSlip->delete();

        ActivityLog::record(
            'payment_slip.deleted',
            "Deleted payment slip for {$name}"
        );

        return response()->json(['message' => 'Payment slip deleted']);
    }

    public function incrementPrinted(PaymentSlip $paymentSlip)
    {
        $paymentSlip->increment('printed_count');

        ActivityLog::record(
            'payment_slip.printed',
            "Printed payment slip for {$paymentSlip->last_name}, {$paymentSlip->first_name}"
        );

        return response()->json($paymentSlip);
    }

    public function incrementReleased(PaymentSlip $paymentSlip)
    {
        $paymentSlip->increment('released_count');

        ActivityLog::record(
            'payment_slip.released',
            "Released payment slip for {$paymentSlip->last_name}, {$paymentSlip->first_name}"
        );

        return response()->json($paymentSlip);
    }
}
