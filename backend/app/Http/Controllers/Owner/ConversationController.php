<?php

namespace App\Http\Controllers\Owner;

use App\Http\Controllers\Controller;
use App\Http\Requests\Owner\ListOwnerConversationsRequest;
use App\Http\Resources\ConversationResource;
use App\Services\Chat\ChatService;
use Illuminate\Http\JsonResponse;

class ConversationController extends Controller
{
    public function __construct(private readonly ChatService $chatService)
    {
    }

    public function index(ListOwnerConversationsRequest $request): JsonResponse
    {
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

        $conversations = $this->chatService->listOwnerConversations(
            tenantId: $tenantId,
            perPage: (int) $request->integer('per_page', 15),
        );

        return response()->json([
            'success' => true,
            'message' => 'Conversations fetched successfully.',
            'data' => ConversationResource::collection($conversations->items()),
            'meta' => [
                'current_page' => $conversations->currentPage(),
                'per_page' => $conversations->perPage(),
                'total' => $conversations->total(),
                'last_page' => $conversations->lastPage(),
            ],
        ]);
    }
}
