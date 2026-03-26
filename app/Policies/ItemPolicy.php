<?php

namespace App\Policies;

use App\Models\Item;
use App\Models\User;

class ItemPolicy
{
    public function viewAny(User $user): bool
    {
        return $this->hasTenantRole($user, ['owner', 'admin', 'staff']);
    }

    public function view(User $user, Item $item): bool
    {
        $tenantId = $this->resolveTenantId();

        if ($tenantId === null || (int) $item->tenant_id !== $tenantId) {
            return false;
        }

        return $this->hasTenantRole($user, ['owner', 'admin', 'staff'], $tenantId);
    }

    public function create(User $user): bool
    {
        return $this->hasTenantRole($user, ['owner', 'admin']);
    }

    public function update(User $user, Item $item): bool
    {
        $tenantId = $this->resolveTenantId();

        if ($tenantId === null || (int) $item->tenant_id !== $tenantId) {
            return false;
        }

        return $this->hasTenantRole($user, ['owner', 'admin'], $tenantId);
    }

    public function delete(User $user, Item $item): bool
    {
        $tenantId = $this->resolveTenantId();

        if ($tenantId === null || (int) $item->tenant_id !== $tenantId) {
            return false;
        }

        return $this->hasTenantRole($user, ['owner', 'admin'], $tenantId);
    }

    /**
     * @param array<int, string> $roles
     */
    private function hasTenantRole(User $user, array $roles, ?int $tenantId = null): bool
    {
        $tenantId = $tenantId ?? $this->resolveTenantId();

        if ($tenantId === null) {
            return false;
        }

        return $user->tenantUsers()
            ->where('tenant_id', $tenantId)
            ->where('status', 'active')
            ->whereIn('role', $roles)
            ->exists();
    }

    private function resolveTenantId(): ?int
    {
        $tenant = request()?->attributes->get('tenant');

        if (is_object($tenant) && method_exists($tenant, 'getKey')) {
            return (int) $tenant->getKey();
        }

        $tenantId = request()?->attributes->get('tenant_id');

        return is_numeric($tenantId) ? (int) $tenantId : null;
    }
}
