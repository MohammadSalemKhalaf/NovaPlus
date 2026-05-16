<?php

namespace App\Http\Controllers\EndUser;

use App\Http\Controllers\Controller;
use App\Http\Requests\EndUser\MarkNotificationReadRequest;
use App\Http\Requests\EndUser\NotificationIndexRequest;
use App\Http\Resources\EndUserNotificationResource;
use App\Services\EndUser\NotificationInboxService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationsController extends Controller
{
    public function __construct(private readonly NotificationInboxService $notificationInboxService)
    {
    }

    public function index(NotificationIndexRequest $request): JsonResponse
    {
        $user = $request->user('sanctum');

        $notifications = $this->notificationInboxService->list($user, [
            'per_page' => $request->integer('per_page', 15),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Notifications retrieved successfully',
            'data' => EndUserNotificationResource::collection($notifications->items()),
            'meta' => [
                'current_page' => $notifications->currentPage(),
                'per_page' => $notifications->perPage(),
                'total' => $notifications->total(),
                'last_page' => $notifications->lastPage(),
            ],
        ]);
    }

    public function markAsRead(MarkNotificationReadRequest $request, int $id): JsonResponse
    {
        $user = $request->user('sanctum');

        if (!$this->notificationInboxService->existsForUser($user, $id)) {
            return response()->json([
                'success' => false,
                'message' => 'Notification not found',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        $this->notificationInboxService->markAsRead($user, $id);

        return response()->json([
            'success' => true,
            'message' => 'Notification marked as read',
            'data' => [
                'id' => $id,
                'is_read' => true,
            ],
            'meta' => (object) [],
        ]);
    }

    public function markAllAsRead(Request $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $updatedCount = $this->notificationInboxService->markAllAsRead($user);

        return response()->json([
            'success' => true,
            'message' => 'All notifications marked as read',
            'data' => [
                'updated_count' => $updatedCount,
            ],
            'meta' => (object) [],
        ]);
    }

    public function unreadCount(Request $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $count = $this->notificationInboxService->getUnreadCount($user);

        return response()->json([
            'success' => true,
            'message' => 'Unread count retrieved successfully',
            'data' => [
                'count' => $count,
            ],
            'meta' => (object) [],
        ]);
    }
}
