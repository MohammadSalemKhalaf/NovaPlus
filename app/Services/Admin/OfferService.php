<?php

namespace App\Services\Admin;

use App\Models\Offer;
use App\Repositories\Catalog\OfferRepository;
use App\Services\Notifications\NotificationService;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

class OfferService
{
    public function __construct(
        private readonly OfferRepository $offerRepository,
        private readonly NotificationService $notificationService,
    ) {
    }

    /**
     * @param array{per_page?: int, status?: string|null, search?: string|null} $filters
     */
    public function getByTenant(int $tenantId, array $filters = []): LengthAwarePaginator
    {
        return $this->offerRepository->paginateByTenant($tenantId, $filters);
    }

    public function findForTenant(int $tenantId, int $offerId): ?Offer
    {
        return $this->offerRepository->findForTenant($tenantId, $offerId);
    }

    /**
     * @param array<string, mixed> $validatedData
     */
    public function createForTenant(array $validatedData, int $tenantId, int $userId): Offer
    {
        $offer = $this->offerRepository->createForTenant($validatedData, $tenantId, $userId);

        if (($offer->status ?? 'draft') === 'active') {
            $this->notificationService->notifyStoreFollowersForOfferPublished($offer, $userId);
        }

        return $offer;
    }

    /**
     * @param array<string, mixed> $validatedData
     */
    public function updateForTenant(Offer $offer, array $validatedData, int $tenantId): Offer
    {
        return $this->offerRepository->updateForTenant($offer, $validatedData, $tenantId);
    }

    public function deleteForTenant(Offer $offer, int $tenantId): bool
    {
        return $this->offerRepository->deleteForTenant($offer, $tenantId);
    }
}
