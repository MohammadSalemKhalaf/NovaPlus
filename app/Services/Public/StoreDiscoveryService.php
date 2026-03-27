<?php

namespace App\Services\Public;

use App\Models\Category;
use App\Models\Item;
use App\Models\Tenant;
use Illuminate\Pagination\LengthAwarePaginator;

class StoreDiscoveryService
{
    /**
     * @param array<string, mixed> $filters
     */
    public function listStores(array $filters): LengthAwarePaginator
    {
        $perPage = isset($filters['per_page']) ? (int) $filters['per_page'] : 10;
        $search = trim((string) ($filters['search'] ?? ''));
        $businessTypeId = isset($filters['business_type_id']) ? (int) $filters['business_type_id'] : null;

        $query = Tenant::query()
            ->with('businessType')
            ->where('tenants.status', 'active')
            ->whereHas('subscriptions', function ($subscriptionQuery): void {
                $subscriptionQuery
                    ->where('subscriptions.status', 'active')
                    ->where('subscriptions.starts_at', '<=', now())
                    ->where('subscriptions.ends_at', '>', now());
            })
            ->select([
                'tenants.id',
                'tenants.name',
                'tenants.slug',
                'tenants.business_type_id',
                'tenants.whatsapp_number',
            ])
            ->orderBy('tenants.name')
            ->orderBy('tenants.id');

        if ($search !== '') {
            $query->where('tenants.name', 'like', '%'.$search.'%');
        }

        if ($businessTypeId !== null && $businessTypeId > 0) {
            $query->where('tenants.business_type_id', $businessTypeId);
        }

        return $query->paginate($perPage);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function getStoreBySlug(string $tenantSlug): ?array
    {
        $tenant = Tenant::query()
            ->with('businessType')
            ->where('tenants.status', 'active')
            ->where('tenants.slug', $tenantSlug)
            ->whereHas('subscriptions', function ($subscriptionQuery): void {
                $subscriptionQuery
                    ->where('subscriptions.status', 'active')
                    ->where('subscriptions.starts_at', '<=', now())
                    ->where('subscriptions.ends_at', '>', now());
            })
            ->select([
                'tenants.id',
                'tenants.name',
                'tenants.slug',
                'tenants.business_type_id',
                'tenants.whatsapp_number',
                'tenants.business_mode',
            ])
            ->first();

        if ($tenant === null) {
            return null;
        }

        return [
            'id' => $tenant->id,
            'name' => $tenant->name,
            'slug' => $tenant->slug,
            'business_mode' => $tenant->business_mode,
            'business_type' => $tenant->businessType !== null ? [
                'id' => $tenant->businessType->id,
                'name' => $tenant->businessType->name,
                'slug' => $tenant->businessType->slug,
            ] : null,
            'catalog_summary' => [
                'categories_count' => (int) Category::query()
                    ->where('categories.tenant_id', $tenant->id)
                    ->where('categories.status', 'active')
                    ->count(),
                'public_items_count' => (int) Item::query()
                    ->where('items.tenant_id', $tenant->id)
                    ->where('items.status', 'active')
                    ->where('items.visibility', 'public')
                    ->whereHas('itemPrices', function ($priceQuery) use ($tenant): void {
                        $priceQuery
                            ->where('item_prices.tenant_id', $tenant->id)
                            ->where('item_prices.pricing_status', 'active')
                            ->where('item_prices.effective_from', '<=', now())
                            ->where(function ($nested): void {
                                $nested
                                    ->whereNull('item_prices.effective_to')
                                    ->orWhere('item_prices.effective_to', '>=', now());
                            });
                    })
                    ->count(),
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function getStoreByTenant(Tenant $tenant): ?array
    {
        return $this->getStoreBySlug($tenant->slug);
    }
}
