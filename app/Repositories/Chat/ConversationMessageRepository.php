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
            ])
            ->orderBy('id')
            ->paginate($perPage);
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
