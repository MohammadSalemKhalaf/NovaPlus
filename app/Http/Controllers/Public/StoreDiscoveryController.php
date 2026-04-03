<?php

namespace App\Http\Controllers\Public;

use App\Http\Controllers\Controller;
use App\Http\Requests\Public\PublicStoreIndexRequest;
use App\Http\Requests\Public\PublicStoreShowRequest;
use App\Models\Tenant;
use App\Services\Public\StoreDiscoveryService;
use Illuminate\Http\JsonResponse;

class StoreDiscoveryController extends Controller
{
    public function __construct(private readonly StoreDiscoveryService $storeDiscoveryService)
    {
    }

    public function index(PublicStoreIndexRequest $request): JsonResponse
    {
        $payload = $request->validated();

        $stores = $this->storeDiscoveryService->listStores($payload);

        return response()->json([
            'success' => true,
            'message' => 'Stores fetched successfully.',
            'data' => collect($stores->items())->map(static function ($store): array {
                return [
                    'id' => $store->id,
                    'name' => $store->name,
                    'slug' => $store->slug,
                    'business_type' => $store->businessType !== null ? [
                        'id' => $store->businessType->id,
                        'name' => $store->businessType->name,
                        'slug' => $store->businessType->slug,
                    ] : null,
                ];
            })->values(),
            'meta' => [
                'pagination' => [
                    'current_page' => $stores->currentPage(),
                    'last_page' => $stores->lastPage(),
                    'per_page' => $stores->perPage(),
                    'total' => $stores->total(),
                ],
            ],
        ]);
    }

    public function show(PublicStoreShowRequest $request, Tenant $tenant_slug): JsonResponse
    {
        $store = $this->storeDiscoveryService->getStoreByTenant($tenant_slug, $request->validated());

        if ($store === null) {
            return response()->json([
                'success' => false,
                'message' => 'Store not found.',
                'data' => [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Store fetched successfully.',
            'data' => [
                'id' => $store['id'],
                'name' => $store['name'],
                'slug' => $store['slug'],
                'business_mode' => $store['business_mode'],
                'business_type' => $store['business_type'],
                'catalog_summary' => $store['catalog_summary'],
                'catalog_endpoints' => [
                    'items' => '/api/v1/public/catalog/'.$store['slug'].'/items',
                    'categories' => '/api/v1/public/catalog/'.$store['slug'].'/categories',
                ],
                'items' => $store['items'],
                'top_items' => $store['top_items'],
                'offers' => $store['offers'],
            ],
            'meta' => (object) [],
        ]);
    }
}
