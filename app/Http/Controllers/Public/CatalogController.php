<?php

namespace App\Http\Controllers\Public;

use App\Http\Controllers\Controller;
use App\Http\Resources\ItemResource;
use App\Models\Item;
use App\Models\Subscription;
use App\Models\Tenant;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CatalogController extends Controller
{
    public function show(Request $request, string $tenant_slug): JsonResponse
    {
        $tenant = Tenant::query()
            ->where('slug', $tenant_slug)
            ->where('status', 'active')
            ->first();

        if ($tenant === null) {
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
                    ->where('tenant_id', $tenant->id)
                    ->where('pricing_status', 'active')
                    ->where('effective_from', '<=', now())
                    ->where(function ($nested): void {
                        $nested->whereNull('effective_to')->orWhere('effective_to', '>=', now());
                    });
            })
            ->with([
                'category:id,tenant_id,parent_id,name,slug,description,sort_order,status',
                'activePrice' => function ($query) use ($tenant): void {
                    $query
                        ->where('tenant_id', $tenant->id)
                        ->where('pricing_status', 'active')
                        ->where('effective_from', '<=', now())
                        ->where(function ($nested): void {
                            $nested->whereNull('effective_to')->orWhere('effective_to', '>=', now());
                        })
                        ->select([
                            'id',
                            'tenant_id',
                            'item_id',
                            'currency_code',
                            'base_price_amount',
                            'compare_at_price_amount',
                            'pricing_status',
                            'effective_from',
                            'effective_to',
                            'created_at',
                            'updated_at',
                        ]);
                },
                'primaryImage:id,tenant_id,item_id,storage_path,alt_text,sort_order,is_primary,created_at,updated_at',
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
