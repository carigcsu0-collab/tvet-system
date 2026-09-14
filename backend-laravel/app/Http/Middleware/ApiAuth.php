<?php

namespace App\Http\Middleware;

use App\Models\ApiToken;
use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class ApiAuth
{
    public function handle(Request $request, Closure $next): Response
    {
        $header = $request->header('Authorization', '');
        $token = trim(preg_replace('/^bearer\s+/i', '', $header));

        if (empty($token)) {
            $token = (string) $request->query('api_token', '');
        }

        if (empty($token)) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        // Look the token up in the multi-token table first so several devices
        // can stay logged in at once.
        $user = null;
        $apiToken = ApiToken::where('token', $token)->first();
        if ($apiToken !== null) {
            $user = $apiToken->user;
            // Touch last_used_at without firing a full model update storm.
            $apiToken->forceFill(['last_used_at' => now()])->save();
        }

        // Backward compatibility: tokens issued before the api_tokens table
        // are still stored on the user row.
        if ($user === null) {
            $user = User::where('api_token', $token)->first();
        }

        if (! $user) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        auth()->setUser($user);

        return $next($request);
    }
}
