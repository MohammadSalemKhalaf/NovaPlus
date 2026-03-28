<?php

namespace App\DTOs\Admin;

use App\Models\Tenant;

class TenantControlDto
{
    public function __construct(private readonly Tenant $tenant)
    {
        $this->tenant->loadMissing(['owner', 'subscriptions']);
    }

    public function toArray(): array
    {
        $activeSubscription = $this->tenant->subscriptions()
            ->where('status', 'active')
            ->where('starts_at', '<=', now())
            ->where('ends_at', '>', now())
            ->first();

        return [
            'id' => (int) $this->tenant->id,
            'name' => $this->tenant->name,
            'slug' => $this->tenant->slug,
            'status' => $this->tenant->status,
            'owner' => [
                'id' => (int) $this->tenant->owner->id,
                'name' => $this->tenant->owner->name,
                'email' => $this->tenant->owner->email,
                'status' => $this->tenant->owner->status,
            ],
            'business_type_id' => (int) $this->tenant->business_type_id,
            'business_mode' => $this->tenant->business_mode,
            'active_subscription' => $activeSubscription ? [
                'id' => (int) $activeSubscription->id,
                'plan_code' => $activeSubscription->plan_code,
                'ends_at' => $activeSubscription->ends_at->toIso8601String(),
            ] : null,
            'subscription_count' => (int) $this->tenant->subscriptions()->count(),
            'created_at' => $this->tenant->created_at?->toIso8601String(),
        ];
    }
}
