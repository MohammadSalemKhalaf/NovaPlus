<?php

namespace App\Repositories\Admin;

use App\Models\Subscription;
use Illuminate\Pagination\LengthAwarePaginator;

class SubscriptionRepository
{
    /**
     * Get base query with eager loads.
     */
    private function baseQuery()
    {
        return Subscription::query()
            ->with(['tenant', 'createdByAdmin', 'soldByUser', 'activatedByUser'])
            ->orderByDesc('created_at');
    }

    /**
     * Paginate subscriptions with filters.
     */
    public function paginate(array $filters): LengthAwarePaginator
    {
        $query = $this->baseQuery();

        // Status filter
        if (! empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }

        // Active subscriptions require both status and date range
        if (! empty($filters['active_only']) && $filters['active_only'] === true) {
            $query->where('status', 'active')
                ->where('starts_at', '<=', now())
                ->where('ends_at', '>', now());
        }

        // Expired subscriptions
        if (! empty($filters['expired_only']) && $filters['expired_only'] === true) {
            $query->where('status', 'active')
                ->where('ends_at', '<=', now());
        }

        // Expiring soon
        if (! empty($filters['expiring_days'])) {
            $expiringDays = (int) $filters['expiring_days'];
            $query->where('status', 'active')
                ->whereBetween('ends_at', [now(), now()->addDays($expiringDays)]);
        }

        // Created by sales agent
        if (! empty($filters['created_by_agent_id'])) {
            $query->where('created_by_admin_id', (int) $filters['created_by_agent_id']);
        }

        // Tenant filter
        if (! empty($filters['tenant_id'])) {
            $query->where('tenant_id', (int) $filters['tenant_id']);
        }

        // Date range
        if (! empty($filters['created_from'])) {
            $query->where('created_at', '>=', $filters['created_from']);
        }

        if (! empty($filters['created_to'])) {
            $query->where('created_at', '<=', $filters['created_to']);
        }

        // Business type filter via tenant relationship
        if (! empty($filters['business_type_id'])) {
            $query->whereHas('tenant', fn ($q) => $q->where('business_type_id', (int) $filters['business_type_id']));
        }

        $perPage = isset($filters['per_page']) ? min((int) $filters['per_page'], 100) : 15;

        return $query->paginate($perPage);
    }

    /**
     * Find subscription by ID.
     */
    public function findById(int $id): ?Subscription
    {
        return $this->baseQuery()->where('id', $id)->first();
    }

    /**
     * Get active subscriptions.
     */
    public function getActive(): \Illuminate\Database\Eloquent\Collection
    {
        return $this->baseQuery()
            ->where('status', 'active')
            ->where('starts_at', '<=', now())
            ->where('ends_at', '>', now())
            ->get();
    }

    /**
     * Get expired subscriptions.
     */
    public function getExpired(): \Illuminate\Database\Eloquent\Collection
    {
        return $this->baseQuery()
            ->where('status', 'active')
            ->where('ends_at', '<=', now())
            ->get();
    }

    /**
     * Get subscriptions expiring soon.
     */
    public function getExpiringIn(int $days): \Illuminate\Database\Eloquent\Collection
    {
        return $this->baseQuery()
            ->where('status', 'active')
            ->whereBetween('ends_at', [now(), now()->addDays($days)])
            ->get();
    }

    /**
     * Update subscription status.
     */
    public function updateStatus(Subscription $subscription, string $status): Subscription
    {
        $subscription->update(['status' => $status]);
        return $subscription;
    }

    /**
     * Suspend subscription (set end_at to now).
     */
    public function suspend(Subscription $subscription): Subscription
    {
        $subscription->update([
            'status' => 'suspended',
            'ends_at' => now(),
        ]);
        return $subscription;
    }

    /**
     * Renew subscription.
     */
    public function renew(Subscription $subscription, int $months = 1): Subscription
    {
        $subscription->update([
            'status' => 'active',
            'ends_at' => now()->addMonths($months),
        ]);
        return $subscription;
    }

    /**
     * Cancel subscription.
     */
    public function cancel(Subscription $subscription): void
    {
        $subscription->update(['status' => 'cancelled']);
    }
}
