<?php

namespace App\Services\Admin;

use App\DTOs\Admin\TenantControlDto;
use App\Repositories\Admin\TenantControlRepository;

class TenantControlService
{
    public function __construct(private readonly TenantControlRepository $repository) {}

    /**
     * List tenants with filters and pagination.
     */
    public function list(array $filters = []): array
    {
        $paginated = $this->repository->paginate($filters);

        return [
            'tenants' => array_map(
                static fn ($tenant): array => (new TenantControlDto($tenant))->toArray(),
                $paginated->items(),
            ),
            'pagination' => [
                'current_page' => $paginated->currentPage(),
                'last_page' => $paginated->lastPage(),
                'per_page' => $paginated->perPage(),
                'total' => $paginated->total(),
            ],
        ];
    }

    /**
     * Get tenant details.
     */
    public function show(int $id): ?array
    {
        $tenant = $this->repository->findById($id);

        if (! $tenant) {
            return null;
        }

        return (new TenantControlDto($tenant))->toArray();
    }

    /**
     * Activate tenant.
     */
    public function activate(int $id): ?array
    {
        $tenant = $this->repository->findById($id);

        if (! $tenant) {
            return null;
        }

        $this->repository->activate($tenant);

        return (new TenantControlDto($tenant->fresh()))->toArray();
    }

    /**
     * Suspend tenant.
     */
    public function suspend(int $id): ?array
    {
        $tenant = $this->repository->findById($id);

        if (! $tenant) {
            return null;
        }

        $this->repository->suspend($tenant);

        return (new TenantControlDto($tenant->fresh()))->toArray();
    }

    /**
     * Delete tenant permanently.
     */
    public function delete(int $id): bool
    {
        $tenant = $this->repository->findById($id);

        if (! $tenant) {
            return false;
        }

        $this->repository->delete($tenant);

        return true;
    }

    /**
     * Delete tenant and its owner account in one operation.
     */
    public function deleteWithOwner(int $id): bool
    {
        $tenant = $this->repository->findById($id);

        if (! $tenant) {
            return false;
        }

        $this->repository->deleteWithOwner($tenant);

        return true;
    }

    /**
     * Deactivate owner login for a tenant.
     */
    public function deactivateOwner(int $id): ?array
    {
        $tenant = $this->repository->findById($id);

        if (! $tenant) {
            return null;
        }

        $this->repository->deactivateOwner($tenant);

        return (new TenantControlDto($tenant->fresh()))->toArray();
    }

    /**
     * Activate owner login for a tenant.
     */
    public function activateOwner(int $id): ?array
    {
        $tenant = $this->repository->findById($id);

        if (! $tenant) {
            return null;
        }

        $this->repository->activateOwner($tenant);

        return (new TenantControlDto($tenant->fresh()))->toArray();
    }
}
