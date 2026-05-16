<?php

namespace App\Repositories\EndUser;

use App\Models\User;
use App\Models\UserFavoriteStore;
use Illuminate\Pagination\LengthAwarePaginator;

class FavoritesRepository
{
    /**
     * Get favorite stores for a user.
     */
    private function baseQuery(User $user)
    {
        return UserFavoriteStore::query()
            ->where('user_id', $user->id)
            ->with(['store'])
            ->orderByDesc('created_at');
    }

    /**
     * Paginate favorite stores for a user.
     */
    public function paginate(User $user, array $filters = []): LengthAwarePaginator
    {
        $query = $this->baseQuery($user);

        $perPage = isset($filters['per_page']) ? min((int) $filters['per_page'], 100) : 15;

        return $query->paginate($perPage);
    }

    /**
     * Get all favorite stores for a user.
     */
    public function getAllForUser(User $user): \Illuminate\Database\Eloquent\Collection
    {
        return $this->baseQuery($user)->get();
    }

    /**
     * Check if user has favorited a store.
     */
    public function isFavorited(User $user, int $tenantId): bool
    {
        return UserFavoriteStore::query()
            ->where('user_id', $user->id)
            ->where('tenant_id', $tenantId)
            ->exists();
    }

    /**
     * Add store to favorites.
     */
    public function favorite(User $user, int $tenantId, bool $notificationsOptIn = false): UserFavoriteStore
    {
        $favorite = UserFavoriteStore::query()->firstOrCreate([
            'user_id' => $user->id,
            'tenant_id' => $tenantId,
        ]);

        if ((bool) $favorite->notifications_optin !== $notificationsOptIn) {
            $favorite->update([
                'notifications_optin' => $notificationsOptIn,
            ]);
        }

        return $favorite;
    }

    /**
     * Update favorite settings for a store.
     */
    public function updateFavorite(User $user, int $tenantId, bool $notificationsOptIn): UserFavoriteStore
    {
        $favorite = UserFavoriteStore::query()
            ->where('user_id', $user->id)
            ->where('tenant_id', $tenantId)
            ->firstOrFail();

        $favorite->update([
            'notifications_optin' => $notificationsOptIn,
        ]);

        return $favorite->fresh();
    }

    /**
     * Remove store from favorites.
     */
    public function unfavorite(User $user, int $tenantId): bool
    {
        return UserFavoriteStore::query()
            ->where('user_id', $user->id)
            ->where('tenant_id', $tenantId)
            ->delete() > 0;
    }

    /**
     * Get favorites count for a user.
     */
    public function countForUser(User $user): int
    {
        return UserFavoriteStore::query()
            ->where('user_id', $user->id)
            ->count();
    }
}
