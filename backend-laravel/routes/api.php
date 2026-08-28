<?php

use App\Http\Controllers\Api\AssesseeController;
use App\Http\Controllers\Api\AssessorController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CenterController;
use App\Http\Controllers\Api\CommunicationPdfController;
use App\Http\Controllers\Api\DocumentCodeSettingController;
use App\Http\Controllers\Api\DocumentController;
use App\Http\Controllers\Api\DocumentTypeController;
use App\Http\Controllers\Api\OfficeController;
use App\Http\Controllers\Api\PaymentSlipController;
use App\Http\Controllers\Api\ActivityLogController;
use App\Http\Controllers\Api\PeiDocumentController;
use App\Http\Controllers\Api\RapDocumentController;
use App\Http\Controllers\Api\SettingController;
use App\Http\Controllers\Api\UserController;
use Illuminate\Support\Facades\Route;

Route::post('/auth/login', [AuthController::class, 'login']);

Route::middleware('api.auth')->group(function () {
    Route::get('/auth/me', [AuthController::class, 'me']);

    Route::get('/offices', [OfficeController::class, 'index']);

    Route::get('/document-types', [DocumentTypeController::class, 'index']);
    Route::get('/document-types/{slug}', [DocumentTypeController::class, 'show']);
    Route::get('/document-types/{slug}/next-code', [DocumentTypeController::class, 'nextCode']);

    Route::get('/document-code-settings', [DocumentCodeSettingController::class, 'index']);
    Route::put('/document-code-settings/{slug}', [DocumentCodeSettingController::class, 'update']);

    Route::post('/documents/render-communication-pdf', [CommunicationPdfController::class, 'render']);
    Route::post('/documents/{typeSlug}/generate', [DocumentController::class, 'generate']);
    Route::post('/documents/{typeSlug}', [DocumentController::class, 'store']);
    Route::get('/documents', [DocumentController::class, 'index']);
    Route::get('/documents/{code}', [DocumentController::class, 'show']);
    Route::put('/documents/{code}', [DocumentController::class, 'update']);
    Route::delete('/documents/{code}', [DocumentController::class, 'destroy']);
    Route::get('/documents/{code}/download', [DocumentController::class, 'download']);
    Route::post('/documents/{code}/receive', [DocumentController::class, 'receive']);
    Route::put('/documents/{code}/status', [DocumentController::class, 'updateStatus']);

    Route::get('/settings/{key}', [SettingController::class, 'show']);
    Route::put('/settings/{key}', [SettingController::class, 'update']);

    Route::get('/centers', [CenterController::class, 'index']);
    Route::post('/centers', [CenterController::class, 'store']);
    Route::put('/centers/{center}', [CenterController::class, 'update']);
    Route::delete('/centers/{center}', [CenterController::class, 'destroy']);
    Route::post('/centers/{center}/complete-audit', [CenterController::class, 'completeAudit']);

    Route::get('/assessees', [AssesseeController::class, 'index']);
    Route::post('/assessees', [AssesseeController::class, 'store']);
    Route::post('/assessees/bulk-update', [AssesseeController::class, 'bulkUpdate']);
    Route::put('/assessees/{assessee}', [AssesseeController::class, 'update']);
    Route::delete('/assessees/{assessee}', [AssesseeController::class, 'destroy']);

    Route::get('/assessors', [AssessorController::class, 'index']);
    Route::post('/assessors', [AssessorController::class, 'store']);
    Route::put('/assessors/{assessor}', [AssessorController::class, 'update']);
    Route::delete('/assessors/{assessor}', [AssessorController::class, 'destroy']);

    Route::get('/rap-documents', [RapDocumentController::class, 'index']);
    Route::post('/rap-documents', [RapDocumentController::class, 'store']);
    Route::get('/rap-documents/{rapDocument}', [RapDocumentController::class, 'show']);
    Route::put('/rap-documents/{rapDocument}', [RapDocumentController::class, 'update']);
    Route::delete('/rap-documents/{rapDocument}', [RapDocumentController::class, 'destroy']);

    Route::get('/pei-documents', [PeiDocumentController::class, 'index']);
    Route::post('/pei-documents', [PeiDocumentController::class, 'store']);
    Route::get('/pei-documents/{peiDocument}', [PeiDocumentController::class, 'show']);
    Route::put('/pei-documents/{peiDocument}', [PeiDocumentController::class, 'update']);
    Route::delete('/pei-documents/{peiDocument}', [PeiDocumentController::class, 'destroy']);

    Route::get('/users', [UserController::class, 'index']);
    Route::get('/users/ac-managers', [UserController::class, 'acManagers']);
    Route::post('/users', [UserController::class, 'store']);
    Route::put('/users/{user}', [UserController::class, 'update']);
    Route::delete('/users/{user}', [UserController::class, 'destroy']);

    Route::get('/activity-logs', [ActivityLogController::class, 'index']);

    Route::get('/payment-slips', [PaymentSlipController::class, 'index']);
    Route::post('/payment-slips', [PaymentSlipController::class, 'store']);
    Route::get('/payment-slips/{paymentSlip}', [PaymentSlipController::class, 'show']);
    Route::put('/payment-slips/{paymentSlip}', [PaymentSlipController::class, 'update']);
    Route::delete('/payment-slips/{paymentSlip}', [PaymentSlipController::class, 'destroy']);
    Route::post('/payment-slips/{paymentSlip}/printed', [PaymentSlipController::class, 'incrementPrinted']);
    Route::post('/payment-slips/{paymentSlip}/released', [PaymentSlipController::class, 'incrementReleased']);
});
