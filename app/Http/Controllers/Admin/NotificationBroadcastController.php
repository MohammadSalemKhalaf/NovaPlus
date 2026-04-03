<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\BroadcastNotificationRequest;
use App\Services\Admin\BroadcastService;
use Illuminate\Http\JsonResponse;

class NotificationBroadcastController extends Controller
{
    public function __construct(private readonly BroadcastService $broadcastService)
    {
    }

    public function broadcast(BroadcastNotificationRequest $request): JsonResponse
    {
        $user = $request->user();
        $result = $this->broadcastService->broadcast($request->validated(), $user?->id);

        return response()->json([
            'success' => true,
            'message' => 'Broadcast notification sent successfully.',
            'data' => $result,
            'meta' => (object) [],
        ]);
    }
}
