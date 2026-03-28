<?php

namespace App\Http\Controllers\Owner;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\CategoryStoreRequest;
use App\Http\Requests\Admin\CategoryUpdateRequest;
use App\Http\Resources\CategoryResource;
use App\Models\Category;
use App\Services\Admin\CategoryService;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CategoryController extends Controller
{
    public function __construct(private readonly CategoryService $categoryService)
    {
    }

    public function index(Request $request): JsonResponse
    {
        $tenantId = $this->resolveTenantId($request);

        if ($tenantId === null) {
            return $this->tenantContextRequiredResponse();
        }

        try {
            $this->authorize('viewAny', Category::class);
        } catch (AuthorizationException) {
            return $this->forbiddenResponse();
        }

        $categories = $this->categoryService->getByTenant($tenantId, [
            'per_page' => $request->integer('per_page', 15),
            'status' => $request->input('status'),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Categories fetched successfully.',
            'data' => [
                'categories' => CategoryResource::collection($categories->items()),
            ],
            'meta' => [
                'pagination' => [
                    'current_page' => $categories->currentPage(),
                    'last_page' => $categories->lastPage(),
                    'per_page' => $categories->perPage(),
                    'total' => $categories->total(),
                ],
            ],
        ]);
    }

    public function store(CategoryStoreRequest $request): JsonResponse
    {
        $tenantId = $this->resolveTenantId($request);

        if ($tenantId === null) {
            return $this->tenantContextRequiredResponse();
        }

        try {
            $this->authorize('create', Category::class);
        } catch (AuthorizationException) {
            return $this->forbiddenResponse();
        }

        $category = $this->categoryService->createForTenant(
            $request->validated(),
            $tenantId,
            $request->user()?->id,
        );

        return response()->json([
            'success' => true,
            'message' => 'Category created successfully.',
            'data' => [
                'category' => new CategoryResource($category),
            ],
            'meta' => (object) [],
        ], 201);
    }

    public function show(Request $request, int $category): JsonResponse
    {
        $tenantId = $this->resolveTenantId($request);

        if ($tenantId === null) {
            return $this->tenantContextRequiredResponse();
        }

        $record = $this->categoryService->findForTenant($tenantId, $category);

        if ($record === null) {
            return $this->notFoundResponse('Category not found.');
        }

        try {
            $this->authorize('view', $record);
        } catch (AuthorizationException) {
            return $this->forbiddenResponse();
        }

        return response()->json([
            'success' => true,
            'message' => 'Category fetched successfully.',
            'data' => [
                'category' => new CategoryResource($record),
            ],
            'meta' => (object) [],
        ]);
    }

    public function update(CategoryUpdateRequest $request, int $category): JsonResponse
    {
        $tenantId = $this->resolveTenantId($request);

        if ($tenantId === null) {
            return $this->tenantContextRequiredResponse();
        }

        $record = $this->categoryService->findForTenant($tenantId, $category);

        if ($record === null) {
            return $this->notFoundResponse('Category not found.');
        }

        try {
            $this->authorize('update', $record);
        } catch (AuthorizationException) {
            return $this->forbiddenResponse();
        }

        $updated = $this->categoryService->updateForTenant(
            $record,
            $request->validated(),
            $tenantId,
            $request->user()?->id,
        );

        return response()->json([
            'success' => true,
            'message' => 'Category updated successfully.',
            'data' => [
                'category' => new CategoryResource($updated),
            ],
            'meta' => (object) [],
        ]);
    }

    public function destroy(Request $request, int $category): JsonResponse
    {
        $tenantId = $this->resolveTenantId($request);

        if ($tenantId === null) {
            return $this->tenantContextRequiredResponse();
        }

        $record = $this->categoryService->findForTenant($tenantId, $category);

        if ($record === null) {
            return $this->notFoundResponse('Category not found.');
        }

        try {
            $this->authorize('delete', $record);
        } catch (AuthorizationException) {
            return $this->forbiddenResponse();
        }

        $this->categoryService->deleteForTenant(
            $record,
            $tenantId,
            $request->user()?->id,
        );

        return response()->json([
            'success' => true,
            'message' => 'Category archived successfully.',
            'data' => [
                'deleted' => true,
                'id' => $category,
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
