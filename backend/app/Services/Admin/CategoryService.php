<?php

namespace App\Services\Admin;

use App\Models\Category;
use App\Models\Item;
use App\Models\ItemImage;
use App\Models\ItemPrice;
use App\Repositories\Catalog\CategoryRepository;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Support\Facades\DB;

class CategoryService
{
    public function __construct(private readonly CategoryRepository $categoryRepository)
    {
    }

    /**
     * @param array{per_page?: int, status?: string|null} $filters
     */
    public function getByTenant(int $tenantId, array $filters = []): LengthAwarePaginator
    {
        return $this->categoryRepository->paginateByTenant($tenantId, $filters);
    }

    public function findForTenant(int $tenantId, int $categoryId): ?Category
    {
        return $this->categoryRepository->findForTenant($tenantId, $categoryId);
    }

    /**
     * @param array<string, mixed> $validatedData
     */
    public function createForTenant(array $validatedData, int $tenantId, ?int $userId = null): Category
    {
        unset($userId);

        return $this->categoryRepository->createForTenant($validatedData, $tenantId);
    }

    /**
     * @param array<string, mixed> $validatedData
     */
    public function updateForTenant(Category $category, array $validatedData, int $tenantId, ?int $userId = null): Category
    {
        unset($userId);

        if ((int) $category->tenant_id !== $tenantId) {
            throw (new ModelNotFoundException())->setModel(Category::class, [(string) $category->getKey()]);
        }

        return $this->categoryRepository->updateForTenant($category, $validatedData, $tenantId);
    }

    public function deleteForTenant(Category $category, int $tenantId, ?int $userId = null): Category
    {
        unset($userId);

        if ((int) $category->tenant_id !== $tenantId) {
            throw (new ModelNotFoundException())->setModel(Category::class, [(string) $category->getKey()]);
        }

        return DB::transaction(function () use ($category, $tenantId): Category {
            $itemIds = Item::query()
                ->where('tenant_id', $tenantId)
                ->where('category_id', $category->id)
                ->pluck('id');

            if ($itemIds->isNotEmpty()) {
                ItemPrice::query()
                    ->where('tenant_id', $tenantId)
                    ->whereIn('item_id', $itemIds->all())
                    ->delete();

                ItemImage::query()
                    ->where('tenant_id', $tenantId)
                    ->whereIn('item_id', $itemIds->all())
                    ->delete();

                Item::query()
                    ->where('tenant_id', $tenantId)
                    ->whereIn('id', $itemIds->all())
                    ->delete();
            }

            return $this->categoryRepository->archiveForTenant($category, $tenantId);
        });
    }

    /**
     * @param array<string, mixed> $validatedData
     */
    public function createCategory(array $validatedData, int $tenantId, ?int $userId = null): Category
    {
        return $this->createForTenant($validatedData, $tenantId, $userId);
    }

    /**
     * @param array<string, mixed> $validatedData
     */
    public function updateCategory(Category $category, array $validatedData, int $tenantId, ?int $userId = null): Category
    {
        return $this->updateForTenant($category, $validatedData, $tenantId, $userId);
    }

    public function archiveCategory(Category $category, int $tenantId, ?int $userId = null): Category
    {
        return $this->deleteForTenant($category, $tenantId, $userId);
    }
}
