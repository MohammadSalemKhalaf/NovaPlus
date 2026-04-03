<?php

namespace App\Services\Notifications;

use App\Models\Item;
use App\Models\Offer;

class NotificationPayloadBuilder
{
    /**
     * @return array{type: string, title: string, body: string, related_type: string, related_id: int}
     */
    public function buildItemPublishedPayload(Item $item): array
    {
        return [
            'type' => 'store_item_published',
            'title' => 'New item is now available',
            'body' => sprintf('%s has published a new item: %s', $item->tenant?->name ?? 'A store', $item->name),
            'related_type' => 'item',
            'related_id' => (int) $item->id,
        ];
    }

    /**
     * @return array{type: string, title: string, body: string, related_type: string, related_id: int}
     */
    public function buildOfferPublishedPayload(Offer $offer): array
    {
        return [
            'type' => 'store_offer_published',
            'title' => 'New offer is live',
            'body' => sprintf('%s has published a new offer: %s', $offer->tenant?->name ?? 'A store', $offer->title),
            'related_type' => 'offer',
            'related_id' => (int) $offer->id,
        ];
    }
}
