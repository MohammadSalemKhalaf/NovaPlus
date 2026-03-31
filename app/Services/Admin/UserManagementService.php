<?php

namespace App\Services\Admin;

use App\Models\User;
use App\Repositories\Admin\UserManagementRepository;

class UserManagementService
{
    public function __construct(private readonly UserManagementRepository $repository)
    {
    }

    public function list(array $filters): array
    {
        if (!isset($filters['role']) || $filters['role'] === '') {
            $filters['role'] = 'end_user';
        }

        $paginator = $this->repository->paginate($filters);

        return [
            'users' => collect($paginator->items())
                ->map(fn (User $user): array => $this->toPayload($user))
                ->all(),
            'pagination' => [
                'current_page' => $paginator->currentPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
                'last_page' => $paginator->lastPage(),
            ],
        ];
    }

    public function show(int $id): ?array
    {
        $user = $this->repository->findById($id);

        if ($user === null || !$this->isEndUser($user)) {
            return null;
        }

        return $this->toPayload($user);
    }

    public function update(int $id, array $data): ?array
    {
        $user = $this->repository->findById($id);

        if ($user === null || !$this->isEndUser($user)) {
            return null;
        }

        if (isset($data['email']) && $this->repository->existsByEmailExcept((string) $data['email'], $user->id)) {
            throw new \InvalidArgumentException('Email is already taken.');
        }

        $updated = $this->repository->update($user, $data);

        return $this->toPayload($updated);
    }

    public function delete(int $id, int $actorId): bool
    {
        $user = $this->repository->findById($id);

        if ($user === null || !$this->isEndUser($user)) {
            return false;
        }

        if ($user->id === $actorId) {
            throw new \InvalidArgumentException('You cannot delete your own account.');
        }

        if ($user->roles->contains(fn ($role) => $role->slug === 'super_admin')) {
            throw new \InvalidArgumentException('Super admin users cannot be deleted from this endpoint.');
        }

        return $this->repository->delete($user);
    }

    private function toPayload(User $user): array
    {
        $user->loadMissing(['roles']);

        return [
            'id' => (int) $user->id,
            'name' => (string) $user->name,
            'email' => (string) $user->email,
            'status' => (string) $user->status,
            'roles' => $user->roles->pluck('slug')->values()->all(),
            'favorite_stores_count' => (int) ($user->favorite_stores_count ?? $user->favoriteStores()->count()),
            'last_login_at' => $user->last_login_at?->toIso8601String(),
            'created_at' => $user->created_at?->toIso8601String(),
        ];
    }

    private function isEndUser(User $user): bool
    {
        $user->loadMissing(['roles']);

        return $user->roles->contains(fn ($role) => $role->slug === 'end_user');
    }
}
