<?php

namespace App\Http\Resources;

use App\Models\ConversationMessage;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin ConversationMessage */
class ConversationMessageResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $reactions = $this->reactions ?? collect();
        $userReaction = null;

        if ($request->user('sanctum')) {
            $userReaction = $reactions->firstWhere('user_id', (int) $request->user('sanctum')->id);
        }

        return [
            'id' => (int) $this->id,
            'conversation_id' => (int) $this->conversation_id,
            'sender_type' => (string) $this->sender_type,
            'sender' => $this->sender ? [
                'id' => (int) $this->sender->id,
                'name' => (string) $this->sender->name,
            ] : null,
            'message_type' => (string) $this->message_type,
            'body' => (string) $this->body,
            'media_url' => $this->media_url,
            'media_type' => $this->media_type,
            'metadata' => $this->metadata,
            'reply_to_message_id' => $this->reply_to_message_id,
            'reactions_count' => $reactions->count(),
            'user_reaction' => $userReaction ? (string) $userReaction->reaction_type : null,
            'is_read' => (bool) $this->is_read,
            'read_at' => $this->read_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
