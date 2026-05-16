<?php

namespace App\Http\Controllers;

use App\Http\Requests\Chat\AddReactionRequest;
use App\Services\Chat\ChatService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MessageReactionController extends Controller
{
    public function __construct(private readonly ChatService $chatService)
    {
    }

    public function store(AddReactionRequest $request, int $id): JsonResponse
    {
        $user = $request->user('sanctum');
        $data = $request->validated();

        $result = $this->chatService->addReaction(
            actor: $user,
            messageId: $id,
            reactionType: (string) $data['reaction'],
        );

        if ($result === null) {
            return response()->json([
                'success' => false,
                'message' => 'Message not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Reaction added successfully.',
            'data' => $result,
            'meta' => (object) [],
        ], 201);
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $user = $request->user('sanctum');

        $removed = $this->chatService->removeReaction(
            actor: $user,
            messageId: $id,
        );

        if ($removed === null) {
            return response()->json([
                'success' => false,
                'message' => 'Message not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Reaction removed successfully.',
            'data' => [
                'removed_count' => $removed,
            ],
            'meta' => (object) [],
        ], 200);
    }
}
