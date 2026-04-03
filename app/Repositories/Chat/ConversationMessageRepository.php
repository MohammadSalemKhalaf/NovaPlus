<?php

namespace App\Repositories\Chat;

use App\Models\ConversationMessage;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

class ConversationMessageRepository
{
    /**
     * @param array<string, mixed> $attributes
     */
    public function create(array $attributes): ConversationMessage
    {
        return ConversationMessage::query()->create($attributes);
    }

    public function paginateForConversation(int $conversationId, int $perPage = 30): LengthAwarePaginator
    {
        return ConversationMessage::query()
            ->where('conversation_id', $conversationId)
            ->select([
                'id',
                'conversation_id',
                'sender_type',
                'sender_id',
                'message_type',
                'body',
                'media_url',
                'media_type',
                'metadata',
                'reply_to_message_id',
                'is_read',
                'read_at',
                'created_at',
                'updated_at',
            ])
            ->with([
                'sender' => static function ($query): void {
                    $query->select([
                        'id',
                        'name',
                        'email',
                    ]);
                },
                'reactions' => static function ($query): void {
                    $query->select([
                        'id',
                        'message_id',
                        'user_id',
                        'reaction_type',
                        'created_at',
                    ]);
                },
                'replyTo' => static function ($query): void {
                    $query->select([
                        'id',
                        'conversation_id',
                        'sender_id',
                        'message_type',
                        'body',
                        'media_url',
                        'media_type',
                        'metadata',
                        'reply_to_message_id',
                        'created_at',
                    ]);
                },
            ])
            ->orderBy('id')
            ->paginate($perPage);
    }

    public function findForEndUser(int $messageId, int $endUserId): ?ConversationMessage
    {
        return ConversationMessage::query()
            ->whereKey($messageId)
            ->whereHas('conversation', function ($query) use ($endUserId): void {
                $query->where('end_user_id', $endUserId);
            })
            ->with([
                'conversation:id,tenant_id,end_user_id,status,context_type,last_message_at,last_message_preview,created_at,updated_at',
                'sender:id,name,email',
                'reactions:id,message_id,user_id,reaction_type,created_at',
                'replyTo:id,conversation_id,sender_id,message_type,body,media_url,media_type,metadata,reply_to_message_id,created_at',
            ])
            ->first();
    }

    public function findForOwner(int $messageId, int $ownerUserId): ?ConversationMessage
    {
        return ConversationMessage::query()
            ->whereKey($messageId)
            ->whereHas('conversation', function ($query) use ($ownerUserId): void {
                $query
                    ->whereHas('tenant', function ($tenantQuery) use ($ownerUserId): void {
                        $tenantQuery->where('owner_user_id', $ownerUserId);
                    })
                    ->orWhereHas('tenant.tenantUsers', function ($tenantUsersQuery) use ($ownerUserId): void {
                        $tenantUsersQuery
                            ->where('user_id', $ownerUserId)
                            ->where('role', 'owner')
                            ->where('status', 'active');
                    });
            })
            ->with([
                'conversation:id,tenant_id,end_user_id,status,context_type,last_message_at,last_message_preview,created_at,updated_at',
                'sender:id,name,email',
                'reactions:id,message_id,user_id,reaction_type,created_at',
                'replyTo:id,conversation_id,sender_id,message_type,body,media_url,media_type,metadata,reply_to_message_id,created_at',
            ])
            ->first();
    }

    public function markOwnerMessagesAsReadForEndUser(int $conversationId): int
    {
        return ConversationMessage::query()
            ->where('conversation_id', $conversationId)
            ->where('sender_type', 'owner')
            ->where('is_read', false)
            ->update([
                'is_read' => true,
                'read_at' => now(),
                'updated_at' => now(),
            ]);
    }

    public function markEndUserMessagesAsReadForOwner(int $conversationId): int
    {
        return ConversationMessage::query()
            ->where('conversation_id', $conversationId)
            ->where('sender_type', 'end_user')
            ->where('is_read', false)
            ->update([
                'is_read' => true,
                'read_at' => now(),
                'updated_at' => now(),
            ]);
    }
}
