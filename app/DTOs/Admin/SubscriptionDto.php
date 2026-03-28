<?php

namespace App\DTOs\Admin;

use App\Models\Subscription;

class SubscriptionDto
{
    public function __construct(private readonly Subscription $subscription)
    {
        $this->subscription->loadMissing(['tenant', 'createdByAdmin', 'soldByUser', 'activatedByUser']);
    }

    public function toArray(): array
    {
        return [
            'id' => (int) $this->subscription->id,
            'tenant_id' => (int) $this->subscription->tenant_id,
            'tenant' => [
                'id' => (int) $this->subscription->tenant->id,
                'name' => $this->subscription->tenant->name,
                'slug' => $this->subscription->tenant->slug,
                'owner_user_id' => (int) $this->subscription->tenant->owner_user_id,
            ],
            'plan_code' => $this->subscription->plan_code,
            'code' => $this->subscription->code,
            'activation_code' => $this->subscription->activation_code,
            'status' => $this->subscription->status,
            'billing_cycle' => $this->subscription->billing_cycle,
            'activation_channel' => $this->subscription->activation_channel,
            'starts_at' => $this->subscription->starts_at?->toIso8601String(),
            'ends_at' => $this->subscription->ends_at?->toIso8601String(),
            'redeemed_at' => $this->subscription->redeemed_at?->toIso8601String(),
            'created_at' => $this->subscription->created_at?->toIso8601String(),
            'updated_at' => $this->subscription->updated_at?->toIso8601String(),
            'created_by_admin' => $this->subscription->createdByAdmin ? [
                'id' => (int) $this->subscription->createdByAdmin->id,
                'name' => $this->subscription->createdByAdmin->name,
                'email' => $this->subscription->createdByAdmin->email,
            ] : null,
            'sold_by_user' => $this->subscription->soldByUser ? [
                'id' => (int) $this->subscription->soldByUser->id,
                'name' => $this->subscription->soldByUser->name,
                'email' => $this->subscription->soldByUser->email,
            ] : null,
            'activated_by_user' => $this->subscription->activatedByUser ? [
                'id' => (int) $this->subscription->activatedByUser->id,
                'name' => $this->subscription->activatedByUser->name,
                'email' => $this->subscription->activatedByUser->email,
            ] : null,
        ];
    }
}
