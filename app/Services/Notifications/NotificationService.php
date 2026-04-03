<?php

namespace App\Services\Notifications;

use App\Models\Item;
use App\Models\Notification;
use App\Models\Offer;
use App\Repositories\Notifications\NotificationRepository;
use Illuminate\Support\Facades\DB;

class NotificationService
{
    public function __construct(
        private readonly NotificationRepository $notificationRepository,
        private readonly NotificationRecipientResolver $recipientResolver,
        private readonly NotificationPayloadBuilder $payloadBuilder,
    ) {
    }

    public function notifyStoreFollowersForItemPublished(Item $item, ?int $createdBy = null): ?Notification
    {
        $item->loadMissing('tenant');
        $payload = $this->payloadBuilder->buildItemPublishedPayload($item);

        return $this->dispatchForTenantFollowers(
            tenantId: (int) $item->tenant_id,
            payload: $payload,
            createdBy: $createdBy,
        );
    }

    public function notifyStoreFollowersForOfferPublished(Offer $offer, ?int $createdBy = null): ?Notification
    {
        $offer->loadMissing('tenant');
        $payload = $this->payloadBuilder->buildOfferPublishedPayload($offer);

        return $this->dispatchForTenantFollowers(
            tenantId: (int) $offer->tenant_id,
            payload: $payload,
            createdBy: $createdBy,
        );
    }

    /**
     * @param array{type: string, title: string, body: string, related_type: string, related_id: int} $payload
     */
    private function dispatchForTenantFollowers(int $tenantId, array $payload, ?int $createdBy = null): ?Notification
    {
        $recipientIds = $this->recipientResolver->resolve([
            'strategy' => 'favorites',
            'tenant_id' => $tenantId,
        ]);

        if ($recipientIds === []) {
            return null;
        }

        return DB::transaction(function () use ($tenantId, $payload, $createdBy, $recipientIds): Notification {
            $notification = $this->notificationRepository->findExisting(
                type: $payload['type'],
                notifiableType: 'tenant',
                notifiableId: $tenantId,
                relatedType: $payload['related_type'],
                relatedId: $payload['related_id'],
            );

            if ($notification === null) {
                $notification = $this->notificationRepository->create([
                    'type' => $payload['type'],
                    'title' => $payload['title'],
                    'body' => $payload['body'],
                    'notifiable_type' => 'tenant',
                    'notifiable_id' => $tenantId,
                    'related_type' => $payload['related_type'],
                    'related_id' => $payload['related_id'],
                    'channel' => 'database',
                    'priority' => 'normal',
                    'status' => 'sent',
                    'created_by' => $createdBy,
                ]);
            }

            $this->notificationRepository->attachRecipients((int) $notification->id, $recipientIds);

            return $notification;
        });
    }
}
