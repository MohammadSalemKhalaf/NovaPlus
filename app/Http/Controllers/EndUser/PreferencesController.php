<?php

namespace App\Http\Controllers\EndUser;

use App\Http\Controllers\Controller;
use App\Http\Requests\EndUser\PreferencesRequest;
use App\Services\EndUser\NotificationPreferencesService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PreferencesController extends Controller
{
    public function __construct(
        private NotificationPreferencesService $preferencesService
    ) {}

    /**
     * Get user notification preferences.
     * GET /api/v1/enduser/preferences
     */
    public function show(Request $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $preferences = $this->preferencesService->getPreferences($user);

        return response()->json([
            'success' => true,
            'message' => 'Preferences retrieved successfully',
            'data' => $preferences->toArray(),
        ], 200);
    }

    /**
     * Update user notification preferences.
     * PUT /api/v1/enduser/preferences
     */
    public function update(PreferencesRequest $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $preferences = $this->preferencesService->updatePreferences($user, $request->validated());

        return response()->json([
            'success' => true,
            'message' => 'Preferences updated successfully',
            'data' => $preferences->toArray(),
        ], 200);
    }
}
