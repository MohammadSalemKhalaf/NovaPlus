<?php

namespace App\Http\Controllers\Public;

use App\Http\Controllers\Controller;
use App\Http\Resources\ItemResource;
use App\Models\Item;
use App\Models\Subscription;
use App\Models\Tenant;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;

class CatalogController extends Controller
{
    public function show(Request $request, Tenant $tenant_slug): JsonResponse
    {
        $tenant = $tenant_slug;

        if ($tenant->status !== 'active') {
            return response()->json([
                'success' => false,
                'message' => 'Catalog not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        $hasActiveSubscription = Subscription::query()
            ->where('tenant_id', $tenant->id)
            ->where('status', 'active')
            ->where('starts_at', '<=', now())
            ->where('ends_at', '>', now())
            ->exists();

        if (!$hasActiveSubscription) {
            return response()->json([
                'success' => false,
                'message' => 'Catalog not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        $perPage = max(1, min(100, $request->integer('per_page', 15)));

        $items = Item::query()
            ->where('tenant_id', $tenant->id)
            ->where('status', 'active')
            ->where('visibility', 'public')
            ->whereHas('itemPrices', function ($query) use ($tenant): void {
                $query
                    ->where('item_prices.tenant_id', $tenant->id)
                    ->where('item_prices.pricing_status', 'active')
                    ->where('item_prices.effective_from', '<=', now())
                    ->where(function ($nested): void {
                        $nested->whereNull('item_prices.effective_to')->orWhere('item_prices.effective_to', '>=', now());
                    });
            })
            ->with([
                'category:id,tenant_id,parent_id,name,slug,description,sort_order,status',
                'activePrice' => function ($query) use ($tenant): void {
                    $query
                        ->where('item_prices.tenant_id', $tenant->id)
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
                            'item_prices.created_at',
                            'item_prices.updated_at',
                        ]);
                },
                'primaryImage' => function ($query) use ($tenant): void {
                    $query
                        ->where('item_images.tenant_id', $tenant->id)
                        ->select([
                            'item_images.id',
                            'item_images.tenant_id',
                            'item_images.item_id',
                            'item_images.storage_path',
                            'item_images.alt_text',
                            'item_images.sort_order',
                            'item_images.is_primary',
                            'item_images.created_at',
                            'item_images.updated_at',
                        ]);
                },
                'itemImages' => function ($query) use ($tenant): void {
                    $query
                        ->where('tenant_id', $tenant->id)
                        ->select([
                            'id',
                            'tenant_id',
                            'item_id',
                            'storage_path',
                            'alt_text',
                            'sort_order',
                            'is_primary',
                            'created_at',
                            'updated_at',
                        ])
                        ->orderBy('sort_order')
                        ->orderBy('id');
                },
            ])
            ->when(Schema::hasTable('offers') && Schema::hasTable('offer_items'), function ($query) use ($tenant): void {
                $query->with([
                    'offers' => function ($offersQuery) use ($tenant): void {
                        $offersQuery
                            ->where('offers.tenant_id', $tenant->id)
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
            ->orderBy('sort_order')
            ->orderByDesc('id')
            ->paginate($perPage);

        return response()->json([
            'success' => true,
            'message' => 'Catalog fetched successfully.',
            'data' => [
                'tenant' => [
                    'id' => $tenant->id,
                    'name' => $tenant->name,
                    'slug' => $tenant->slug,
                ],
                'items' => ItemResource::collection(collect($items->items())),
                'pagination' => [
                    'current_page' => $items->currentPage(),
                    'last_page' => $items->lastPage(),
                    'per_page' => $items->perPage(),
                    'total' => $items->total(),
                ],
            ],
            'meta' => (object) [],
        ]);
    }
}
