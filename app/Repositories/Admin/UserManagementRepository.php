<?php

namespace App\Repositories\Admin;

use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\Hash;

class UserManagementRepository
{
    public function paginate(array $filters): LengthAwarePaginator
    {
        $query = User::query()
            ->with(['roles'])
            ->withCount('favoriteStores')
            ->orderByDesc('id');

        if (!empty($filters['q'])) {
            $search = trim((string) $filters['q']);
            $query->where(function (Builder $builder) use ($search): void {
                $builder->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%");
            });
        }

        if (!empty($filters['status'])) {
            $query->where('status', (string) $filters['status']);
        }

        if (!empty($filters['role'])) {
            $role = trim((string) $filters['role']);
            $query->whereHas('roles', function (Builder $builder) use ($role): void {
                $builder->where('slug', $role);
            });
        }

        $perPage = max(1, min((int) ($filters['per_page'] ?? 15), 100));

        return $query->paginate($perPage);
    }

    public function findById(int $id): ?User
    {
        return User::query()
            ->with(['roles'])
            ->withCount('favoriteStores')
            ->find($id);
    }

    public function existsByEmailExcept(string $email, int $exceptId): bool
    {
        return User::query()
            ->where('email', $email)
            ->where('id', '!=', $exceptId)
            ->exists();
    }

    public function update(User $user, array $data): User
    {
        $payload = [];

        if (array_key_exists('name', $data)) {
            $payload['name'] = $data['name'];
        }

        if (array_key_exists('email', $data)) {
            $payload['email'] = $data['email'];
        }

        if (array_key_exists('status', $data)) {
            $payload['status'] = $data['status'];
        }

        if (!empty($data['password'])) {
            $payload['password_hash'] = Hash::make((string) $data['password']);
        }

        if (!empty($payload)) {
            $user->update($payload);
        }

        return $user->fresh(['roles']);
    }

    public function delete(User $user): bool
    {
        return (bool) $user->delete();
    }
}
