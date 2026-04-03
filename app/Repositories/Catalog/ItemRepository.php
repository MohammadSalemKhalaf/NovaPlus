<?php

namespace App\Repositories\Catalog;

use App\Models\Item;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class ItemRepository
{
    /**
     * @return Collection<int, Item>
     */
    public function getPublicItemsForStore(int $tenantId, ?string $sort = null, int $limit = 10): Collection
    {
        $normalizedSort = is_string($sort) ? trim(strtolower($sort)) : null;
        $limited = max(1, min(50, $limit));

        $query = $this->basePublicItemsQuery($tenantId);

        if ($normalizedSort === 'top') {
            $query
                ->leftJoin('cart_items', 'cart_items.item_id', '=', 'items.id')
                ->leftJoin('carts', function ($join) use ($tenantId): void {
                    $join
                        ->on('carts.id', '=', 'cart_items.cart_id')
                        ->where('carts.tenant_id', '=', $tenantId);
                })
                ->addSelect(DB::raw('COUNT(carts.id) as cart_adds_count'))
                ->groupBy($this->publicItemGroupColumns())
                ->orderByDesc('cart_adds_count')
                ->orderByDesc('items.id');
        } elseif ($normalizedSort === 'discount' && Schema::hasTable('offers') && Schema::hasTable('offer_items')) {
            $query
                ->leftJoin('item_prices as active_sort_prices', function ($join) use ($tenantId): void {
                    $join
                        ->on('active_sort_prices.item_id', '=', 'items.id')
                        ->where('active_sort_prices.tenant_id', '=', $tenantId)
                        ->where('active_sort_prices.pricing_status', '=', 'active')
                        ->where('active_sort_prices.effective_from', '<=', now())
                        ->where(function ($nested): void {
                            $nested->whereNull('active_sort_prices.effective_to')->orWhere('active_sort_prices.effective_to', '>=', now());
                        });
                })
                ->leftJoin('offer_items', 'offer_items.item_id', '=', 'items.id')
                ->leftJoin('offers', function ($join) use ($tenantId): void {
                    $join
                        ->on('offers.id', '=', 'offer_items.offer_id')
                        ->where('offers.tenant_id', '=', $tenantId)
                        ->where('offers.status', '=', 'active')
                        ->where(function ($nested): void {
                            $nested->whereNull('offers.starts_at')->orWhere('offers.starts_at', '<=', now());
                        })
                        ->where(function ($nested): void {
                            $nested->whereNull('offers.ends_at')->orWhere('offers.ends_at', '>=', now());
                        });
                })
                ->addSelect(DB::raw("MAX(CASE WHEN offers.discount_type = 'percentage' THEN COALESCE(active_sort_prices.base_price_amount, 0) * (offers.discount_value / 100) WHEN offers.discount_type = 'fixed' THEN offers.discount_value ELSE 0 END) as sort_discount_amount"))
                ->groupBy($this->publicItemGroupColumns())
                ->orderByDesc('sort_discount_amount')
                ->orderByDesc('items.id');
        } elseif ($normalizedSort === 'newest') {
            $query->orderByDesc('items.id');
        } else {
            $query
                ->orderBy('items.sort_order')
                ->orderByDesc('items.id');
        }

        return $query
            ->limit($limited)
            ->get();
    }

    /**
     * @return Collection<int, Item>
     */
    public function getTopPublicItemsByCartAdds(int $tenantId, int $limit = 8): Collection
    {
        $limited = max(5, min(10, $limit));

        return $this->basePublicItemsQuery($tenantId)
            ->join('cart_items', 'cart_items.item_id', '=', 'items.id')
            ->join('carts', function ($join) use ($tenantId): void {
                $join
                    ->on('carts.id', '=', 'cart_items.cart_id')
                    ->where('carts.tenant_id', '=', $tenantId);
            })
            ->addSelect(DB::raw('COUNT(cart_items.id) as cart_adds_count'))
            ->groupBy($this->publicItemGroupColumns())
            ->orderByDesc('cart_adds_count')
            ->orderByDesc('items.id')
            ->limit($limited)
            ->get();
    }

    /**
     * @param array{per_page?: int, category_id?: int|null, search?: string|null, status?: string|null} $filters
     */
    public function paginateByTenant(int $tenantId, array $filters = []): LengthAwarePaginator
    {
        $perPage = max(1, min(100, (int) ($filters['per_page'] ?? 15)));
        $categoryId = (int) ($filters['category_id'] ?? 0);
        $search = isset($filters['search']) ? trim((string) $filters['search']) : '';
        $status = isset($filters['status']) ? trim((string) $filters['status']) : '';

        return Item::query()
            ->where('tenant_id', $tenantId)
            ->when($categoryId > 0, function ($query) use ($categoryId): void {
                $query->where('category_id', $categoryId);
            })
            ->when($search !== '', function ($query) use ($search): void {
                $query->where('name', 'like', '%'.$search.'%');
            })
            ->when($status !== '', function ($query) use ($status): void {
                $query->where('status', $status);
            })
            ->select([
                'id',
                'tenant_id',
                'category_id',
                'name',
                'slug',
                'short_description',
                'long_description',
                'item_type',
                'status',
                'visibility',
                'primary_image_id',
                'sort_order',
                'created_by_user_id',
                'updated_by_user_id',
                'created_at',
                'updated_at',
            ])
            ->with([
                'activePrice' => function ($query) use ($tenantId): void {
                    $query
                        ->where('item_prices.tenant_id', $tenantId)
                        ->where('item_prices.pricing_status', 'active')
                        ->where('item_prices.effective_from', '<=', now())
                        ->where(function ($nested): void {
                            $nested->whereNull('item_prices.effective_to')->orWhere('item_prices.effective_to', '>=', now());
                        })
                        ->select([
                            'item_prices.id',
                            'item_prices.tenant_id',
                            'item_prices.item_id',
                            'item_prices.currency_code',
                            'item_prices.base_price_amount',
                            'item_prices.compare_at_price_amount',
                            'item_prices.pricing_status',
                            'item_prices.effective_from',
                            'item_prices.effective_to',
                        ]);
                },
            ])
            ->when(Schema::hasTable('offers') && Schema::hasTable('offer_items'), function ($query) use ($tenantId): void {
                $query->with([
                    'offers' => function ($offersQuery) use ($tenantId): void {
                        $offersQuery
                            ->where('offers.tenant_id', $tenantId)
                            ->select([
                                'offers.id',
                                'offers.tenant_id',
                                'offers.title',
                                'offers.discount_type',
                                'offers.discount_value',
                                'offers.starts_at',
                                'offers.ends_at',
                                'offers.status',
                            ]);
                    },
                ]);
            })
            ->latest('id')
            ->paginate($perPage);
    }

    public function createForTenant(array $validatedData, int $tenantId, ?int $userId = null): Item
    {
        return Item::query()->create([
            ...$validatedData,
            'tenant_id' => $tenantId,
            'created_by_user_id' => $userId,
            'updated_by_user_id' => $userId,
        ]);
    }

    public function findForTenant(int $tenantId, int $itemId): ?Item
    {
        return Item::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($itemId)
            ->first();
    }

    public function updateForTenant(Item $item, array $validatedData, int $tenantId, ?int $userId = null): Item
    {
        if ((int) $item->tenant_id !== $tenantId) {
            return $item;
        }

        $item->fill([
            ...$validatedData,
            'updated_by_user_id' => $userId,
        ]);
        $item->save();

        return $item;
    }

    public function archiveForTenant(Item $item, int $tenantId, ?int $userId = null): Item
    {
        if ((int) $item->tenant_id !== $tenantId) {
            return $item;
        }

        $item->update([
            'status' => 'archived',
            'updated_by_user_id' => $userId,
        ]);

        return $item;
    }

    public function countForTenant(int $tenantId): int
    {
        return Item::query()
            ->where('tenant_id', $tenantId)
            ->count();
    }

    private function basePublicItemsQuery(int $tenantId): Builder
    {
        return Item::query()
            ->where('items.tenant_id', $tenantId)
            ->where('items.status', 'active')
            ->where('items.visibility', 'public')
            ->whereHas('itemPrices', function (Builder $query) use ($tenantId): void {
                $this->applyActivePriceConstraint($query, $tenantId);
            })
            ->select($this->publicItemSelectColumns())
            ->with([
                'category' => function ($query) use ($tenantId): void {
                    $query
                        ->where('categories.tenant_id', $tenantId)
                        ->select([
                            'categories.id',
                            'categories.name',
                        ]);
                },
                'activePrice' => function ($query) use ($tenantId): void {
                    $this->applyActivePriceConstraint($query, $tenantId);

                    $query->select([
                        'item_prices.id',
                        'item_prices.tenant_id',
                        'item_prices.item_id',
                        'item_prices.currency_code',
                        'item_prices.base_price_amount',
                    ]);
                },
                'primaryImage' => function ($query) use ($tenantId): void {
                    $query
                        ->where('item_images.tenant_id', $tenantId)
                        ->select([
                            'item_images.id',
                            'item_images.item_id',
                            'item_images.storage_path',
                            'item_images.is_primary',
                        ]);
                },
            ])
            ->when(Schema::hasTable('offers') && Schema::hasTable('offer_items'), function (Builder $query) use ($tenantId): void {
                $query->with([
                    'offers' => function ($offersQuery) use ($tenantId): void {
                        $offersQuery
                            ->where('offers.tenant_id', $tenantId)
                            ->where('offers.status', 'active')
                            ->where(function ($nested): void {
                                $nested->whereNull('offers.starts_at')->orWhere('offers.starts_at', '<=', now());
                            })
                            ->where(function ($nested): void {
                                $nested->whereNull('offers.ends_at')->orWhere('offers.ends_at', '>=', now());
                            })
                            ->select([
                                'offers.id',
                                'offers.tenant_id',
                                'offers.title',
                                'offers.discount_type',
                                'offers.discount_value',
                                'offers.starts_at',
                                'offers.ends_at',
                                'offers.status',
                            ]);
                    },
                ]);
            });
    }

    /**
     * @return array<int, string>
     */
    private function publicItemSelectColumns(): array
    {
        return [
            'items.id',
            'items.tenant_id',
            'items.category_id',
            'items.name',
            'items.slug',
            'items.status',
            'items.visibility',
            'items.sort_order',
            'items.created_at',
        ];
    }

    /**
     * @return array<int, string>
     */
    private function publicItemGroupColumns(): array
    {
        return $this->publicItemSelectColumns();
    }

    private function applyActivePriceConstraint(Builder $query, int $tenantId): void
    {
        $query
            ->where('item_prices.tenant_id', $tenantId)
            ->where('item_prices.pricing_status', 'active')
            ->where('item_prices.effective_from', '<=', now())
            ->where(function ($nested): void {
                $nested->whereNull('item_prices.effective_to')->orWhere('item_prices.effective_to', '>=', now());
            });
    }
}
