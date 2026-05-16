<?php

namespace App\Services\Public;

use App\Models\Subscription;
use App\Models\Tenant;
use Illuminate\Database\Eloquent\Builder;

class PublicTenantAccessService
{
    public function activeSubscribedTenantsQuery(): Builder
    {
        return Tenant::query()
            ->where('tenants.status', 'active')
            ->whereHas('subscriptions', function (Builder $query): void {
                $this->applyActiveSubscriptionConstraint($query);
            });
    }

    public function isActiveSubscribedTenant(Tenant $tenant): bool
    {
        if ($tenant->status !== 'active') {
            return false;
        }

        return Subscription::query()
            ->where('subscriptions.tenant_id', $tenant->id)
            ->where('subscriptions.status', 'active')
            ->where('subscriptions.starts_at', '<=', now())
            ->where('subscriptions.ends_at', '>', now())
            ->exists();
    }

    public function applyActiveSubscriptionConstraint(Builder $query): void
    {
        $query
            ->where('subscriptions.status', 'active')
            ->where('subscriptions.starts_at', '<=', now())
            ->where('subscriptions.ends_at', '>', now());
    }
}
