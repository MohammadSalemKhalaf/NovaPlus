<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\ItemStoreRequest;
use App\Http\Resources\ItemResource;
use App\Http\Requests\Admin\ItemUpdateRequest;
use App\Models\Item;
use App\Services\Admin\ItemService;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ItemController extends Controller
{
    public function __construct(private readonly ItemService $itemService)
    {
    }

    public function index(Request $request): JsonResponse
    {
        $tenantId = $this->resolveTenantId($request);

        if ($tenantId === null) {
            return $this->tenantContextRequiredResponse();
        }

        try {
            $this->authorize('viewAny', Item::class);
        } catch (AuthorizationException) {
            return response()->json([
                'success' => false,
                'message' => 'You are not authorized to access this resource.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 403);
        }

        $perPage = max(1, min(100, $request->integer('per_page', 15)));
        $categoryId = $request->integer('category_id');
        $search = trim((string) $request->input('search', ''));
        $statusFilter = (string) $request->input('status', '');

        $items = Item::query()
            ->where('tenant_id', $tenantId)
            ->when($categoryId > 0, function ($query) use ($categoryId): void {
                $query->where('category_id', $categoryId);
            })
            ->when($search !== '', function ($query) use ($search): void {
                $query->where('name', 'like', '%'.$search.'%');
            })
            ->when($statusFilter !== '', function ($query) use ($statusFilter): void {
                if ($statusFilter === 'active') {
                    $query->where('status', 'active');
                } elseif ($statusFilter === 'inactive') {
                    $query->whereIn('status', ['draft', 'archived']);
                }
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
                'category' => function ($query) use ($tenantId): void {
                    $query
                        ->where('tenant_id', $tenantId)
                        ->select([
                            'id',
                            'tenant_id',
                            'name',
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
                'activePrice' => function ($query) use ($tenantId): void {
                    $query
                        ->where('item_prices.tenant_id', $tenantId)
                        ->where('item_prices.pricing_status', 'active')
                        ->select([
                            'item_prices.id',
                            'item_prices.tenant_id',
                            'item_prices.item_id',
                            'item_prices.currency_code',
                            'item_prices.base_price_amount',
                        ]);
                },
            ])
            ->latest('id')
            ->paginate($perPage);

        $itemsData = collect($items->items())->map(function (Item $item): array {
            return [
                'id' => $item->id,
                'name' => $item->name,
                'category' => $item->category !== null ? [
                    'id' => $item->category->id,
                    'name' => $item->category->name,
                ] : null,
                'price' => $item->activePrice !== null ? [
                    'amount' => $item->activePrice->base_price_amount,
                    'currency' => $item->activePrice->currency_code,
                ] : null,
                'image' => $item->primaryImage?->storage_path,
                'status' => $item->status,
            ];
        })->values();

        return response()->json([
            'success' => true,
            'message' => 'Items fetched successfully.',
            'data' => $itemsData,
            'meta' => [
                'pagination' => [
                    'current_page' => $items->currentPage(),
                    'last_page' => $items->lastPage(),
                    'per_page' => $items->perPage(),
                    'total' => $items->total(),
                ],
            ],
        ]);
    }

    public function store(ItemStoreRequest $request): JsonResponse
    {
        $tenantId = $this->resolveTenantId($request);

        if ($tenantId === null) {
            return $this->tenantContextRequiredResponse();
        }

        try {
            $this->authorize('create', Item::class);
        } catch (AuthorizationException) {
            return response()->json([
                'success' => false,
                'message' => 'You are not authorized to access this resource.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 403);
        }

        $item = $this->itemService->createItem(
            $request->validated(),
            $tenantId,
            $request->user()?->id,
        );

        $item->load([
            'category' => function ($query) use ($tenantId): void {
                $query
                    ->where('tenant_id', $tenantId)
                    ->select([
                        'id',
                        'tenant_id',
                        'parent_id',
                        'name',
                        'slug',
                        'description',
                        'sort_order',
                        'status',
                    ]);
            },
            'primaryImage' => function ($query) use ($tenantId, $item): void {
                $query
                    ->where('item_images.tenant_id', $tenantId)
                    ->where('item_images.item_id', $item->id)
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
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Item created successfully.',
            'data' => [
                'item' => new ItemResource($item),
            ],
            'meta' => (object) [],
        ], 201);
    }

    public function show(Request $request, int $item): JsonResponse
    {
        $tenantId = $this->resolveTenantId($request);

        if ($tenantId === null) {
            return $this->tenantContextRequiredResponse();
        }

        $record = Item::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($item)
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
                'category' => function ($query) use ($tenantId): void {
                    $query
                        ->where('tenant_id', $tenantId)
                        ->select([
                            'id',
                            'tenant_id',
                            'parent_id',
                            'name',
                            'slug',
                            'description',
                            'sort_order',
                            'status',
                        ]);
                },
                'primaryImage' => function ($query) use ($tenantId): void {
                    $query
                        ->where('item_images.tenant_id', $tenantId)
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
                'activePrice' => function ($query) use ($tenantId): void {
                    $query
                        ->where('item_prices.tenant_id', $tenantId)
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
            ])
            ->first();

        if ($record === null) {
            return response()->json([
                'success' => false,
                'message' => 'Item not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        try {
            $this->authorize('view', $record);
        } catch (AuthorizationException) {
            return response()->json([
                'success' => false,
                'message' => 'You are not authorized to access this resource.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 403);
        }

        return response()->json([
            'success' => true,
            'message' => 'Item fetched successfully.',
            'data' => [
                'item' => new ItemResource($record),
            ],
            'meta' => (object) [],
        ]);
    }

    public function update(ItemUpdateRequest $request, int $item): JsonResponse
    {
        $tenantId = $this->resolveTenantId($request);

        if ($tenantId === null) {
            return $this->tenantContextRequiredResponse();
        }

        $record = Item::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($item)
            ->first();

        if ($record === null) {
            return response()->json([
                'success' => false,
                'message' => 'Item not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        try {
            $this->authorize('update', $record);
        } catch (AuthorizationException) {
            return response()->json([
                'success' => false,
                'message' => 'You are not authorized to access this resource.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 403);
        }

        $record = $this->itemService->updateItem(
            $record,
            $request->validated(),
            $tenantId,
            $request->user()?->id,
        );

        $record->load([
            'category' => function ($query) use ($tenantId): void {
                $query
                    ->where('tenant_id', $tenantId)
                    ->select([
                        'id',
                        'tenant_id',
                        'parent_id',
                        'name',
                        'slug',
                        'description',
                        'sort_order',
                        'status',
                    ]);
            },
            'primaryImage' => function ($query) use ($tenantId, $record): void {
                $query
                    ->where('item_images.tenant_id', $tenantId)
                    ->where('item_images.item_id', $record->id)
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
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Item updated successfully.',
            'data' => [
                'item' => new ItemResource($record),
            ],
            'meta' => (object) [],
        ]);
    }

    public function destroy(Request $request, int $item): JsonResponse
    {
        $tenantId = $this->resolveTenantId($request);

        if ($tenantId === null) {
            return $this->tenantContextRequiredResponse();
        }

        $record = Item::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($item)
            ->first();

        if ($record === null) {
            return response()->json([
                'success' => false,
                'message' => 'Item not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        try {
            $this->authorize('delete', $record);
        } catch (AuthorizationException) {
            return response()->json([
                'success' => false,
                'message' => 'You are not authorized to access this resource.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 403);
        }

        $this->itemService->archiveItem(
            $record,
            $tenantId,
            $request->user()?->id,
        );

        return response()->json([
            'success' => true,
            'message' => 'Item archived successfully.',
            'data' => [
                'deleted' => true,
                'id' => $item,
            ],
            'meta' => (object) [],
        ]);
    }

    private function resolveTenantId(Request $request): ?int
    {
        $tenant = $request->attributes->get('tenant');

        if (is_object($tenant) && method_exists($tenant, 'getKey')) {
            return (int) $tenant->getKey();
        }

        $tenantId = $request->attributes->get('tenant_id');

        return is_numeric($tenantId) ? (int) $tenantId : null;
    }

    private function tenantContextRequiredResponse(): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => 'Tenant context is required.',
            'data' => (object) [],
            'meta' => (object) [],
        ], 400);
    }
}
