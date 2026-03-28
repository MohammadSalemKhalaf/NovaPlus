<?php

namespace App\DTOs\EndUser;

use App\Models\UserFavoriteStore;

class FavoriteStoreDto
{
    public function __construct(private readonly UserFavoriteStore $favorite)
    {
        $this->favorite->loadMissing(['store']);
    }

    public function toArray(): array
    {
        $store = $this->favorite->store;

        return [
            'id' => (int) $this->favorite->id,
            'store_id' => (int) $store->id,
            'notifications_optin' => (bool) $this->favorite->notifications_optin,
            'store' => [
                'id' => (int) $store->id,
                'name' => $store->name,
                'slug' => $store->slug,
                'business_type_id' => (int) $store->business_type_id,
                'status' => $store->status,
            ],
            'favorited_at' => $this->favorite->created_at?->toIso8601String(),
        ];
    }
}
