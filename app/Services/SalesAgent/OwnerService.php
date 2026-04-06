<?php

namespace App\Services\SalesAgent;

use App\Models\Subscription;
use App\Models\Tenant;
use App\Models\User;
use App\Repositories\SalesAgent\OwnerRepository;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\Log;

class OwnerService
{
    public function __construct(private readonly OwnerRepository $ownerRepository)
    {
    }

    /**
     * @param array{status?: string|null, subscription_status?: string|null, per_page?: int} $filters
     * @return array{owners: array<int, array<string, mixed>>, pagination: array<string, int>}
     */
    public function listBySalesAgent(int $salesAgentId, array $filters = []): array
    {
        $paginator = $this->ownerRepository->paginateByAgent($salesAgentId, $filters);

        Log::info('SalesAgent Owners Query', [
            'agent_id' => $salesAgentId,
            'count' => count($paginator->items()),
        ]);

        return [
            'owners' => array_map(function (User $owner): array {
                $tenant = $this->resolvePrimaryTenant($owner);
                $subscription = $tenant?->latestSubscription;
                $subscriptionStatus = $this->resolveSubscriptionStatus($subscription);

                return [
                    'id' => (int) $owner->id,
                    'name' => (string) $owner->name,
                    'email' => (string) $owner->email,
                    'store_name' => $tenant?->name,
                    'store_status' => $tenant !== null && $tenant->status === 'active' ? 'active' : 'inactive',
                    'account_status' => $owner->status === 'active' ? 'active' : 'pending',
                    'subscription' => [
                        'status' => $subscriptionStatus,
                        'expires_at' => $subscription?->ends_at?->toISOString(),
                        'days_remaining' => $this->resolveDaysRemaining($subscription),
                    ],
                ];
            }, $paginator->items()),
            'pagination' => $this->pagination($paginator),
        ];
    }

    private function resolvePrimaryTenant(User $owner): ?Tenant
    {
        if ($owner->relationLoaded('ownedTenants')) {
            return $owner->ownedTenants->first();
        }

        return null;
    }

    private function resolveSubscriptionStatus(?Subscription $subscription): string
    {
        if ($subscription === null || $subscription->ends_at === null) {
            return 'expired';
        }

        if ($subscription->status === 'active' && $subscription->ends_at->isFuture()) {
            $daysRemaining = now()->diffInDays($subscription->ends_at, false);

            if ($daysRemaining <= 5) {
                return 'expiring';
            }

            return 'active';
        }

        return 'expired';
    }

    private function resolveDaysRemaining(?Subscription $subscription): int
    {
        if ($subscription === null || $subscription->ends_at === null) {
            return 0;
        }

        return max(0, now()->diffInDays($subscription->ends_at, false));
    }

    /**
     * @return array<string, int>
     */
    private function pagination(LengthAwarePaginator $paginator): array
    {
        return [
            'current_page' => $paginator->currentPage(),
            'last_page' => $paginator->lastPage(),
            'per_page' => $paginator->perPage(),
            'total' => $paginator->total(),
        ];
    }
}
