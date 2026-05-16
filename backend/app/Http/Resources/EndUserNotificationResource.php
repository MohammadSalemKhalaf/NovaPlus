<?php

namespace App\Http\Resources;

use App\Models\NotificationRecipient;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin NotificationRecipient */
class EndUserNotificationResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => (int) $this->notification_id,
            'type' => (string) ($this->notification?->type ?? ''),
            'title' => (string) ($this->notification?->title ?? ''),
            'body' => (string) ($this->notification?->body ?? ''),
            'related_type' => $this->notification?->related_type,
            'related_id' => $this->notification?->related_id,
            'channel' => (string) ($this->notification?->channel ?? 'database'),
            'priority' => (string) ($this->notification?->priority ?? 'normal'),
            'status' => (string) ($this->notification?->status ?? 'sent'),
            'is_read' => (bool) $this->is_read,
            'read_at' => $this->read_at?->toIso8601String(),
            'created_at' => $this->notification?->created_at?->toIso8601String(),
        ];
    }
}
