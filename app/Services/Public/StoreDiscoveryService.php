<?php

namespace App\Services\Public;

use App\Models\Offer;
use App\Repositories\Catalog\ItemRepository;
use App\Repositories\Catalog\OfferRepository;
use App\Models\Category;
use App\Models\Item;
use App\Models\Tenant;
use Illuminate\Support\Collection;
use Illuminate\Pagination\LengthAwarePaginator;

class StoreDiscoveryService
{
    private const STORE_ITEMS_LIMIT = 10;
    private const STORE_TOP_ITEMS_LIMIT = 8;

    public function __construct(
        private readonly ItemRepository $itemRepository,
        private readonly OfferRepository $offerRepository,
    ) {
    }

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
                'tenants.store_image',
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
    public function getStoreBySlug(string $tenantSlug, array $filters = []): ?array
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
                'tenants.store_image',
                'tenants.business_mode',
            ])
            ->first();

        if ($tenant === null) {
            return null;
        }

        $sort = isset($filters['sort']) ? trim((string) $filters['sort']) : null;
        $items = $this->itemRepository->getPublicItemsForStore($tenant->id, $sort, self::STORE_ITEMS_LIMIT);
        $topItems = $this->itemRepository->getTopPublicItemsByCartAdds($tenant->id, self::STORE_TOP_ITEMS_LIMIT);
        $offers = $this->offerRepository->getActiveForPublicCatalog($tenant->id);

        return [
            'id' => $tenant->id,
            'name' => $tenant->name,
            'slug' => $tenant->slug,
            'image' => $tenant->store_image,
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
            'items' => $this->mapCatalogItems($items),
            'top_items' => $this->mapCatalogItems($topItems, true),
            'offers' => $offers->map(static function (Offer $offer): array {
                return [
                    'id' => (int) $offer->id,
                    'title' => (string) $offer->title,
                    'discount_type' => (string) $offer->discount_type,
                    'discount_value' => (float) $offer->discount_value,
                ];
            })->values()->all(),
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function getStoreByTenant(Tenant $tenant, array $filters = []): ?array
    {
        return $this->getStoreBySlug($tenant->slug, $filters);
    }

    /**
     * @param Collection<int, Item> $items
     * @return array<int, array<string, mixed>>
     */
    private function mapCatalogItems(Collection $items, bool $includeTopCount = false): array
    {
        return $items->map(static function (Item $item) use ($includeTopCount): array {
            $price = $item->activePrice !== null ? [
                'amount' => (float) $item->activePrice->base_price_amount,
                'currency' => $item->activePrice->currency_code,
            ] : null;

            $activeOffer = $item->active_offer;

            $payload = [
                'id' => (int) $item->id,
                'name' => (string) $item->name,
                'price' => $price,
                'final_price' => $price !== null ? [
                    'amount' => $item->final_price,
                    'currency' => $price['currency'],
                ] : null,
                'has_offer' => $item->has_offer,
                'active_offer' => $activeOffer !== null ? [
                    'id' => (int) $activeOffer->id,
                    'title' => (string) $activeOffer->title,
                    'discount_type' => (string) $activeOffer->discount_type,
                    'discount_value' => (float) $activeOffer->discount_value,
                ] : null,
                'image' => $item->primaryImage?->storage_path,
                'category' => $item->category !== null ? [
                    'id' => (int) $item->category->id,
                    'name' => (string) $item->category->name,
                ] : null,
            ];

            if ($includeTopCount) {
                $payload['cart_adds_count'] = (int) ($item->cart_adds_count ?? 0);
            }

            return $payload;
        })->values()->all();
    }
}
