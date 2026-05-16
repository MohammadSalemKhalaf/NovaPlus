<?php

namespace App\Http\Controllers\EndUser;

use App\Http\Controllers\Controller;
use App\Http\Requests\EndUser\StartConversationRequest;
use App\Services\Chat\ChatService;
use Illuminate\Http\JsonResponse;

class ConversationController extends Controller
{
    public function __construct(private readonly ChatService $chatService)
    {
    }

    public function start(StartConversationRequest $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $tenantId = (int) $request->validated('tenant_id');

        $conversation = $this->chatService->startOrGetConversation($user, $tenantId);

        return response()->json([
            'success' => true,
            'message' => 'Conversation started successfully.',
            'data' => [
                'conversation' => [
                    'id' => (int) $conversation->id,
                    'tenant_id' => (int) $conversation->tenant_id,
                    'end_user_id' => (int) $conversation->end_user_id,
                    'status' => (string) $conversation->status,
                    'context_type' => (string) $conversation->context_type,
                    'last_message_at' => $conversation->last_message_at?->toIso8601String(),
                    'last_message_preview' => $conversation->last_message_preview,
                    'created_at' => $conversation->created_at?->toIso8601String(),
                    'updated_at' => $conversation->updated_at?->toIso8601String(),
                ],
            ],
            'meta' => (object) [],
        ]);
    }
}
