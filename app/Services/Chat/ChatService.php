<?php

namespace App\Services\Chat;

use App\Models\Conversation;
use App\Models\ConversationMessage;
use App\Models\Item;
use App\Models\Tenant;
use App\Models\User;
use App\Repositories\Catalog\ItemRepository;
use App\Repositories\Chat\ConversationMessageRepository;
use App\Repositories\Chat\ConversationOrderDraftRepository;
use App\Repositories\Chat\ConversationRepository;
use App\Repositories\Chat\MessageReactionRepository;
use App\Services\Notifications\NotificationPayloadBuilder;
use App\Services\Notifications\NotificationService;
use App\Services\Realtime\FirebaseRealtimeService;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class ChatService
{
    private const ALLOWED_MEDIA_TYPES = ['image', 'voice'];
    private const ALLOWED_REACTIONS = ['like', 'love', 'laugh', 'fire'];
    private const ALLOWED_MESSAGE_TYPES = ['text', 'image', 'voice', 'product'];
    private const METADATA_MAX_BYTES = 2048;

    public function __construct(
        private readonly ConversationRepository $conversationRepository,
        private readonly ConversationMessageRepository $conversationMessageRepository,
        private readonly ConversationOrderDraftRepository $orderDraftRepository,
        private readonly MessageReactionRepository $messageReactionRepository,
        private readonly ItemRepository $itemRepository,
        private readonly NotificationService $notificationService,
        private readonly NotificationPayloadBuilder $notificationPayloadBuilder,
        private readonly FirebaseRealtimeService $firebaseRealtimeService,
    ) {
    }

    public function startOrGetConversation(User $endUser, int $tenantId, string $contextType = 'general'): Conversation
    {
        $conversation = $this->conversationRepository->startOrCreate($tenantId, (int) $endUser->id, $contextType);

        return $conversation->loadMissing([
            'tenant:id,name,slug',
            'endUser:id,name,email',
        ]);
    }

    public function sendEndUserMessage(User $endUser, int $conversationId, string $body, ?int $replyToMessageId = null): ?array
    {
        $conversation = $this->conversationRepository->findForEndUser($conversationId, (int) $endUser->id);

        if ($conversation === null) {
            return null;
        }

        if ($replyToMessageId !== null && !$this->validateReplyBelongsToConversation((int) $conversation->id, $replyToMessageId)) {
            return null;
        }

        $message = $this->persistMessage(
            conversationId: (int) $conversation->id,
            senderType: 'end_user',
            senderId: (int) $endUser->id,
            messageType: 'text',
            body: $body,
            replyToMessageId: $replyToMessageId,
        );

        $this->broadcastMessageToOwner($conversation, $endUser);
        $this->pushRealtimeMessage($conversation, $message);

        return [
            'conversation' => $conversation,
            'message' => $message,
        ];
    }

    public function sendEndUserMediaMessage(User $endUser, int $conversationId, string $mediaUrl, string $mediaType, ?int $replyToMessageId = null): ?array
    {
        if (!in_array($mediaType, self::ALLOWED_MEDIA_TYPES, true)) {
            return null;
        }

        $conversation = $this->conversationRepository->findForEndUser($conversationId, (int) $endUser->id);

        if ($conversation === null) {
            return null;
        }

        if ($replyToMessageId !== null && !$this->validateReplyBelongsToConversation((int) $conversation->id, $replyToMessageId)) {
            return null;
        }

        $message = $this->persistMessage(
            conversationId: (int) $conversation->id,
            senderType: 'end_user',
            senderId: (int) $endUser->id,
            messageType: $mediaType,
            body: 'media message',
            replyToMessageId: $replyToMessageId,
        );

        $this->broadcastMessageToOwner($conversation, $endUser);
        $this->pushRealtimeMessage($conversation, $message);

        return [
            'conversation' => $conversation,
            'message' => $message,
        ];
    }

    public function sendEndUserProductMessage(User $endUser, ?int $tenantId, ?int $conversationId, int $productId, ?int $replyToMessageId = null): ?array
    {
        $conversation = null;
        $item = null;
        $effectiveTenantId = $tenantId;

        if ($conversationId !== null) {
            $conversation = $this->conversationRepository->findForEndUser($conversationId, (int) $endUser->id);

            if ($conversation === null) {
                return null;
            }

            $effectiveTenantId = (int) $conversation->tenant_id;
        }

        if ($effectiveTenantId === null || $effectiveTenantId <= 0) {
            return null;
        }

        $item = $this->itemRepository->findForTenant($effectiveTenantId, $productId);

        if ($item === null) {
            return null;
        }

        if ($conversation === null) {
            $conversation = $this->startOrGetConversation($endUser, $effectiveTenantId, 'product');
        } elseif ($conversation->context_type !== 'product') {
            $conversation->forceFill(['context_type' => 'product'])->save();
        }

        if ($replyToMessageId !== null && !$this->validateReplyBelongsToConversation((int) $conversation->id, $replyToMessageId)) {
            return null;
        }

        $metadata = $this->buildProductMetadata($item);

        $message = $this->persistMessage(
            conversationId: (int) $conversation->id,
            senderType: 'end_user',
            senderId: (int) $endUser->id,
            messageType: 'product',
            body: 'product inquiry',
            metadata: $metadata,
            replyToMessageId: $replyToMessageId,
        );

        $draft = $this->orderDraftRepository->create(
            (int) $conversation->id,
            (int) $conversation->tenant_id,
            (int) $endUser->id,
            [[
                'product_id' => (int) $item->id,
                'name' => (string) $item->name,
                'price' => (float) ($item->final_price ?? 0),
                'image' => $this->resolveItemImage($item),
                'quantity' => 1,
            ]]
        );

        $this->broadcastMessageToOwner($conversation, $endUser);
        $this->pushRealtimeMessage($conversation, $message);

        return [
            'conversation' => $conversation,
            'message' => $message,
            'order_draft' => [
                'draft_id' => (int) $draft->id,
                'conversation_id' => (int) $draft->conversation_id,
                'tenant_id' => (int) $draft->tenant_id,
                'end_user_id' => (int) $draft->end_user_id,
                'items' => $draft->items,
                'status' => (string) $draft->status,
                'created_at' => $draft->created_at?->toIso8601String(),
            ],
        ];
    }

    public function sendEndUserIntentMessage(User $endUser, int $tenantId, string $intentType, ?int $replyToMessageId = null): ?array
    {
        if ($intentType !== 'order_request') {
            return null;
        }

        $conversation = $this->startOrGetConversation($endUser, $tenantId, 'general');

        if ($replyToMessageId !== null && !$this->validateReplyBelongsToConversation((int) $conversation->id, $replyToMessageId)) {
            return null;
        }

        $metadata = $this->buildIntentMetadata($intentType);

        $message = $this->persistMessage(
            conversationId: (int) $conversation->id,
            senderType: 'end_user',
            senderId: (int) $endUser->id,
            messageType: 'text',
            body: 'intent request',
            metadata: $metadata,
            replyToMessageId: $replyToMessageId,
        );

        $draft = $this->orderDraftRepository->create(
            (int) $conversation->id,
            (int) $conversation->tenant_id,
            (int) $endUser->id,
            [],
            'intent'
        );

        $this->broadcastMessageToOwner($conversation, $endUser);
        $this->pushRealtimeMessage($conversation, $message);

        return [
            'conversation' => $conversation,
            'message' => $message,
            'order_draft' => [
                'draft_id' => (int) $draft->id,
                'conversation_id' => (int) $draft->conversation_id,
                'tenant_id' => (int) $draft->tenant_id,
                'end_user_id' => (int) $draft->end_user_id,
                'items' => $draft->items,
                'status' => (string) $draft->status,
                'created_at' => $draft->created_at?->toIso8601String(),
            ],
        ];
    }

    public function sendOwnerMessage(User $owner, int $tenantId, int $conversationId, string $body, ?int $replyToMessageId = null): ?array
    {
        $conversation = $this->conversationRepository->findForOwnerAndTenant($conversationId, (int) $owner->id, $tenantId);

        if ($conversation === null) {
            return null;
        }

        if ($replyToMessageId !== null && !$this->validateReplyBelongsToConversation((int) $conversation->id, $replyToMessageId)) {
            return null;
        }

        $message = $this->persistMessage(
            conversationId: (int) $conversation->id,
            senderType: 'owner',
            senderId: (int) $owner->id,
            messageType: 'text',
            body: $body,
            replyToMessageId: $replyToMessageId,
        );

        $this->broadcastMessageToEndUser($conversation, $owner);
        $this->pushRealtimeMessage($conversation, $message);

        return [
            'conversation' => $conversation,
            'message' => $message,
        ];
    }

    public function listOwnerConversations(int $tenantId, int $perPage = 15): LengthAwarePaginator
    {
        $safePerPage = max(1, min(100, $perPage));

        return $this->conversationRepository->paginateForOwnerTenant($tenantId, $safePerPage);
    }

    public function listMessagesForActor(User $actor, int $conversationId, int $perPage = 30): ?LengthAwarePaginator
    {
        $conversation = $this->resolveConversationForActor($actor, $conversationId);

        if ($conversation === null) {
            return null;
        }

        $safePerPage = max(1, min(100, $perPage));

        return $this->conversationMessageRepository->paginateForConversation((int) $conversation->id, $safePerPage);
    }

    public function markConversationAsRead(User $actor, int $conversationId): ?int
    {
        $conversation = $this->resolveConversationForActor($actor, $conversationId);

        if ($conversation === null) {
            return null;
        }

        if ((int) $conversation->end_user_id === (int) $actor->id) {
            $updatedCount = $this->conversationMessageRepository->markOwnerMessagesAsReadForEndUser((int) $conversation->id);
        } else {
            $updatedCount = $this->conversationMessageRepository->markEndUserMessagesAsReadForOwner((int) $conversation->id);
        }

        $this->pushRealtimeConversationRead($conversation, $actor, $updatedCount);

        return $updatedCount;
    }

    public function addReaction(User $actor, int $messageId, string $reactionType): ?array
    {
        if (!in_array($reactionType, self::ALLOWED_REACTIONS, true)) {
            return null;
        }

        $message = $this->resolveMessageForActor($actor, $messageId);

        if ($message === null) {
            return null;
        }

        $reaction = $this->messageReactionRepository->create((int) $message->id, (int) $actor->id, $reactionType);
        $this->pushRealtimeReactionUpdate($message, $actor, 'upsert');

        return [
            'reaction_id' => (int) $reaction->id,
            'message_id' => (int) $reaction->message_id,
            'user_id' => (int) $reaction->user_id,
            'reaction_type' => (string) $reaction->reaction_type,
            'created_at' => $reaction->created_at?->toIso8601String(),
        ];
    }

    public function removeReaction(User $actor, int $messageId): ?int
    {
        $message = $this->resolveMessageForActor($actor, $messageId);

        if ($message === null) {
            return null;
        }

        $removed = $this->messageReactionRepository->remove((int) $message->id, (int) $actor->id);

        if ($removed > 0) {
            $this->pushRealtimeReactionUpdate($message, $actor, 'remove');
        }

        return $removed;
    }

    public function getMessageReactions(int $messageId): array
    {
        $reactions = $this->messageReactionRepository->getByMessage($messageId);

        return [
            'reactions' => $reactions->map(static fn ($reaction): array => [
                'id' => (int) $reaction->id,
                'message_id' => (int) $reaction->message_id,
                'user_id' => (int) $reaction->user_id,
                'reaction_type' => (string) $reaction->reaction_type,
                'created_at' => $reaction->created_at?->toIso8601String(),
            ])->toArray(),
            'counts' => $this->messageReactionRepository->getCountByMessage($messageId),
        ];
    }

    private function validateReplyBelongsToConversation(int $conversationId, int $replyToMessageId): bool
    {
        return ConversationMessage::query()
            ->where('id', $replyToMessageId)
            ->where('conversation_id', $conversationId)
            ->exists();
    }

    private function resolveConversationForActor(User $actor, int $conversationId): ?Conversation
    {
        $conversation = $this->conversationRepository->findForEndUser($conversationId, (int) $actor->id);

        if ($conversation !== null) {
            return $conversation;
        }

        return $this->conversationRepository->findForOwner($conversationId, (int) $actor->id);
    }

    private function resolveMessageForActor(User $actor, int $messageId): ?ConversationMessage
    {
        $message = $this->conversationMessageRepository->findForEndUser($messageId, (int) $actor->id);

        if ($message !== null) {
            return $message;
        }

        return $this->conversationMessageRepository->findForOwner($messageId, (int) $actor->id);
    }

    private function buildProductMetadata(Item $item): array
    {
        $payload = [
            'product_id' => (int) $item->id,
            'name' => (string) $item->name,
            'price' => (float) ($item->final_price ?? 0),
            'image' => $this->resolveItemImage($item),
        ];

        return $this->buildStructuredMetadata('product', $payload);
    }

    private function buildIntentMetadata(string $intentType): array
    {
        return $this->buildStructuredMetadata('intent', [
            'intent_type' => $intentType,
        ]);
    }

    private function buildStructuredMetadata(string $type, array $payload): array
    {
        $metadata = [
            'type' => $type,
            'payload' => $payload,
        ];

        $this->assertStructuredMetadata($metadata);

        return $metadata;
    }

    private function assertStructuredMetadata(array $metadata): void
    {
        if (!isset($metadata['type'], $metadata['payload']) || !is_string($metadata['type']) || !is_array($metadata['payload'])) {
            throw new \InvalidArgumentException('Metadata must follow {type, payload} structure.');
        }

        $encoded = json_encode($metadata, JSON_THROW_ON_ERROR);

        if ($encoded === false || strlen($encoded) > self::METADATA_MAX_BYTES) {
            throw new \InvalidArgumentException('Metadata exceeds allowed size.');
        }
    }

    private function resolveItemImage(Item $item): string
    {
        $primaryImage = $item->relationLoaded('primaryImage') ? $item->getRelation('primaryImage') : $item->primaryImage()->first();

        return (string) ($primaryImage?->storage_path ?? '');
    }

    private function persistMessage(
        int $conversationId,
        string $senderType,
        int $senderId,
        string $messageType,
        string $body,
        ?string $mediaUrl = null,
        ?string $mediaType = null,
        ?array $metadata = null,
        ?int $replyToMessageId = null,
    ): array {
        if (!in_array($messageType, self::ALLOWED_MESSAGE_TYPES, true)) {
            throw new \InvalidArgumentException('Invalid message type.');
        }

        if ($metadata !== null) {
            $this->assertStructuredMetadata($metadata);
        }

        return DB::transaction(function () use ($conversationId, $senderType, $senderId, $messageType, $body, $mediaUrl, $mediaType, $metadata, $replyToMessageId): array {
            $messageData = [
                'conversation_id' => $conversationId,
                'sender_type' => $senderType,
                'sender_id' => $senderId,
                'message_type' => $messageType,
                'body' => $body,
                'is_read' => false,
            ];

            if ($mediaUrl !== null) {
                $messageData['media_url'] = $mediaUrl;
            }

            if ($mediaType !== null) {
                $messageData['media_type'] = $mediaType;
            }

            if ($metadata !== null) {
                $messageData['metadata'] = $metadata;
            }

            if ($replyToMessageId !== null) {
                $messageData['reply_to_message_id'] = $replyToMessageId;
            }

            $message = $this->conversationMessageRepository->create($messageData);
            $preview = Str::limit(trim($body), 100);
            $this->conversationRepository->touchLastMessage($conversationId, $preview);

            return [
                'id' => (int) $message->id,
                'conversation_id' => (int) $message->conversation_id,
                'sender_type' => (string) $message->sender_type,
                'sender_id' => (int) $message->sender_id,
                'message_type' => (string) $message->message_type,
                'body' => (string) $message->body,
                'media_url' => $message->media_url,
                'media_type' => $message->media_type,
                'metadata' => $message->metadata,
                'reply_to_message_id' => $message->reply_to_message_id,
                'is_read' => (bool) $message->is_read,
                'read_at' => $message->read_at?->toIso8601String(),
                'created_at' => $message->created_at?->toIso8601String(),
            ];
        });
    }

    private function broadcastMessageToOwner(Conversation $conversation, User $endUser): void
    {
        $tenant = Tenant::query()->whereKey($conversation->tenant_id)->select(['id', 'name', 'owner_user_id'])->first();

        if ($tenant !== null && (int) $tenant->owner_user_id > 0) {
            $payload = $this->notificationPayloadBuilder->buildChatMessagePayload(
                tenantName: (string) $tenant->name,
                senderName: (string) $endUser->name,
                forOwner: true,
            );

            $this->notificationService->sendBroadcast([
                'type' => $payload['type'],
                'title' => $payload['title'],
                'body' => $payload['body'],
                'notifiable_type' => 'conversation',
                'notifiable_id' => (int) $conversation->id,
                'related_type' => 'conversation',
                'related_id' => (int) $conversation->id,
                'priority' => 'normal',
                'tenant_id' => (int) $conversation->tenant_id,
            ], [(int) $tenant->owner_user_id], (int) $endUser->id);
        }
    }

    private function broadcastMessageToEndUser(Conversation $conversation, User $owner): void
    {
        $tenant = Tenant::query()->whereKey($conversation->tenant_id)->select(['id', 'name'])->first();

        $payload = $this->notificationPayloadBuilder->buildChatMessagePayload(
            tenantName: (string) ($tenant?->name ?? 'Store'),
            senderName: (string) $owner->name,
            forOwner: false,
        );

        $this->notificationService->sendBroadcast([
            'type' => $payload['type'],
            'title' => $payload['title'],
            'body' => $payload['body'],
            'notifiable_type' => 'conversation',
            'notifiable_id' => (int) $conversation->id,
            'related_type' => 'conversation',
            'related_id' => (int) $conversation->id,
            'priority' => 'normal',
            'tenant_id' => (int) $conversation->tenant_id,
        ], [(int) $conversation->end_user_id], (int) $owner->id);
    }

    /**
     * @param array<string, mixed> $message
     */
    private function pushRealtimeMessage(Conversation $conversation, array $message): void
    {
        $this->firebaseRealtimeService->pushMessage(
            conversationId: (int) $conversation->id,
            messageId: (int) $message['id'],
            payload: [
                'id' => (int) $message['id'],
                'conversation_id' => (int) $conversation->id,
                'tenant_id' => (int) $conversation->tenant_id,
                'sender_type' => (string) $message['sender_type'],
                'sender_id' => (int) $message['sender_id'],
                'message_type' => (string) $message['message_type'],
                'body' => (string) $message['body'],
                'media_url' => $message['media_url'],
                'metadata' => $message['metadata'],
                'created_at' => $message['created_at'],
            ]
        );
    }

    private function pushRealtimeReactionUpdate(ConversationMessage $message, User $actor, string $action): void
    {
        $conversation = $message->relationLoaded('conversation') ? $message->conversation : null;
        $counts = $this->messageReactionRepository->getCountByMessage((int) $message->id);

        $this->firebaseRealtimeService->pushReactionUpdate(
            conversationId: (int) $message->conversation_id,
            messageId: (int) $message->id,
            payload: [
                'tenant_id' => $conversation?->tenant_id,
                'conversation_id' => (int) $message->conversation_id,
                'message_id' => (int) $message->id,
                'action' => $action,
                'actor_user_id' => (int) $actor->id,
                'counts' => $counts,
                'updated_at' => now()->toIso8601String(),
            ]
        );
    }

    private function pushRealtimeConversationRead(Conversation $conversation, User $actor, int $updatedCount): void
    {
        $this->firebaseRealtimeService->pushConversationRead(
            conversationId: (int) $conversation->id,
            payload: [
                'tenant_id' => (int) $conversation->tenant_id,
                'conversation_id' => (int) $conversation->id,
                'actor_user_id' => (int) $actor->id,
                'updated_count' => $updatedCount,
                'read_at' => now()->toIso8601String(),
            ]
        );
    }
}
