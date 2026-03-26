<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\CreateDraftItemPriceRequest;
use App\Http\Requests\Admin\SetActiveItemPriceRequest;
use App\Http\Requests\Admin\UpdateItemPriceRequest;
use App\Http\Resources\ItemPriceResource;
use App\Models\Item;
use App\Services\Admin\ItemPriceService;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class ItemPriceController extends Controller
{
    public function __construct(private readonly ItemPriceService $itemPriceService)
    {
    }

    public function setActive(SetActiveItemPriceRequest $request, int $item): JsonResponse
    {
        $tenantId = $this->resolveTenantId($request);

        if ($tenantId === null) {
            return $this->tenantContextRequiredResponse();
        }

        $itemRecord = $this->resolveItem($tenantId, $item);

        if ($itemRecord === null) {
            return response()->json([
                'success' => false,
                'message' => 'Item not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        try {
            $this->authorize('update', $itemRecord);
        } catch (AuthorizationException) {
            return response()->json([
                'success' => false,
                'message' => 'You are not authorized to access this resource.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 403);
        }

        try {
            $price = $this->itemPriceService->setActivePrice(
                $tenantId,
                $item,
                $request->validated(),
            );
        } catch (ModelNotFoundException) {
            return response()->json([
                'success' => false,
                'message' => 'Item not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        } catch (ValidationException $exception) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed.',
                'errors' => $exception->errors(),
            ], 422);
        }

        return response()->json([
            'success' => true,
            'message' => 'Active price set successfully.',
            'data' => [
                'price' => new ItemPriceResource($price),
            ],
            'meta' => (object) [],
        ]);
    }

    public function createDraft(CreateDraftItemPriceRequest $request, int $item): JsonResponse
    {
        $tenantId = $this->resolveTenantId($request);

        if ($tenantId === null) {
            return $this->tenantContextRequiredResponse();
        }

        $itemRecord = $this->resolveItem($tenantId, $item);

        if ($itemRecord === null) {
            return response()->json([
                'success' => false,
                'message' => 'Item not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        try {
            $this->authorize('update', $itemRecord);
        } catch (AuthorizationException) {
            return response()->json([
                'success' => false,
                'message' => 'You are not authorized to access this resource.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 403);
        }

        try {
            $price = $this->itemPriceService->createDraftPrice(
                $tenantId,
                $item,
                $request->validated(),
            );
        } catch (ModelNotFoundException) {
            return response()->json([
                'success' => false,
                'message' => 'Item not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        } catch (ValidationException $exception) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed.',
                'errors' => $exception->errors(),
            ], 422);
        }

        return response()->json([
            'success' => true,
            'message' => 'Draft price created successfully.',
            'data' => [
                'price' => new ItemPriceResource($price),
            ],
            'meta' => (object) [],
        ], 201);
    }

    public function update(UpdateItemPriceRequest $request, int $item, int $price): JsonResponse
    {
        $tenantId = $this->resolveTenantId($request);

        if ($tenantId === null) {
            return $this->tenantContextRequiredResponse();
        }

        $itemRecord = $this->resolveItem($tenantId, $item);

        if ($itemRecord === null) {
            return response()->json([
                'success' => false,
                'message' => 'Item not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        try {
            $this->authorize('update', $itemRecord);
        } catch (AuthorizationException) {
            return response()->json([
                'success' => false,
                'message' => 'You are not authorized to access this resource.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 403);
        }

        try {
            $updatedPrice = $this->itemPriceService->updatePrice(
                $tenantId,
                $item,
                $price,
                $request->validated(),
            );
        } catch (ModelNotFoundException) {
            return response()->json([
                'success' => false,
                'message' => 'Price not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        } catch (ValidationException $exception) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed.',
                'errors' => $exception->errors(),
            ], 422);
        }

        return response()->json([
            'success' => true,
            'message' => 'Price updated successfully.',
            'data' => [
                'price' => new ItemPriceResource($updatedPrice),
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

    private function resolveItem(int $tenantId, int $itemId): ?Item
    {
        return Item::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($itemId)
            ->first();
    }
}
