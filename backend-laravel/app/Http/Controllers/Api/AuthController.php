<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\ApiToken;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required'],
            'device_name' => ['nullable', 'string', 'max:255'],
        ]);

        $user = User::where('email', $validated['email'])->first();

        if (! $user || ! Hash::check($validated['password'], $user->password)) {
            return response()->json(['error' => 'Invalid credentials'], 401);
        }

        // Issue a token into the api_tokens table so each login gets its own
        // token. This lets the same account stay logged in on several devices
        // at once — a new login no longer overwrites the previous device's
        // token (which is what kicked the older device out before).
        $plainToken = Str::random(80);
        $user->apiTokens()->create([
            'token' => $plainToken,
            'device_name' => $validated['device_name'] ?? $request->userAgent(),
        ]);

        ActivityLog::record(
            'login',
            "User logged in: {$user->name} ({$user->email})"
        );

        return response()->json([
            'token' => $plainToken,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role,
            ],
        ]);
    }

    public function me(Request $request)
    {
        return response()->json(auth()->user()->load('office:id,name,coordinator_name,coordinator_title'));
    }

    /**
     * Revokes only the token used to make this request, leaving every other
     * device's session intact.
     */
    public function logout(Request $request)
    {
        $header = $request->header('Authorization', '');
        $token = trim(preg_replace('/^bearer\s+/i', '', $header));
        if ($token !== '') {
            ApiToken::where('token', $token)->delete();
        }

        $user = $request->user();
        ActivityLog::record(
            'logout',
            "User logged out: " . ($user->name ?? 'unknown')
        );

        return response()->json(['message' => 'Logged out']);
    }
}
