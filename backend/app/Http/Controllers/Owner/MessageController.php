<?php

namespace App\Http\Controllers\Owner;

use App\Http\Controllers\Controller;
use App\Http\Requests\Owner\SendOwnerMessageRequest;
use App\Services\Chat\ChatService;
use Illuminate\Http\JsonResponse;

class MessageController extends Controller
{
    public function __construct(private readonly ChatService $chatService)
    {
    }

    public function store(SendOwnerMessageRequest $request): JsonResponse
    {
        $user = $request->user();
        $tenant = $request->attributes->get('tenant');
        $tenantId = is_object($tenant) && method_exists($tenant, 'getKey')
            ? (int) $tenant->getKey()
            : 0;

        if ($tenantId <= 0) {
            return response()->json([
                'success' => false,
                'message' => 'Tenant context is required.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 400);
        }

        $data = $request->validated();

        $result = $this->chatService->sendOwnerMessage(
            owner: $user,
            tenantId: $tenantId,
            conversationId: (int) $data['conversation_id'],
            body: (string) $data['body'],
            replyToMessageId: isset($data['reply_to_message_id']) ? (int) $data['reply_to_message_id'] : null,
        );

        if ($result === null) {
            return response()->json([
                'success' => false,
                'message' => 'Conversation not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Message sent successfully.',
            'data' => [
                'message' => $result['message'],
            ],
            'meta' => (object) [],
        ], 201);
    }
}
