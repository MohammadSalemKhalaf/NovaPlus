<?php

namespace App\Services\Admin;

use App\Models\Item;
use App\Repositories\Catalog\ItemRepository;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\ModelNotFoundException;

class ItemService
{
    public function __construct(private readonly ItemRepository $itemRepository)
    {
    }

    /**
     * @param array{per_page?: int, category_id?: int|null, search?: string|null, status?: string|null} $filters
     */
    public function getByTenant(int $tenantId, array $filters = []): LengthAwarePaginator
    {
        return $this->itemRepository->paginateByTenant($tenantId, $filters);
    }

    public function findForTenant(int $tenantId, int $itemId): ?Item
    {
        return $this->itemRepository->findForTenant($tenantId, $itemId);
    }

    /**
     * @param array<string, mixed> $validatedData
     */
    public function createForTenant(array $validatedData, int $tenantId, ?int $userId = null): Item
    {
        return $this->itemRepository->createForTenant($validatedData, $tenantId, $userId);
    }

    /**
     * @param array<string, mixed> $validatedData
     */
    public function updateForTenant(Item $item, array $validatedData, int $tenantId, ?int $userId = null): Item
    {
        if ((int) $item->tenant_id !== $tenantId) {
            throw (new ModelNotFoundException())->setModel(Item::class, [(string) $item->getKey()]);
        }

        return $this->itemRepository->updateForTenant($item, $validatedData, $tenantId, $userId);
    }

    public function deleteForTenant(Item $item, int $tenantId, ?int $userId = null): Item
    {
        if ((int) $item->tenant_id !== $tenantId) {
            throw (new ModelNotFoundException())->setModel(Item::class, [(string) $item->getKey()]);
        }

        return $this->itemRepository->archiveForTenant($item, $tenantId, $userId);
    }

    /**
     * @param array<string, mixed> $validatedData
     */
    public function createItem(array $validatedData, int $tenantId, ?int $userId = null): Item
    {
        return $this->createForTenant($validatedData, $tenantId, $userId);
    }

    /**
     * @param array<string, mixed> $validatedData
     */
    public function updateItem(Item $item, array $validatedData, int $tenantId, ?int $userId = null): Item
    {
        return $this->updateForTenant($item, $validatedData, $tenantId, $userId);
    }

    public function archiveItem(Item $item, int $tenantId, ?int $userId = null): Item
    {
        return $this->deleteForTenant($item, $tenantId, $userId);
    }
}
