<?php

namespace App\Http\Controllers\Public;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Item;
use App\Models\ItemPrice;
use App\Models\Subscription;
use App\Models\Tenant;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Schema;

class PublicCatalogController extends Controller
{
    public function categories(Request $request, Tenant $tenant_slug): JsonResponse
    {
        $tenant = $tenant_slug;

        if (($guardResponse = $this->ensureCatalogAccess($tenant)) !== null) {
            return $guardResponse;
        }

        $perPage = max(1, min(100, $request->integer('per_page', 15)));
        $sort = (string) $request->input('sort', 'name');
        $direction = strtolower((string) $request->input('direction', 'asc')) === 'desc' ? 'desc' : 'asc';

        $cacheKey = $this->categoriesCacheKey($tenant->id, $request, $perPage, $sort, $direction);

        $payload = Cache::remember($cacheKey, 60, function () use ($tenant, $perPage, $sort, $direction): array {
            $categories = Category::query()
                ->where('categories.tenant_id', $tenant->id)
                ->where('categories.status', 'active')
                ->whereHas('items', function (Builder $query) use ($tenant): void {
                    $query
                        ->where('items.tenant_id', $tenant->id)
                        ->where('items.status', 'active')
                        ->where('items.visibility', 'public')
                        ->whereHas('itemPrices', function (Builder $priceQuery) use ($tenant): void {
                            $this->applyActivePriceConstraint($priceQuery, $tenant->id);
                        });
                })
                ->select([
                    'categories.id',
                    'categories.name',
                    'categories.slug',
                    'categories.sort_order',
                ])
                ->when($sort === 'created_at', function (Builder $query) use ($direction): void {
                    $query->orderBy('categories.created_at', $direction);
                }, function (Builder $query) use ($direction): void {
                    $query->orderBy('categories.name', $direction);
                })
                ->orderBy('categories.id')
                ->paginate($perPage);

            return [
                'data' => collect($categories->items())->map(fn (Category $category): array => [
                    'id' => $category->id,
                    'name' => $category->name,
                    'slug' => $category->slug,
                ])->values()->all(),
                'meta' => [
                    'pagination' => [
                        'current_page' => $categories->currentPage(),
                        'last_page' => $categories->lastPage(),
                        'per_page' => $categories->perPage(),
                        'total' => $categories->total(),
                    ],
                ],
            ];
        });

        return response()->json([
            'success' => true,
            'message' => 'Catalog categories fetched successfully.',
            'data' => $payload['data'],
            'meta' => $payload['meta'],
        ]);
    }

    public function items(Request $request, Tenant $tenant_slug): JsonResponse
    {
        $tenant = $tenant_slug;

        if (($guardResponse = $this->ensureCatalogAccess($tenant)) !== null) {
            return $guardResponse;
        }

        $perPage = max(1, min(100, $request->integer('per_page', 15)));
        $categoryId = $request->integer('category_id');
        $hasCategoryFilter = $request->filled('category_id');
        $search = trim((string) $request->input('search', ''));
        $sort = (string) $request->input('sort', 'latest');
        $direction = strtolower((string) $request->input('direction', 'desc')) === 'asc' ? 'asc' : 'desc';
        $featured = $request->boolean('featured', false);

        if ($hasCategoryFilter) {
            $category = Category::query()
                ->where('categories.id', $categoryId)
                ->where('categories.tenant_id', $tenant->id)
                ->first();

            if ($category === null) {
                return $this->categoryNotFoundResponse();
            }
        }

        $cacheKey = $this->itemsCacheKey($tenant->id, $request, $perPage, $categoryId, $search, $sort, $direction, $featured);

        $payload = Cache::remember($cacheKey, 60, function () use ($tenant, $perPage, $categoryId, $hasCategoryFilter, $search, $sort, $direction, $featured): array {
            $itemsQuery = Item::query()
                ->where('items.tenant_id', $tenant->id)
                ->where('items.status', 'active')
                ->where('items.visibility', 'public')
                ->when($hasCategoryFilter, function (Builder $query) use ($categoryId): void {
                    $query->where('items.category_id', $categoryId);
                })
                ->when($search !== '', function (Builder $query) use ($search): void {
                    $query->where('items.name', 'like', '%'.$search.'%');
                })
                ->when($featured && Schema::hasColumn('items', 'is_featured'), function (Builder $query): void {
                    $query->where('items.is_featured', true);
                })
                ->whereHas('itemPrices', function (Builder $query) use ($tenant): void {
                    $this->applyActivePriceConstraint($query, $tenant->id);
                })
                ->select([
                    'items.id',
                    'items.tenant_id',
                    'items.category_id',
                    'items.name',
                    'items.slug',
                    'items.status',
                    'items.visibility',
                    'items.sort_order',
                    'items.created_at',
                ])
                ->with([
                    'category' => function (Builder $query) use ($tenant): void {
                        $query
                            ->where('categories.tenant_id', $tenant->id)
                            ->select([
                                'categories.id',
                                'categories.name',
                            ]);
                    },
                    'activePrice' => function (Builder $query) use ($tenant): void {
                        $this->applyActivePriceConstraint($query, $tenant->id);

                        $query->select([
                            'item_prices.id',
                            'item_prices.tenant_id',
                            'item_prices.item_id',
                            'item_prices.currency_code',
                            'item_prices.base_price_amount',
                        ]);
                    },
                    'primaryImage' => function (Builder $query) use ($tenant): void {
                        $query
                            ->where('item_images.tenant_id', $tenant->id)
                            ->select([
                                'item_images.id',
                                'item_images.item_id',
                                'item_images.storage_path',
                                'item_images.is_primary',
                            ]);
                    },
                ])
                ->when(in_array($sort, ['price_asc', 'price_desc'], true), function (Builder $query) use ($tenant): void {
                    $query->addSelect([
                        'sort_price' => $this->activePriceAmountSubquery($tenant->id),
                    ]);
                });

            switch ($sort) {
                case 'price_asc':
                    $itemsQuery
                        ->orderBy('sort_price', 'asc')
                        ->orderByDesc('items.id');
                    break;

                case 'price_desc':
                    $itemsQuery
                        ->orderBy('sort_price', 'desc')
                        ->orderByDesc('items.id');
                    break;

                case 'name':
                    $itemsQuery
                        ->orderBy('items.name', $direction)
                        ->orderByDesc('items.id');
                    break;

                case 'latest':
                default:
                    $itemsQuery->orderByDesc('items.id');
                    break;
            }

            $items = $itemsQuery->paginate($perPage);

            return [
                'data' => collect($items->items())->map(function (Item $item): array {
                    return [
                        'id' => $item->id,
                        'name' => $item->name,
                        'price' => $item->activePrice !== null ? [
                            'amount' => $item->activePrice->base_price_amount,
                            'currency' => $item->activePrice->currency_code,
                        ] : null,
                        'image' => $item->primaryImage?->storage_path,
                        'category' => $item->category?->name,
                    ];
                })->values()->all(),
                'meta' => [
                    'pagination' => [
                        'current_page' => $items->currentPage(),
                        'last_page' => $items->lastPage(),
                        'per_page' => $items->perPage(),
                        'total' => $items->total(),
                    ],
                ],
            ];
        });

        return response()->json([
            'success' => true,
            'message' => $payload['data'] === [] ? 'No items found' : 'Catalog items fetched successfully.',
            'data' => $payload['data'],
            'meta' => $payload['meta'],
        ]);
    }

    private function ensureCatalogAccess(Tenant $tenant): ?JsonResponse
    {
        if ($tenant->status !== 'active') {
            return $this->tenantInactiveResponse();
        }

        $hasActiveSubscription = Subscription::query()
            ->where('subscriptions.tenant_id', $tenant->id)
            ->where('subscriptions.status', 'active')
            ->where('subscriptions.starts_at', '<=', now())
            ->where('subscriptions.ends_at', '>', now())
            ->exists();

        return $hasActiveSubscription ? null : $this->subscriptionExpiredResponse();
    }

    private function applyActivePriceConstraint(Builder $query, int $tenantId): void
    {
        $query
            ->where('item_prices.tenant_id', $tenantId)
            ->where('item_prices.pricing_status', 'active')
            ->where('item_prices.effective_from', '<=', now())
            ->where(function (Builder $nested): void {
                $nested
                    ->whereNull('item_prices.effective_to')
                    ->orWhere('item_prices.effective_to', '>=', now());
            });
    }

    private function subscriptionExpiredResponse(): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => 'Subscription expired',
            'data' => [],
            'meta' => (object) [],
        ], 403);
    }

    private function tenantInactiveResponse(): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => 'Tenant is inactive',
            'data' => [],
            'meta' => (object) [],
        ], 403);
    }

    private function categoryNotFoundResponse(): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => 'Category not found',
            'data' => [],
            'meta' => (object) [],
        ], 404);
    }

    private function activePriceAmountSubquery(int $tenantId): Builder
    {
        return ItemPrice::query()
            ->select('item_prices.base_price_amount')
            ->where('item_prices.tenant_id', $tenantId)
            ->whereColumn('item_prices.item_id', 'items.id')
            ->where('item_prices.pricing_status', 'active')
            ->where('item_prices.effective_from', '<=', now())
            ->where(function (Builder $nested): void {
                $nested
                    ->whereNull('item_prices.effective_to')
                    ->orWhere('item_prices.effective_to', '>=', now());
            })
            ->orderByDesc('item_prices.id')
            ->limit(1);
    }

    private function itemsCacheKey(
        int $tenantId,
        Request $request,
        int $perPage,
        int $categoryId,
        string $search,
        string $sort,
        string $direction,
        bool $featured,
    ): string {
        $hash = md5(json_encode([
            'tenant_id' => $tenantId,
            'page' => $request->integer('page', 1),
            'per_page' => $perPage,
            'category_id' => $categoryId,
            'search' => $search,
            'sort' => $sort,
            'direction' => $direction,
            'featured' => $featured,
        ]));

        return 'public_catalog_items:'.$hash;
    }

    private function categoriesCacheKey(
        int $tenantId,
        Request $request,
        int $perPage,
        string $sort,
        string $direction,
    ): string {
        $hash = md5(json_encode([
            'tenant_id' => $tenantId,
            'page' => $request->integer('page', 1),
            'per_page' => $perPage,
            'sort' => $sort,
            'direction' => $direction,
        ]));

        return 'public_catalog_categories:'.$hash;
    }
}
