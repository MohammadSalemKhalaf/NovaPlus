<?php

namespace App\Repositories\Notifications;

use App\Models\UserFavoriteStore;
use Illuminate\Support\Facades\DB;

class NotificationTargetRepository
{
    /**
     * @return array<int, int>
     */
    public function favoriteFollowerUserIdsByTenant(int $tenantId): array
    {
        return UserFavoriteStore::query()
            ->where('tenant_id', $tenantId)
            ->distinct()
            ->orderBy('user_id')
            ->pluck('user_id')
            ->map(static fn ($id): int => (int) $id)
            ->all();
    }

    /**
     * @return array<int, int>
     */
    public function allUserIds(): array
    {
        return DB::table('users')->orderBy('id')->pluck('id')->map(static fn ($id): int => (int) $id)->all();
    }

    /**
     * @param array<int, string> $roles
     * @return array<int, int>
     */
    public function userIdsByRoles(array $roles): array
    {
        if ($roles === []) {
            return [];
        }

        return DB::table('user_roles')
            ->join('roles', 'roles.id', '=', 'user_roles.role_id')
            ->whereIn('roles.slug', $roles)
            ->distinct()
            ->orderBy('user_roles.user_id')
            ->pluck('user_roles.user_id')
            ->map(static fn ($id): int => (int) $id)
            ->all();
    }

    /**
     * @return array<int, int>
     */
    public function tenantUserIds(int $tenantId): array
    {
        return DB::table('tenant_users')
            ->where('tenant_id', $tenantId)
            ->where('status', 'active')
            ->distinct()
            ->orderBy('user_id')
            ->pluck('user_id')
            ->map(static fn ($id): int => (int) $id)
            ->all();
    }
}
