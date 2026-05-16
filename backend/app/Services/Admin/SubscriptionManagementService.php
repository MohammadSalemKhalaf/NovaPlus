<?php

namespace App\Services\Admin;

use App\DTOs\Admin\SubscriptionDto;
use App\Models\Subscription;
use App\Repositories\Admin\SubscriptionRepository;

class SubscriptionManagementService
{
    public function __construct(private readonly SubscriptionRepository $repository) {}

    /**
     * List subscriptions with pagination and filtering.
     */
    public function list(array $filters): array
    {
        $paginated = $this->repository->paginate($filters);

        return [
            'subscriptions' => $paginated->getCollection()
                ->map(fn (Subscription $sub) => (new SubscriptionDto($sub))->toArray())
                ->toArray(),
            'pagination' => [
                'current_page' => $paginated->currentPage(),
                'last_page' => $paginated->lastPage(),
                'per_page' => $paginated->perPage(),
                'total' => $paginated->total(),
            ],
        ];
    }

    /**
     * Get single subscription.
     */
    public function show(int $id): ?array
    {
        $subscription = $this->repository->findById($id);

        if (! $subscription) {
            return null;
        }

        return (new SubscriptionDto($subscription))->toArray();
    }

    /**
     * Activate subscription (set to active status).
     */
    public function activate(int $id): ?array
    {
        $subscription = $this->repository->findById($id);

        if (! $subscription) {
            return null;
        }

        $this->repository->updateStatus($subscription, 'active');

        return (new SubscriptionDto($subscription->fresh()))->toArray();
    }

    /**
     * Suspend subscription (disable access).
     */
    public function suspend(int $id): ?array
    {
        $subscription = $this->repository->findById($id);

        if (! $subscription) {
            return null;
        }

        $this->repository->suspend($subscription);

        return (new SubscriptionDto($subscription->fresh()))->toArray();
    }

    /**
     * Cancel subscription.
     */
    public function cancel(int $id): ?array
    {
        $subscription = $this->repository->findById($id);

        if (! $subscription) {
            return null;
        }

        $this->repository->cancel($subscription);

        return (new SubscriptionDto($subscription->fresh()))->toArray();
    }

    /**
     * Renew subscription for additional months.
     */
    public function renew(int $id, int $months = 1): ?array
    {
        $subscription = $this->repository->findById($id);

        if (! $subscription) {
            return null;
        }

        $this->repository->renew($subscription, $months);

        return (new SubscriptionDto($subscription->fresh()))->toArray();
    }

    /**
     * Get active subscriptions (paginated).
     */
    public function getActive(array $filters = []): array
    {
        $filters['active_only'] = true;
        return $this->list($filters);
    }

    /**
     * Get expired subscriptions (paginated).
     */
    public function getExpired(array $filters = []): array
    {
        $filters['expired_only'] = true;
        return $this->list($filters);
    }

    /**
     * Get subscriptions expiring in N days (paginated).
     */
    public function getExpiringIn(int $days, array $filters = []): array
    {
        $filters['expiring_days'] = $days;
        return $this->list($filters);
    }
}
