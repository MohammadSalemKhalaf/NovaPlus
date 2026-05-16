<?php

namespace App\Http\Resources;

use App\Models\Conversation;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Conversation */
class ConversationResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => (int) $this->id,
            'tenant_id' => (int) $this->tenant_id,
            'end_user' => $this->endUser ? [
                'id' => (int) $this->endUser->id,
                'name' => (string) $this->endUser->name,
                'email' => (string) $this->endUser->email,
            ] : null,
            'status' => (string) $this->status,
            'last_message_at' => $this->last_message_at?->toIso8601String(),
            'last_message_preview' => $this->last_message_preview,
            'unread_count' => (int) ($this->unread_count ?? 0),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
