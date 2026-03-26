<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\CategoryStoreRequest;
use App\Http\Resources\CategoryResource;
use App\Http\Requests\Admin\CategoryUpdateRequest;
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
            return response()->json([
                'success' => false,
                'message' => 'You are not authorized to access this resource.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 403);
        }

        $perPage = max(1, min(100, $request->integer('per_page', 15)));
        $includeChildren = $request->boolean('include_children', true);

        $query = Category::query()
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
                'created_at',
                'updated_at',
            ])
            ->orderBy('sort_order')
            ->orderByDesc('id');

        if ($includeChildren) {
            $query->with([
                'children' => function ($childrenQuery) use ($tenantId): void {
                    $childrenQuery
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
                            'created_at',
                            'updated_at',
                        ])
                        ->orderBy('sort_order')
                        ->orderByDesc('id');
                },
            ]);
        }

        $categories = $query->paginate($perPage);

        return response()->json([
            'success' => true,
            'message' => 'Categories fetched successfully.',
            'data' => [
                'categories' => CategoryResource::collection(collect($categories->items())),
                'pagination' => [
                    'current_page' => $categories->currentPage(),
                    'last_page' => $categories->lastPage(),
                    'per_page' => $categories->perPage(),
                    'total' => $categories->total(),
                ],
            ],
            'meta' => (object) [],
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
            return response()->json([
                'success' => false,
                'message' => 'You are not authorized to access this resource.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 403);
        }

        $category = $this->categoryService->createCategory(
            $request->validated(),
            $tenantId,
            $request->user()?->id,
        );

        $category->load([
            'children' => function ($childrenQuery) use ($tenantId): void {
                $childrenQuery
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
                        'created_at',
                        'updated_at',
                    ])
                    ->orderBy('sort_order')
                    ->orderByDesc('id');
            },
        ]);

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

        $record = Category::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($category)
            ->with([
                'children' => function ($childrenQuery) use ($tenantId): void {
                    $childrenQuery
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
                            'created_at',
                            'updated_at',
                        ])
                        ->orderBy('sort_order')
                        ->orderByDesc('id');
                },
            ])
            ->first();

        if ($record === null) {
            return response()->json([
                'success' => false,
                'message' => 'Category not found.',
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

        $record = Category::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($category)
            ->first();

        if ($record === null) {
            return response()->json([
                'success' => false,
                'message' => 'Category not found.',
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

        $record = $this->categoryService->updateCategory(
            $record,
            $request->validated(),
            $tenantId,
            $request->user()?->id,
        );

        $record->load([
            'children' => function ($childrenQuery) use ($tenantId): void {
                $childrenQuery
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
                        'created_at',
                        'updated_at',
                    ])
                    ->orderBy('sort_order')
                    ->orderByDesc('id');
            },
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Category updated successfully.',
            'data' => [
                'category' => new CategoryResource($record),
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

        $record = Category::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($category)
            ->first();

        if ($record === null) {
            return response()->json([
                'success' => false,
                'message' => 'Category not found.',
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

        $this->categoryService->archiveCategory(
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
}
