<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Setting;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

class SettingController extends Controller
{
    public function show(string $key)
    {
        $value = Cache::remember("setting:{$key}", now()->addHours(1), function () use ($key) {
            return Setting::where('key', $key)->value('value');
        });

        return response()->json([
            'key' => $key,
            'value' => $value,
        ]);
    }

    public function update(Request $request, string $key)
    {
        $validated = $request->validate([
            'value' => ['required', 'string'],
        ]);

        $setting = Setting::firstOrCreate(
            ['key' => $key],
            ['value' => '']
        );
        $setting->value = $validated['value'];
        $setting->save();

        Cache::forget("setting:{$key}");

        return response()->json([
            'key' => $setting->key,
            'value' => $setting->value,
        ]);
    }
}
