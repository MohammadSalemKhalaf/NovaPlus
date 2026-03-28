<?php

namespace App\DTOs\EndUser;

use App\Models\UserStoreView;

class RecentlyViewedStoreDto
{
    public function __construct(private readonly UserStoreView $view)
    {
        $this->view->loadMissing('store.businessType');
    }

    public function toArray(): array
    {
        $store = $this->view->store;

        return [
            'id' => (int) $this->view->id,
            'tenant_id' => (int) $this->view->tenant_id,
            'view_count' => (int) $this->view->view_count,
            'last_viewed_at' => $this->view->last_viewed_at?->toIso8601String(),
            'store' => $store ? [
                'id' => (int) $store->id,
                'name' => (string) $store->name,
                'slug' => (string) $store->slug,
                'status' => (string) $store->status,
                'business_type' => $store->businessType ? [
                    'id' => (int) $store->businessType->id,
                    'name' => (string) $store->businessType->name,
                    'slug' => (string) $store->businessType->slug,
                ] : null,
            ] : null,
        ];
    }
}
