<?php

namespace App\Services\EndUser;

use App\DTOs\EndUser\FavoriteStoreDto;
use App\Repositories\EndUser\FavoritesRepository;
use App\Models\User;
use Illuminate\Pagination\LengthAwarePaginator;

class FavoritesService
{
    public function __construct(
        private FavoritesRepository $favoritesRepository
    ) {}

    /**
     * Get favorite stores with pagination.
     */
    public function listFavorites(User $user, array $filters = []): LengthAwarePaginator
    {
        $favorites = $this->favoritesRepository->paginate($user, $filters);
        $favorites->setCollection(
            $favorites->getCollection()->map(
                fn ($favorite): array => (new FavoriteStoreDto($favorite))->toArray()
            )
        );

        return $favorites;
    }

    /**
     * Add store to favorites.
     */
    public function addFavorite(User $user, int $tenantId, bool $notificationsOptIn = false): FavoriteStoreDto
    {
        $favorite = $this->favoritesRepository->favorite($user, $tenantId, $notificationsOptIn);
        $favorite->loadMissing(['store']);

        return new FavoriteStoreDto($favorite);
    }

    /**
     * Update favorite store settings.
     */
    public function updateFavorite(User $user, int $tenantId, bool $notificationsOptIn): FavoriteStoreDto
    {
        $favorite = $this->favoritesRepository->updateFavorite($user, $tenantId, $notificationsOptIn);
        $favorite->loadMissing(['store']);

        return new FavoriteStoreDto($favorite);
    }

    /**
     * Remove store from favorites.
     */
    public function removeFavorite(User $user, int $tenantId): bool
    {
        return $this->favoritesRepository->unfavorite($user, $tenantId);
    }

    /**
     * Check if store is favorited.
     */
    public function isFavorited(User $user, int $tenantId): bool
    {
        return $this->favoritesRepository->isFavorited($user, $tenantId);
    }

    /**
     * Get favorite count for user.
     */
    public function getFavoriteCount(User $user): int
    {
        return $this->favoritesRepository->countForUser($user);
    }
}
