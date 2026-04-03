<?php

namespace App\Repositories\Catalog;

use App\Models\Offer;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;

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
        return Offer::query()->create([
            ...$validatedData,
            'tenant_id' => $tenantId,
            'created_by' => $userId,
        ]);
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

        $offer->fill($validatedData);
        $offer->save();

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
}
