<?php

namespace App\Repositories\Chat;

use App\Models\MessageReaction;
use Illuminate\Database\Eloquent\Collection;

class MessageReactionRepository
{
    public function create(int $messageId, int $userId, string $reactionType): MessageReaction
    {
        return MessageReaction::updateOrCreate(
            ['message_id' => $messageId, 'user_id' => $userId],
            ['reaction_type' => $reactionType]
        );
    }

    public function remove(int $messageId, int $userId): int
    {
        return MessageReaction::where('message_id', $messageId)
            ->where('user_id', $userId)
            ->delete();
    }

    public function getByMessage(int $messageId): Collection
    {
        return MessageReaction::where('message_id', $messageId)
            ->select(['id', 'message_id', 'user_id', 'reaction_type', 'created_at'])
            ->orderBy('created_at', 'asc')
            ->get();
    }

    public function getCountByMessage(int $messageId): array
    {
        return MessageReaction::where('message_id', $messageId)
            ->groupBy('reaction_type')
            ->selectRaw('reaction_type, COUNT(*) as count')
            ->get()
            ->pluck('count', 'reaction_type')
            ->toArray();
    }

    public function getUserReactionForMessage(int $messageId, int $userId): ?MessageReaction
    {
        return MessageReaction::where('message_id', $messageId)
            ->where('user_id', $userId)
            ->first();
    }
}
