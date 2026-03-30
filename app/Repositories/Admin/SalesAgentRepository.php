<?php

namespace App\Repositories\Admin;

use App\Models\Role;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;

class SalesAgentRepository
{
    /**
     * @param array{status?: string|null, created_by?: int|null, created_from?: string|null, created_to?: string|null, per_page?: int} $filters
     */
    public function paginate(array $filters = []): LengthAwarePaginator
    {
        $perPage = max(1, min(100, (int) ($filters['per_page'] ?? 15)));
        $status = isset($filters['status']) ? trim((string) $filters['status']) : null;
        $createdBy = isset($filters['created_by']) ? (int) $filters['created_by'] : null;
        $createdFrom = $filters['created_from'] ?? null;
        $createdTo = $filters['created_to'] ?? null;

        return $this->baseQuery()
            ->when(in_array($status, ['active', 'inactive'], true), function (Builder $query) use ($status): void {
                $query->where('status', $status);
            })
            ->when($createdBy !== null && $createdBy > 0, function (Builder $query) use ($createdBy): void {
                $query->where('created_by', $createdBy);
            })
            ->when($createdFrom, function (Builder $query) use ($createdFrom): void {
                $query->whereDate('created_at', '>=', $createdFrom);
            })
            ->when($createdTo, function (Builder $query) use ($createdTo): void {
                $query->whereDate('created_at', '<=', $createdTo);
            })
            ->orderByDesc('id')
            ->paginate($perPage);
    }

    public function findById(int $id): ?User
    {
        return $this->baseQuery()
            ->where('id', $id)
            ->first();
    }

    /**
     * @param array<string, mixed> $attributes
     */
    public function create(array $attributes): User
    {
        return User::query()->create($attributes);
    }

    /**
     * @param array<string, mixed> $attributes
     */
    public function update(User $user, array $attributes): User
    {
        $user->fill($attributes);
        $user->save();

        return $user;
    }

    public function delete(User $user): void
    {
        $user->delete();
    }

    public function attachRoleBySlug(User $user, string $slug): void
    {
        $roleId = Role::query()
            ->where('slug', $slug)
            ->value('id');

        if ($roleId !== null) {
            $user->roles()->syncWithoutDetaching([(int) $roleId]);
        }
    }

    public function findRoleIdBySlug(string $slug): ?int
    {
        $roleId = Role::query()
            ->where('slug', $slug)
            ->value('id');

        return $roleId !== null ? (int) $roleId : null;
    }

    private function baseQuery(): Builder
    {
        return User::query()
            ->select([
                'users.id',
                'users.name',
                'users.email',
                'users.status',
                'users.created_by',
                'users.created_at',
                'users.updated_at',
            ])
            ->with([
                'creator:id,name,email',
                'roles:id,name,slug',
            ])
            ->whereHas('roles', function (Builder $query): void {
                $query->where('slug', 'sales_agent');
            });
    }
}
