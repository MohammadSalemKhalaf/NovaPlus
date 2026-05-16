<?php

namespace App\Repositories\Catalog;

use App\Models\Category;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

class CategoryRepository
{
    /**
     * @param array{per_page?: int, status?: string|null} $filters
     */
    public function paginateByTenant(int $tenantId, array $filters = []): LengthAwarePaginator
    {
        $perPage = max(1, min(100, (int) ($filters['per_page'] ?? 15)));
        $status = isset($filters['status']) ? trim((string) $filters['status']) : '';

        return Category::query()
            ->where('tenant_id', $tenantId)
            ->when($status !== '', function ($query) use ($status): void {
                $query->where('status', $status);
            })
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
            ->latest('id')
            ->paginate($perPage);
    }

    public function createForTenant(array $validatedData, int $tenantId): Category
    {
        return Category::query()->create([
            ...$validatedData,
            'tenant_id' => $tenantId,
        ]);
    }

    public function findForTenant(int $tenantId, int $categoryId): ?Category
    {
        return Category::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($categoryId)
            ->first();
    }

    public function updateForTenant(Category $category, array $validatedData, int $tenantId): Category
    {
        if ((int) $category->tenant_id !== $tenantId) {
            return $category;
        }

        $category->fill($validatedData);
        $category->save();

        return $category;
    }

    public function archiveForTenant(Category $category, int $tenantId): Category
    {
        if ((int) $category->tenant_id !== $tenantId) {
            return $category;
        }

        $category->delete();

        return $category;
    }
}