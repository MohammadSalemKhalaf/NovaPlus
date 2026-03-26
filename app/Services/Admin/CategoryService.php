<?php

namespace App\Services\Admin;

use App\Models\Category;
use Illuminate\Database\Eloquent\ModelNotFoundException;

class CategoryService
{
    /**
     * @param array<string, mixed> $validatedData
     */
    public function createCategory(array $validatedData, int $tenantId, ?int $userId = null): Category
    {
        unset($userId);

        return Category::query()->create([
            ...$validatedData,
            'tenant_id' => $tenantId,
        ]);
    }

    /**
     * @param array<string, mixed> $validatedData
     */
    public function updateCategory(Category $category, array $validatedData, int $tenantId, ?int $userId = null): Category
    {
        unset($userId);

        if ((int) $category->tenant_id !== $tenantId) {
            throw (new ModelNotFoundException())->setModel(Category::class, [(string) $category->getKey()]);
        }

        $category->fill($validatedData);
        $category->save();

        return $category;
    }

    public function archiveCategory(Category $category, int $tenantId, ?int $userId = null): Category
    {
        unset($userId);

        if ((int) $category->tenant_id !== $tenantId) {
            throw (new ModelNotFoundException())->setModel(Category::class, [(string) $category->getKey()]);
        }

        $category->update([
            'status' => 'archived',
        ]);

        return $category;
    }
}
