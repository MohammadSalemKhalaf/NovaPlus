<?php

namespace App\Services\Notifications;

use App\Repositories\Notifications\NotificationTargetRepository;

class NotificationRecipientResolver
{
    public function __construct(private readonly NotificationTargetRepository $targetRepository)
    {
    }

    /**
     * @param array{strategy: string, tenant_id?: int, roles?: array<int, string>, user_ids?: array<int, int>} $target
     * @return array<int, int>
     */
    public function resolve(array $target): array
    {
        $strategy = $target['strategy'] ?? '';

        return match ($strategy) {
            'favorites' => $this->resolveFavorites((int) ($target['tenant_id'] ?? 0)),
            'all_users' => $this->targetRepository->allUserIds(),
            'roles' => $this->targetRepository->userIdsByRoles($target['roles'] ?? []),
            'tenant_users' => $this->targetRepository->tenantUserIds((int) ($target['tenant_id'] ?? 0)),
            'direct_users' => array_values(array_unique(array_map('intval', $target['user_ids'] ?? []))),
            default => [],
        };
    }

    /**
     * @return array<int, int>
     */
    public function resolveFavorites(int $tenantId): array
    {
        if ($tenantId <= 0) {
            return [];
        }

        return $this->targetRepository->favoriteFollowerUserIdsByTenant($tenantId);
    }
}
