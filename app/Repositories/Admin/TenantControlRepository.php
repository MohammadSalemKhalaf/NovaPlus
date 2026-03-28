<?php

namespace App\Repositories\Admin;

use App\Models\Tenant;

class TenantControlRepository
{
    /**
     * Get base query with eager loads.
     */
    private function baseQuery()
    {
        return Tenant::query()
            ->with(['owner', 'subscriptions'])
            ->orderByDesc('created_at');
    }

    /**
     * Find tenant by ID.
     */
    public function findById(int $id): ?Tenant
    {
        return $this->baseQuery()->where('id', $id)->first();
    }

    /**
     * Activate tenant.
     */
    public function activate(Tenant $tenant): Tenant
    {
        $tenant->update(['status' => 'active']);
        return $tenant;
    }

    /**
     * Suspend tenant.
     */
    public function suspend(Tenant $tenant): Tenant
    {
        $tenant->update(['status' => 'suspended']);
        return $tenant;
    }

    /**
     * Delete tenant permanently.
     */
    public function delete(Tenant $tenant): void
    {
        $tenant->delete();
    }

    /**
     * Deactivate owner login (mark owner as inactive).
     */
    public function deactivateOwner(Tenant $tenant): void
    {
        $tenant->owner->update(['status' => 'inactive']);
    }

    /**
     * Activate owner login.
     */
    public function activateOwner(Tenant $tenant): void
    {
        $tenant->owner->update(['status' => 'active']);
    }

    /**
     * Get tenant by slug.
     */
    public function findBySlug(string $slug): ?Tenant
    {
        return $this->baseQuery()->where('slug', $slug)->first();
    }
}
