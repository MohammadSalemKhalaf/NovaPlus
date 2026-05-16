<?php

namespace App\Repositories\Catalog;

use App\Models\Offer;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Schema;

class OfferRepository
{
    /**
     * @return Collection<int, Offer>
     */
    public function getActiveForPublicCatalog(int $tenantId): Collection
    {
        return Offer::query()
            ->where('tenant_id', $tenantId)
            ->where('status', 'active')
            ->where(function ($query): void {
                $query->whereNull('starts_at')->orWhere('starts_at', '<=', now());
            })
            ->where(function ($query): void {
                $query->whereNull('ends_at')->orWhere('ends_at', '>=', now());
            })
            ->select([
                'id',
                'tenant_id',
                'title',
                'discount_type',
                'discount_value',
            ])
            ->orderByDesc('id')
            ->get();
    }

    /**
     * @param array{per_page?: int, status?: string|null, search?: string|null} $filters
     */
    public function paginateByTenant(int $tenantId, array $filters = []): LengthAwarePaginator
    {
        $perPage = max(1, min(100, (int) ($filters['per_page'] ?? 15)));
        $status = isset($filters['status']) ? trim((string) $filters['status']) : '';
        $search = isset($filters['search']) ? trim((string) $filters['search']) : '';

        return Offer::query()
            ->where('tenant_id', $tenantId)
            ->when(Schema::hasTable('offer_items'), function ($query): void {
                $query->with(['items:id']);
            })
            ->when($status !== '', function ($query) use ($status): void {
                $query->where('status', $status);
            })
            ->when($search !== '', function ($query) use ($search): void {
                $query->where('title', 'like', '%'.$search.'%');
            })
            ->select([
                'id',
                'tenant_id',
                'title',
                'description',
                'image',
                'discount_type',
                'discount_value',
                'starts_at',
                'ends_at',
                'status',
                'created_by',
                'created_at',
                'updated_at',
            ])
            ->latest('id')
            ->paginate($perPage);
    }

    /**
     * @param array<string, mixed> $validatedData
     */
    public function createForTenant(array $validatedData, int $tenantId, int $userId): Offer
    {
        $itemIds = Arr::get($validatedData, 'item_ids');

        $offer = Offer::query()->create([
            ...Arr::except($validatedData, ['item_ids']),
            'tenant_id' => $tenantId,
            'created_by' => $userId,
        ]);

        if (Schema::hasTable('offer_items')) {
            $offer->items()->sync($this->normalizeItemIds($itemIds));
        }

        return $offer;
    }

    public function findForTenant(int $tenantId, int $offerId): ?Offer
    {
        return Offer::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($offerId)
            ->first();
    }

    /**
     * @param array<string, mixed> $validatedData
     */
    public function updateForTenant(Offer $offer, array $validatedData, int $tenantId): Offer
    {
        if ((int) $offer->tenant_id !== $tenantId) {
            return $offer;
        }

        $itemIdsProvided = Arr::has($validatedData, 'item_ids');
        $itemIds = Arr::get($validatedData, 'item_ids');

        $offer->fill(Arr::except($validatedData, ['item_ids']));
        $offer->save();

        if ($itemIdsProvided && Schema::hasTable('offer_items')) {
            $offer->items()->sync($this->normalizeItemIds($itemIds));
        }

        return $offer;
    }

    public function deleteForTenant(Offer $offer, int $tenantId): bool
    {
        if ((int) $offer->tenant_id !== $tenantId) {
            return false;
        }

        return (bool) $offer->delete();
    }

    public function countForTenant(int $tenantId): int
    {
        return Offer::query()
            ->where('tenant_id', $tenantId)
            ->count();
    }

    /**
     * @return array<int, int>
     */
    private function normalizeItemIds(mixed $itemIds): array
    {
        if (! is_array($itemIds)) {
            return [];
        }

        return array_values(array_unique(array_filter(array_map(static function ($value): int {
            return (int) $value;
        }, $itemIds), static function (int $value): bool {
            return $value > 0;
        })));
    }
}
