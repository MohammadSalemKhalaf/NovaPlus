<?php

namespace App\Repositories\Admin;

use App\Models\Tenant;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class TenantControlRepository
{
    /**
     * Get base query with eager loads.
     */
    private function baseQuery()
    {
        return Tenant::query()
            ->with(['owner', 'subscriptions'])
            ->orderByDesc('created_at');
    }

    /**
     * Find tenant by ID.
     */
    public function findById(int $id): ?Tenant
    {
        return $this->baseQuery()->where('id', $id)->first();
    }

    /**
     * Paginate tenants with admin filters.
     */
    public function paginate(array $filters = []): LengthAwarePaginator
    {
        $perPage = max(1, min(100, (int) ($filters['per_page'] ?? 15)));
        $status = isset($filters['status']) ? trim((string) $filters['status']) : null;
        $businessTypeId = isset($filters['business_type_id']) ? (int) $filters['business_type_id'] : null;
        $ownerUserId = isset($filters['owner_user_id']) ? (int) $filters['owner_user_id'] : null;
        $createdByAgentId = isset($filters['created_by_agent_id']) ? (int) $filters['created_by_agent_id'] : null;
        $search = isset($filters['search']) ? trim((string) $filters['search']) : null;

        return $this->baseQuery()
            ->when($status !== null && $status !== '', function (Builder $query) use ($status): void {
                $query->where('status', $status);
            })
            ->when($businessTypeId !== null && $businessTypeId > 0, function (Builder $query) use ($businessTypeId): void {
                $query->where('business_type_id', $businessTypeId);
            })
            ->when($ownerUserId !== null && $ownerUserId > 0, function (Builder $query) use ($ownerUserId): void {
                $query->where('owner_user_id', $ownerUserId);
            })
            ->when($createdByAgentId !== null && $createdByAgentId > 0, function (Builder $query) use ($createdByAgentId): void {
                $query->whereHas('owner', function (Builder $ownerQuery) use ($createdByAgentId): void {
                    $ownerQuery->where('created_by', $createdByAgentId);
                });
            })
            ->when($search !== null && $search !== '', function (Builder $query) use ($search): void {
                $query->where(function (Builder $inner) use ($search): void {
                    $inner->where('name', 'like', "%{$search}%")
                        ->orWhere('slug', 'like', "%{$search}%");
                });
            })
            ->paginate($perPage);
    }

    /**
     * Activate tenant.
     */
    public function activate(Tenant $tenant): Tenant
    {
        $tenant->update(['status' => 'active']);
        return $tenant;
    }

    /**
     * Suspend tenant.
     */
    public function suspend(Tenant $tenant): Tenant
    {
        $tenant->update(['status' => 'suspended']);
        return $tenant;
    }

    /**
     * Delete tenant permanently.
     */
    public function delete(Tenant $tenant): void
    {
        $tenant->delete();
    }

    /**
     * Delete tenant and owner user together with manual dependent cleanup.
     */
    public function deleteWithOwner(Tenant $tenant): void
    {
        $tenantId = (int) $tenant->id;
        $ownerId = (int) $tenant->owner_user_id;

        DB::transaction(function () use ($tenantId, $ownerId): void {
            $subscriptionIds = DB::table('subscriptions')
                ->where('tenant_id', $tenantId)
                ->pluck('id')
                ->all();

            if (Schema::hasTable('cart_items') && Schema::hasColumn('cart_items', 'cart_id') && Schema::hasTable('carts')) {
                $cartIds = DB::table('carts')
                    ->where('tenant_id', $tenantId)
                    ->pluck('id')
                    ->all();

                if (! empty($cartIds)) {
                    DB::table('cart_items')->whereIn('cart_id', $cartIds)->delete();
                }
            }

            if (! empty($subscriptionIds) && Schema::hasTable('subscription_codes') && Schema::hasColumn('subscription_codes', 'redeemed_by_subscription_id')) {
                DB::table('subscription_codes')
                    ->whereIn('redeemed_by_subscription_id', $subscriptionIds)
                    ->update(['redeemed_by_subscription_id' => null]);
            }

            $this->deleteByTenantIfColumnExists('cart_items', $tenantId);
            $this->deleteByTenantIfColumnExists('carts', $tenantId);
            $this->deleteByTenantIfColumnExists('item_images', $tenantId);
            $this->deleteByTenantIfColumnExists('item_prices', $tenantId);
            $this->deleteByTenantIfColumnExists('items', $tenantId);
            $this->deleteByTenantIfColumnExists('categories', $tenantId);
            $this->deleteByTenantIfColumnExists('user_favorite_stores', $tenantId);
            $this->deleteByTenantIfColumnExists('user_store_views', $tenantId);
            $this->deleteByTenantIfColumnExists('tenant_users', $tenantId);
            $this->deleteByTenantIfColumnExists('subscriptions', $tenantId);

            DB::table('tenants')->where('id', $tenantId)->delete();

            if ($ownerId > 0 && Schema::hasTable('users')) {
                if (Schema::hasTable('tenant_users') && Schema::hasColumn('tenant_users', 'user_id')) {
                    DB::table('tenant_users')->where('user_id', $ownerId)->delete();
                }

                if (Schema::hasTable('user_roles') && Schema::hasColumn('user_roles', 'user_id')) {
                    DB::table('user_roles')->where('user_id', $ownerId)->delete();
                }

                if (Schema::hasTable('personal_access_tokens') && Schema::hasColumn('personal_access_tokens', 'tokenable_id')) {
                    DB::table('personal_access_tokens')
                        ->where('tokenable_type', 'App\\Models\\User')
                        ->where('tokenable_id', $ownerId)
                        ->delete();
                }

                DB::table('users')->where('id', $ownerId)->delete();
            }
        });
    }

    /**
     * Deactivate owner login (mark owner as inactive).
     */
    public function deactivateOwner(Tenant $tenant): void
    {
        $tenant->owner->update(['status' => 'inactive']);
    }

    /**
     * Activate owner login.
     */
    public function activateOwner(Tenant $tenant): void
    {
        $tenant->owner->update(['status' => 'active']);
    }

    /**
     * Get tenant by slug.
     */
    public function findBySlug(string $slug): ?Tenant
    {
        return $this->baseQuery()->where('slug', $slug)->first();
    }

    private function deleteByTenantIfColumnExists(string $table, int $tenantId): void
    {
        if (! Schema::hasTable($table) || ! Schema::hasColumn($table, 'tenant_id')) {
            return;
        }

        DB::table($table)->where('tenant_id', $tenantId)->delete();
    }
}
