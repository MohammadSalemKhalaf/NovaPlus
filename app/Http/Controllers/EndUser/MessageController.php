<?php

namespace App\Http\Controllers\EndUser;

use App\Http\Controllers\Controller;
use App\Http\Requests\EndUser\SendEndUserMediaMessageRequest;
use App\Http\Requests\EndUser\SendEndUserMessageRequest;
use App\Http\Requests\EndUser\SendEndUserProductMessageRequest;
use App\Services\Chat\ChatService;
use Illuminate\Http\JsonResponse;

class MessageController extends Controller
{
    public function __construct(private readonly ChatService $chatService)
    {
    }

    public function store(SendEndUserMessageRequest $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $data = $request->validated();

        $result = $this->chatService->sendEndUserMessage(
            endUser: $user,
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

    public function storeMedia(SendEndUserMediaMessageRequest $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $data = $request->validated();

        $result = $this->chatService->sendEndUserMediaMessage(
            endUser: $user,
            conversationId: (int) $data['conversation_id'],
            mediaUrl: (string) $data['media_url'],
            mediaType: (string) $data['media_type'],
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
            'message' => 'Media message sent successfully.',
            'data' => [
                'message' => $result['message'],
            ],
            'meta' => (object) [],
        ], 201);
    }

    public function storeProduct(SendEndUserProductMessageRequest $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $data = $request->validated();

        $result = $this->chatService->sendEndUserProductMessage(
            endUser: $user,
            conversationId: (int) $data['conversation_id'],
            productId: (int) $data['product_id'],
            productName: (string) $data['product_name'],
            productPrice: (float) $data['product_price'],
            productImage: (string) $data['product_image'],
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
            'message' => 'Product message sent successfully.',
            'data' => [
                'message' => $result['message'],
            ],
            'meta' => (object) [],
        ], 201);
    }
}
