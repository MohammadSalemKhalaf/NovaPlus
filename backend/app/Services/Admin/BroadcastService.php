<?php

namespace App\Services\Admin;

use App\Services\Notifications\NotificationRecipientResolver;
use App\Services\Notifications\NotificationService;
use Illuminate\Support\Facades\Log;

class BroadcastService
{
    public function __construct(
        private readonly NotificationRecipientResolver $recipientResolver,
        private readonly NotificationService $notificationService,
    ) {
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function broadcast(array $payload, ?int $createdBy): array
    {
        $recipientIds = $this->resolveRecipientIds($payload);

        $notification = $this->notificationService->sendBroadcast(
            payload: [
                'type' => 'admin_broadcast',
                'title' => (string) $payload['title'],
                'body' => (string) $payload['body'],
                'notifiable_type' => 'system',
                'notifiable_id' => 0,
                'related_type' => null,
                'related_id' => null,
                'priority' => 'normal',
            ],
            recipientIds: $recipientIds,
            createdBy: $createdBy,
        );

        Log::info('Admin broadcast dispatched', [
            'created_by' => $createdBy,
            'target' => (string) $payload['target'],
            'recipient_count' => count($recipientIds),
            'notification_id' => $notification?->id,
        ]);

        return [
            'notification_id' => $notification?->id,
            'target' => (string) $payload['target'],
            'recipients_count' => count($recipientIds),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<int, int>
     */
    private function resolveRecipientIds(array $payload): array
    {
        $target = (string) ($payload['target'] ?? '');

        return match ($target) {
            'all_users' => $this->recipientResolver->resolve([
                'strategy' => 'all_users',
            ]),
            'role' => $this->recipientResolver->resolve([
                'strategy' => 'roles',
                'roles' => [(string) ($payload['role'] ?? '')],
            ]),
            'tenant' => $this->recipientResolver->resolve([
                'strategy' => 'tenant_users',
                'tenant_id' => (int) ($payload['tenant_id'] ?? 0),
            ]),
            'direct_users' => $this->recipientResolver->resolve([
                'strategy' => 'direct_users',
                'user_ids' => array_map('intval', (array) ($payload['user_ids'] ?? [])),
            ]),
            default => [],
        };
    }
}
