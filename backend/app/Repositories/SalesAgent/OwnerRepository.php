<?php

namespace App\Repositories\SalesAgent;

use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;

class OwnerRepository
{
    /**
     * @param array{status?: string|null, subscription_status?: string|null, per_page?: int} $filters
     */
    public function paginateByAgent(int $salesAgentId, array $filters = []): LengthAwarePaginator
    {
        $perPage = max(1, min(100, (int) ($filters['per_page'] ?? 15)));
        $status = isset($filters['status']) ? trim((string) $filters['status']) : null;
        $subscriptionStatus = isset($filters['subscription_status']) ? trim((string) $filters['subscription_status']) : null;

        return $this->baseQuery($salesAgentId)
            ->when($status === 'active', function (Builder $query): void {
                $query->where('users.status', 'active');
            })
            ->when($status === 'inactive', function (Builder $query): void {
                $query->where('users.status', '!=', 'active');
            })
            ->when($subscriptionStatus === 'active', function (Builder $query): void {
                $query->whereHas('ownedTenants.latestSubscription', function (Builder $subscriptionQuery): void {
                    $subscriptionQuery
                        ->where('subscriptions.status', 'active')
                        ->where('subscriptions.starts_at', '<=', now())
                        ->where('subscriptions.ends_at', '>', now());
                });
            })
            ->when($subscriptionStatus === 'expired', function (Builder $query): void {
                $query->where(function (Builder $statusQuery): void {
                    $statusQuery
                        ->whereHas('ownedTenants.latestSubscription', function (Builder $subscriptionQuery): void {
                            $subscriptionQuery
                                ->where('subscriptions.status', 'expired')
                                ->orWhere('subscriptions.ends_at', '<=', now());
                        })
                        ->orWhereDoesntHave('ownedTenants.latestSubscription');
                });
            })
            ->orderByDesc('users.created_at')
            ->paginate($perPage);
    }

    private function baseQuery(int $salesAgentId): Builder
    {
        return User::query()
            ->select([
                'users.id',
                'users.name',
                'users.email',
                'users.status',
                'users.created_by',
                'users.created_at',
            ])
            ->where('users.created_by', $salesAgentId)
            ->where(function (Builder $query): void {
                $query
                    ->whereHas('roles', function (Builder $roleQuery): void {
                        $roleQuery->where('roles.slug', 'store_owner');
                    })
                    ->orWhereHas('tenantUsers', function (Builder $tenantUserQuery): void {
                        $tenantUserQuery->where('tenant_users.role', 'owner');
                    })
                    ->orWhereHas('ownedTenants');
            })
            ->with([
                'ownedTenants' => function ($query): void {
                    $query->select([
                        'tenants.id',
                        'tenants.owner_user_id',
                        'tenants.name',
                        'tenants.slug',
                        'tenants.status',
                    ]);
                },
                'ownedTenants.latestSubscription' => function ($query): void {
                    $query->select([
                        'subscriptions.id',
                        'subscriptions.tenant_id',
                        'subscriptions.status',
                        'subscriptions.starts_at',
                        'subscriptions.ends_at',
                    ]);
                },
            ]);
    }
}
