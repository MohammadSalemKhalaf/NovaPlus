<?php

namespace App\Http\Controllers;

use App\Http\Requests\Chat\ListConversationMessagesRequest;
use App\Http\Resources\ConversationMessageResource;
use App\Services\Chat\ChatService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ConversationMessageController extends Controller
{
    public function __construct(private readonly ChatService $chatService)
    {
    }

    public function index(ListConversationMessagesRequest $request, int $id): JsonResponse
    {
        $user = $request->user('sanctum');

        $messages = $this->chatService->listMessagesForActor(
            actor: $user,
            conversationId: $id,
            perPage: (int) $request->integer('per_page', 30),
        );

        if ($messages === null) {
            return response()->json([
                'success' => false,
                'message' => 'Conversation not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Messages fetched successfully.',
            'data' => ConversationMessageResource::collection($messages->items()),
            'meta' => [
                'current_page' => $messages->currentPage(),
                'per_page' => $messages->perPage(),
                'total' => $messages->total(),
                'last_page' => $messages->lastPage(),
            ],
        ]);
    }

    public function markAsRead(Request $request, int $id): JsonResponse
    {
        $user = $request->user('sanctum');
        $updatedCount = $this->chatService->markConversationAsRead($user, $id);

        if ($updatedCount === null) {
            return response()->json([
                'success' => false,
                'message' => 'Conversation not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Conversation marked as read.',
            'data' => [
                'updated_count' => $updatedCount,
            ],
            'meta' => (object) [],
        ]);
    }
}
