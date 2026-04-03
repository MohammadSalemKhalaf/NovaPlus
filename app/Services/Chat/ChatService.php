<?php

namespace App\Services\Chat;

use App\Models\Conversation;
use App\Models\ConversationMessage;
use App\Models\Tenant;
use App\Models\User;
use App\Repositories\Chat\ConversationMessageRepository;
use App\Repositories\Chat\ConversationRepository;
use App\Services\Notifications\NotificationPayloadBuilder;
use App\Services\Notifications\NotificationService;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class ChatService
{
    public function __construct(
        private readonly ConversationRepository $conversationRepository,
        private readonly ConversationMessageRepository $conversationMessageRepository,
        private readonly NotificationService $notificationService,
        private readonly NotificationPayloadBuilder $notificationPayloadBuilder,
    ) {
    }

    public function startOrGetConversation(User $endUser, int $tenantId): Conversation
    {
        $conversation = $this->conversationRepository->startOrCreate($tenantId, (int) $endUser->id);

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

        // Validate reply (if provided)
        if ($replyToMessageId !== null) {
            if (!$this->validateReplyBelongsToConversation((int) $conversation->id, $replyToMessageId)) {
                return null;
            }
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

        return [
            'conversation' => $conversation,
            'message' => $message,
        ];
    }

    public function sendEndUserMediaMessage(User $endUser, int $conversationId, string $mediaUrl, string $mediaType, ?int $replyToMessageId = null): ?array
    {
        if (!in_array($mediaType, ['image', 'voice'])) {
            return null;
        }

        $conversation = $this->conversationRepository->findForEndUser($conversationId, (int) $endUser->id);

        if ($conversation === null) {
            return null;
        }

        // Validate reply
        if ($replyToMessageId !== null) {
            if (!$this->validateReplyBelongsToConversation((int) $conversation->id, $replyToMessageId)) {
                return null;
            }
        }

        $message = $this->persistMessage(
            conversationId: (int) $conversation->id,
            senderType: 'end_user',
            senderId: (int) $endUser->id,
            messageType: $mediaType,
            body: "{$mediaType} message",
            mediaUrl: $mediaUrl,
            mediaType: $mediaType,
            replyToMessageId: $replyToMessageId,
        );

        $this->broadcastMessageToOwner($conversation, $endUser);

        return [
            'conversation' => $conversation,
            'message' => $message,
        ];
    }

    public function sendEndUserProductMessage(User $endUser, int $conversationId, int $productId, string $productName, float $productPrice, string $productImage, ?int $replyToMessageId = null): ?array
    {
        $conversation = $this->conversationRepository->findForEndUser($conversationId, (int) $endUser->id);

        if ($conversation === null) {
            return null;
        }

        // Validate reply
        if ($replyToMessageId !== null) {
            if (!$this->validateReplyBelongsToConversation((int) $conversation->id, $replyToMessageId)) {
                return null;
            }
        }

        $metadata = [
            'product_id' => (int) $productId,
            'name' => (string) $productName,
            'price' => (float) $productPrice,
            'image' => (string) $productImage,
        ];

        $message = $this->persistMessage(
            conversationId: (int) $conversation->id,
            senderType: 'end_user',
            senderId: (int) $endUser->id,
            messageType: 'product',
            body: "Product: {$productName}",
            metadata: $metadata,
            replyToMessageId: $replyToMessageId,
        );

        $this->broadcastMessageToOwner($conversation, $endUser);

        return [
            'conversation' => $conversation,
            'message' => $message,
        ];
    }

    public function sendOwnerMessage(User $owner, int $tenantId, int $conversationId, string $body, ?int $replyToMessageId = null): ?array
    {
        $conversation = $this->conversationRepository->findForOwnerAndTenant($conversationId, (int) $owner->id, $tenantId);

        if ($conversation === null) {
            return null;
        }

        // Validate reply
        if ($replyToMessageId !== null) {
            if (!$this->validateReplyBelongsToConversation((int) $conversation->id, $replyToMessageId)) {
                return null;
            }
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
            return $this->conversationMessageRepository->markOwnerMessagesAsReadForEndUser((int) $conversation->id);
        }

        return $this->conversationMessageRepository->markEndUserMessagesAsReadForOwner((int) $conversation->id);
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

            // Generate preview: truncate to 100 chars (fixed from 140)
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
        ], [(int) $conversation->end_user_id], (int) $owner->id);
    }
}
