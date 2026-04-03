<?php

namespace App\Services\Owner;

use App\Models\Tenant;
use App\Repositories\Catalog\ItemRepository;
use App\Repositories\Catalog\OfferRepository;
use Illuminate\Support\Collection;

class OwnerDashboardService
{
    public function __construct(
        private readonly ItemRepository $itemRepository,
        private readonly OfferRepository $offerRepository,
    ) {
    }

    /**
     * Get dashboard metrics for tenant owner.
     *
     * @return array<string, mixed>
     */
    public function getDashboard(Tenant $tenant): array
    {
        $tenantId = (int) $tenant->id;

        $totalItems = $this->itemRepository->countForTenant($tenantId);
        $totalOffers = $this->offerRepository->countForTenant($tenantId);
        $followersCount = $this->countFollowersForTenant($tenantId);
        $topItems = $this->getTopItemsForDashboard($tenantId);

        return [
            'total_items' => $totalItems,
            'total_offers' => $totalOffers,
            'followers_count' => $followersCount,
            'top_items' => $topItems,
        ];
    }

    /**
     * Count followers (favorites) for tenant.
     */
    private function countFollowersForTenant(int $tenantId): int
    {
        return \App\Models\UserFavoriteStore::query()
            ->where('tenant_id', $tenantId)
            ->count();
    }

    /**
     * Get top items by cart additions for dashboard display.
     *
     * @return Collection<int, array<string, mixed>>
     */
    private function getTopItemsForDashboard(int $tenantId): Collection
    {
        $items = $this->itemRepository->getTopPublicItemsByCartAdds($tenantId, 5);

        return $items->map(fn ($item) => [
            'id' => (int) $item->id,
            'name' => (string) $item->name,
            'description' => $item->description ? (string) $item->description : null,
            'price' => $item->activePrice ? (float) $item->activePrice->base_price_amount : null,
            'final_price' => (float) $item->final_price,
            'has_offer' => (bool) $item->has_offer,
            'image_url' => $item->primaryImage?->image_url,
            'cart_adds_count' => (int) ($item->getAttribute('cart_adds_count') ?? 0),
        ]);
    }
}
