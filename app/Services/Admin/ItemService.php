<?php

namespace App\Services\Admin;

use App\Models\Item;
use Illuminate\Database\Eloquent\ModelNotFoundException;

class ItemService
{
    /**
     * @param array<string, mixed> $validatedData
     */
    public function createItem(array $validatedData, int $tenantId, ?int $userId = null): Item
    {
        return Item::query()->create([
            ...$validatedData,
            'tenant_id' => $tenantId,
            'created_by_user_id' => $userId,
            'updated_by_user_id' => $userId,
        ]);
    }

    /**
     * @param array<string, mixed> $validatedData
     */
    public function updateItem(Item $item, array $validatedData, int $tenantId, ?int $userId = null): Item
    {
        if ((int) $item->tenant_id !== $tenantId) {
            throw (new ModelNotFoundException())->setModel(Item::class, [(string) $item->getKey()]);
        }

        $item->fill([
            ...$validatedData,
            'updated_by_user_id' => $userId,
        ]);
        $item->save();

        return $item;
    }

    public function archiveItem(Item $item, int $tenantId, ?int $userId = null): Item
    {
        if ((int) $item->tenant_id !== $tenantId) {
            throw (new ModelNotFoundException())->setModel(Item::class, [(string) $item->getKey()]);
        }

        $item->update([
            'status' => 'archived',
            'updated_by_user_id' => $userId,
        ]);

        return $item;
    }
}
