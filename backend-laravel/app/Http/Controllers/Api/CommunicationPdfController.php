<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Symfony\Component\Process\Exception\ProcessFailedException;
use Symfony\Component\Process\Process;

class CommunicationPdfController extends Controller
{
    /**
     * Renders a full free-form communication document (letterhead + editable
     * body HTML produced by the frontend rich-text editor) into a PDF using
     * LibreOffice headless conversion, which gives much closer-to-Word
     * fidelity than a pure-PHP HTML-to-PDF renderer.
     */
    public function render(Request $request)
    {
        $validated = $request->validate([
            'html' => 'required|string',
        ]);

        // The frontend sends a complete, self-contained HTML document
        // (letterhead + editable body, fonts/images embedded as base64
        // data URIs), so it's written to disk as-is for conversion.
        $document = $validated['html'];

        $tmpDir = storage_path('app/tmp');
        if (! is_dir($tmpDir)) {
            mkdir($tmpDir, 0755, true);
        }

        $uuid = (string) Str::uuid();
        $htmlPath = $tmpDir.DIRECTORY_SEPARATOR.$uuid.'.html';
        $pdfPath = $tmpDir.DIRECTORY_SEPARATOR.$uuid.'.pdf';

        file_put_contents($htmlPath, $document);

        try {
            $soffice = $this->resolveSofficeBinary();

            $process = new Process([
                $soffice,
                '--headless',
                '--norestore',
                '--convert-to', 'pdf',
                '--outdir', $tmpDir,
                $htmlPath,
            ]);
            $process->setTimeout(80);
            $process->run();

            if (! $process->isSuccessful()) {
                Log::error('LibreOffice conversion failed', [
                    'output' => $process->getOutput(),
                    'error' => $process->getErrorOutput(),
                ]);
                throw new ProcessFailedException($process);
            }

            if (! file_exists($pdfPath)) {
                return response()->json(['error' => 'PDF conversion did not produce an output file.'], 500);
            }

            $pdfBytes = file_get_contents($pdfPath);

            return response($pdfBytes, 200, [
                'Content-Type' => 'application/pdf',
                'Content-Disposition' => 'inline; filename="document.pdf"',
            ]);
        } catch (\Throwable $e) {
            Log::error('Communication PDF render failed: '.$e->getMessage());

            return response()->json([
                'error' => 'Failed to render PDF. Make sure LibreOffice is installed on the server.',
                'details' => $e->getMessage(),
            ], 500);
        } finally {
            @unlink($htmlPath);
            @unlink($pdfPath);
        }
    }

    private function resolveSofficeBinary(): string
    {
        $configured = env('LIBREOFFICE_PATH');
        if ($configured && file_exists($configured)) {
            return $configured;
        }

        $candidates = [
            'C:\\Program Files\\LibreOffice\\program\\soffice.exe',
            'C:\\Program Files (x86)\\LibreOffice\\program\\soffice.exe',
            '/usr/bin/soffice',
            '/usr/bin/libreoffice',
        ];

        foreach ($candidates as $candidate) {
            if (file_exists($candidate)) {
                return $candidate;
            }
        }

        // Fall back to relying on PATH.
        return 'soffice';
    }
}
