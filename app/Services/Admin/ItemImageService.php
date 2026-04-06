<?php

namespace App\Services\Admin;

use App\Models\Item;
use App\Models\ItemImage;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class ItemImageService
{
    /**
     * @return Collection<int, ItemImage>
     */
    public function listImages(int $tenantId, int $itemId): Collection
    {
        $this->resolveItem($tenantId, $itemId);

        return ItemImage::query()
            ->where('tenant_id', $tenantId)
            ->where('item_id', $itemId)
            ->orderBy('sort_order')
            ->orderByDesc('id')
            ->get();
    }

    /**
     * @param array<string, mixed> $validatedData
     */
    public function uploadImage(int $tenantId, int $itemId, UploadedFile $file, array $validatedData): ItemImage
    {
        $item = $this->resolveItem($tenantId, $itemId);

        return DB::transaction(function () use ($tenantId, $itemId, $item, $file, $validatedData): ItemImage {
            $path = Storage::disk('public')->putFile("item-images/{$tenantId}/{$itemId}", $file);

            $nextSortOrder = array_key_exists('sort_order', $validatedData)
                ? (int) $validatedData['sort_order']
                : (int) (ItemImage::query()
                    ->where('tenant_id', $tenantId)
                    ->where('item_id', $itemId)
                    ->max('sort_order') ?? 0) + 1;

            $isPrimary = (bool) ($validatedData['is_primary'] ?? false);

            $hasPrimary = ItemImage::query()
                ->where('tenant_id', $tenantId)
                ->where('item_id', $itemId)
                ->where('is_primary', true)
                ->lockForUpdate()
                ->exists();

            if (!$hasPrimary) {
                $isPrimary = true;
            }

            if ($isPrimary) {
                ItemImage::query()
                    ->where('tenant_id', $tenantId)
                    ->where('item_id', $itemId)
                    ->update(['is_primary' => false]);
            }

            $image = ItemImage::query()->create([
                'tenant_id' => $tenantId,
                'item_id' => $itemId,
                'storage_path' => $path,
                'alt_text' => $validatedData['alt_text'] ?? null,
                'sort_order' => $nextSortOrder,
                'is_primary' => $isPrimary,
            ]);

            if ($isPrimary) {
                $item->update([
                    'primary_image_id' => $image->id,
                ]);
            } elseif ($item->primary_image_id === null) {
                $item->update([
                    'primary_image_id' => $image->id,
                ]);

                $image->update(['is_primary' => true]);
            }

            return $image->fresh();
        });
    }

    public function setPrimaryImage(int $tenantId, int $itemId, int $imageId): ItemImage
    {
        $item = $this->resolveItem($tenantId, $itemId);

        return DB::transaction(function () use ($tenantId, $itemId, $imageId, $item): ItemImage {
            $image = ItemImage::query()
                ->where('tenant_id', $tenantId)
                ->where('item_id', $itemId)
                ->whereKey($imageId)
                ->lockForUpdate()
                ->first();

            if ($image === null) {
                throw (new ModelNotFoundException())->setModel(ItemImage::class, [(string) $imageId]);
            }

            ItemImage::query()
                ->where('tenant_id', $tenantId)
                ->where('item_id', $itemId)
                ->update(['is_primary' => false]);

            $image->update(['is_primary' => true]);

            $item->update([
                'primary_image_id' => $image->id,
            ]);

            return $image->fresh();
        });
    }

    public function deleteImage(int $tenantId, int $itemId, int $imageId): void
    {
        $item = $this->resolveItem($tenantId, $itemId);

        DB::transaction(function () use ($tenantId, $itemId, $imageId, $item): void {
            $image = ItemImage::query()
                ->where('tenant_id', $tenantId)
                ->where('item_id', $itemId)
                ->whereKey($imageId)
                ->lockForUpdate()
                ->first();

            if ($image === null) {
                throw (new ModelNotFoundException())->setModel(ItemImage::class, [(string) $imageId]);
            }

            $wasPrimary = (bool) $image->is_primary || (int) $item->primary_image_id === (int) $image->id;
            $path = $image->storage_path;

            $image->delete();

            if ($wasPrimary) {
                $replacement = ItemImage::query()
                    ->where('tenant_id', $tenantId)
                    ->where('item_id', $itemId)
                    ->orderBy('sort_order')
                    ->orderByDesc('id')
                    ->lockForUpdate()
                    ->first();

                if ($replacement !== null) {
                    ItemImage::query()
                        ->where('tenant_id', $tenantId)
                        ->where('item_id', $itemId)
                        ->update(['is_primary' => false]);

                    $replacement->update(['is_primary' => true]);

                    $item->update([
                        'primary_image_id' => $replacement->id,
                    ]);
                } else {
                    $item->update([
                        'primary_image_id' => null,
                    ]);
                }
            }

            if (is_string($path) && $path !== '') {
                Storage::disk('public')->delete($path);
            }
        });
    }

    private function resolveItem(int $tenantId, int $itemId): Item
    {
        $item = Item::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($itemId)
            ->first();

        if ($item === null) {
            throw (new ModelNotFoundException())->setModel(Item::class, [(string) $itemId]);
        }

        return $item;
    }
}
