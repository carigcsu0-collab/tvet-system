<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class UserController extends Controller
{
    public function index()
    {
        return response()->json(User::orderBy('name')->get());
    }

    public function acManagers()
    {
        $acManagers = User::where(function ($query) {
            $query->whereJsonContains('designations', 'AC Manager')
                  ->orWhereJsonContains('designations', 'ac_manager')
                  ->orWhereJsonContains('designations', 'AC Manager');
        })->orderBy('name')->get();

        return response()->json($acManagers);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'extension_name' => ['nullable', 'string', 'max:255'],
            'designations' => ['nullable', 'array'],
            'designations.*' => ['nullable', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', Rule::unique('users', 'email')],
            'password' => ['required', 'string', 'min:6', 'max:255'],
            'role' => ['required', 'string', 'in:admin,coordinator,staff'],
        ]);

        // Filter out empty designations
        if (isset($validated['designations']) && is_array($validated['designations'])) {
            $validated['designations'] = array_filter($validated['designations'], function($value) {
                return !empty(trim($value));
            });
            if (empty($validated['designations'])) {
                $validated['designations'] = null;
            }
        }

        $user = User::create($validated);

        ActivityLog::record(
            'user.created',
            "Created user account: {$user->name} ({$user->email})"
        );

        return response()->json($user, 201);
    }

    public function update(Request $request, User $user)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'extension_name' => ['nullable', 'string', 'max:255'],
            'designations' => ['nullable', 'array'],
            'designations.*' => ['nullable', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', Rule::unique('users', 'email')->ignore($user->id)],
            'password' => ['nullable', 'string', 'min:6', 'max:255'],
            'role' => ['required', 'string', 'in:admin,coordinator,staff'],
        ]);

        // Filter out empty designations
        if (isset($validated['designations']) && is_array($validated['designations'])) {
            $validated['designations'] = array_filter($validated['designations'], function($value) {
                return !empty(trim($value));
            });
            if (empty($validated['designations'])) {
                $validated['designations'] = null;
            }
        }

        if (empty($validated['password'])) {
            unset($validated['password']);
        }

        $user->update($validated);

        ActivityLog::record(
            'user.updated',
            "Updated user account: {$user->name} ({$user->email})"
        );

        return response()->json($user);
    }

    public function destroy(User $user)
    {
        $name = $user->name;
        $user->delete();

        ActivityLog::record(
            'user.deleted',
            "Deleted user account: {$name}"
        );

        return response()->json(['message' => 'User deleted']);
    }
}
