<?php

namespace App\Repositories\Catalog;

use App\Models\Item;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

class ItemRepository
{
    /**
     * @param array{per_page?: int, category_id?: int|null, search?: string|null, status?: string|null} $filters
     */
    public function paginateByTenant(int $tenantId, array $filters = []): LengthAwarePaginator
    {
        $perPage = max(1, min(100, (int) ($filters['per_page'] ?? 15)));
        $categoryId = (int) ($filters['category_id'] ?? 0);
        $search = isset($filters['search']) ? trim((string) $filters['search']) : '';
        $status = isset($filters['status']) ? trim((string) $filters['status']) : '';

        return Item::query()
            ->where('tenant_id', $tenantId)
            ->when($categoryId > 0, function ($query) use ($categoryId): void {
                $query->where('category_id', $categoryId);
            })
            ->when($search !== '', function ($query) use ($search): void {
                $query->where('name', 'like', '%'.$search.'%');
            })
            ->when($status !== '', function ($query) use ($status): void {
                $query->where('status', $status);
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
            ->latest('id')
            ->paginate($perPage);
    }

    public function createForTenant(array $validatedData, int $tenantId, ?int $userId = null): Item
    {
        return Item::query()->create([
            ...$validatedData,
            'tenant_id' => $tenantId,
            'created_by_user_id' => $userId,
            'updated_by_user_id' => $userId,
        ]);
    }

    public function findForTenant(int $tenantId, int $itemId): ?Item
    {
        return Item::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($itemId)
            ->first();
    }

    public function updateForTenant(Item $item, array $validatedData, int $tenantId, ?int $userId = null): Item
    {
        if ((int) $item->tenant_id !== $tenantId) {
            return $item;
        }

        $item->fill([
            ...$validatedData,
            'updated_by_user_id' => $userId,
        ]);
        $item->save();

        return $item;
    }

    public function archiveForTenant(Item $item, int $tenantId, ?int $userId = null): Item
    {
        if ((int) $item->tenant_id !== $tenantId) {
            return $item;
        }

        $item->update([
            'status' => 'archived',
            'updated_by_user_id' => $userId,
        ]);

        return $item;
    }
}