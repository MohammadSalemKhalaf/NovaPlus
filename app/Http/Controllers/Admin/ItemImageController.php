<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\SetPrimaryItemImageRequest;
use App\Http\Requests\Admin\UploadItemImageRequest;
use App\Http\Resources\ItemImageResource;
use App\Models\Item;
use App\Services\Admin\ItemImageService;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ItemImageController extends Controller
{
    public function __construct(private readonly ItemImageService $itemImageService)
    {
    }

    public function index(Request $request, int $item): JsonResponse
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
            $this->authorize('view', $itemRecord);
        } catch (AuthorizationException) {
            return response()->json([
                'success' => false,
                'message' => 'You are not authorized to access this resource.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 403);
        }

        $images = $this->itemImageService->listImages($tenantId, $item);

        return response()->json([
            'success' => true,
            'message' => 'Item images fetched successfully.',
            'data' => [
                'images' => ItemImageResource::collection($images),
            ],
            'meta' => (object) [],
        ]);
    }

    public function store(UploadItemImageRequest $request, int $item): JsonResponse
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
            $image = $this->itemImageService->uploadImage(
                $tenantId,
                $item,
                $request->file('image'),
                $request->validated(),
            );
        } catch (ModelNotFoundException) {
            return response()->json([
                'success' => false,
                'message' => 'Item not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Item image uploaded successfully.',
            'data' => [
                'image' => new ItemImageResource($image),
            ],
            'meta' => (object) [],
        ], 201);
    }

    public function setPrimary(SetPrimaryItemImageRequest $request, int $item, int $image): JsonResponse
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
            $updatedImage = $this->itemImageService->setPrimaryImage($tenantId, $item, $image);
        } catch (ModelNotFoundException) {
            return response()->json([
                'success' => false,
                'message' => 'Image not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Primary image updated successfully.',
            'data' => [
                'image' => new ItemImageResource($updatedImage),
            ],
            'meta' => (object) [],
        ]);
    }

    public function destroy(Request $request, int $item, int $image): JsonResponse
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
            $this->authorize('delete', $itemRecord);
        } catch (AuthorizationException) {
            return response()->json([
                'success' => false,
                'message' => 'You are not authorized to access this resource.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 403);
        }

        try {
            $this->itemImageService->deleteImage($tenantId, $item, $image);
        } catch (ModelNotFoundException) {
            return response()->json([
                'success' => false,
                'message' => 'Image not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Item image deleted successfully.',
            'data' => [
                'deleted' => true,
                'id' => $image,
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

    private function resolveItem(int $tenantId, int $itemId): ?Item
    {
        return Item::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($itemId)
            ->first();
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
