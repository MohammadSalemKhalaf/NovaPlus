<?php

namespace App\Http\Controllers\Owner;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\ItemStoreRequest;
use App\Http\Requests\Admin\ItemUpdateRequest;
use App\Http\Resources\ItemResource;
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
            return $this->forbiddenResponse();
        }

        $items = $this->itemService->getByTenant($tenantId, [
            'per_page' => $request->integer('per_page', 15),
            'category_id' => $request->integer('category_id'),
            'search' => $request->input('search'),
            'status' => $request->input('status'),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Items fetched successfully.',
            'data' => [
                'items' => ItemResource::collection($items->items()),
            ],
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
            return $this->forbiddenResponse();
        }

        $item = $this->itemService->createForTenant(
            $request->validated(),
            $tenantId,
            $request->user()?->id,
        );

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

        $record = $this->itemService->findForTenant($tenantId, $item);

        if ($record === null) {
            return $this->notFoundResponse('Item not found.');
        }

        try {
            $this->authorize('view', $record);
        } catch (AuthorizationException) {
            return $this->forbiddenResponse();
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

        $record = $this->itemService->findForTenant($tenantId, $item);

        if ($record === null) {
            return $this->notFoundResponse('Item not found.');
        }

        try {
            $this->authorize('update', $record);
        } catch (AuthorizationException) {
            return $this->forbiddenResponse();
        }

        $updated = $this->itemService->updateForTenant(
            $record,
            $request->validated(),
            $tenantId,
            $request->user()?->id,
        );

        return response()->json([
            'success' => true,
            'message' => 'Item updated successfully.',
            'data' => [
                'item' => new ItemResource($updated),
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

        $record = $this->itemService->findForTenant($tenantId, $item);

        if ($record === null) {
            return $this->notFoundResponse('Item not found.');
        }

        try {
            $this->authorize('delete', $record);
        } catch (AuthorizationException) {
            return $this->forbiddenResponse();
        }

        $this->itemService->deleteForTenant(
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

    private function notFoundResponse(string $message): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => $message,
            'data' => (object) [],
            'meta' => (object) [],
        ], 404);
    }

    private function forbiddenResponse(): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => 'You are not authorized to access this resource.',
            'data' => (object) [],
            'meta' => (object) [],
        ], 403);
    }
}
