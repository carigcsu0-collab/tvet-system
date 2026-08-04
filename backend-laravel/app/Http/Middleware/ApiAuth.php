<?php

namespace App\Http\Middleware;

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

        $user = User::where('api_token', $token)->first();

        if (! $user) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        auth()->setUser($user);

        return $next($request);
    }
}
