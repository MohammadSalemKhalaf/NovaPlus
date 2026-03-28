<?php

namespace App\Services\Admin;

use App\DTOs\Admin\SalesAgentDto;
use App\Models\User;
use App\Repositories\Admin\SalesAgentRepository;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\Hash;

class SalesAgentService
{
    public function __construct(private readonly SalesAgentRepository $salesAgentRepository)
    {
    }

    /**
     * @param array{status?: string|null, created_by?: int|null, created_from?: string|null, created_to?: string|null, per_page?: int} $filters
     * @return array<string, mixed>
     */
    public function list(array $filters = []): array
    {
        $paginator = $this->salesAgentRepository->paginate($filters);

        return [
            'sales_agents' => array_map(
                static fn (User $user): array => (new SalesAgentDto($user))->toArray(),
                $paginator->items(),
            ),
            'pagination' => $this->pagination($paginator),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     */
    public function create(array $payload, User $createdBy): array
    {
        $salesAgent = $this->salesAgentRepository->create([
            'name' => $payload['name'],
            'email' => $payload['email'],
            'password_hash' => Hash::make((string) $payload['password']),
            'status' => $payload['status'] ?? 'active',
            'created_by' => $createdBy->id,
        ]);

        $this->salesAgentRepository->attachRoleBySlug($salesAgent, 'sales_agent');
        $this->salesAgentRepository->attachRoleBySlug($salesAgent, 'end_user');

        $fresh = $this->salesAgentRepository->findById((int) $salesAgent->id);

        return (new SalesAgentDto($fresh ?? $salesAgent->load(['creator:id,name,email', 'roles:id,name,slug'])))->toArray();
    }

    public function show(int $id): ?array
    {
        $salesAgent = $this->salesAgentRepository->findById($id);

        if ($salesAgent === null) {
            return null;
        }

        return (new SalesAgentDto($salesAgent))->toArray();
    }

    /**
     * @param array<string, mixed> $payload
     */
    public function update(int $id, array $payload): ?array
    {
        $salesAgent = $this->salesAgentRepository->findById($id);

        if ($salesAgent === null) {
            return null;
        }

        $attributes = [];

        if (array_key_exists('name', $payload)) {
            $attributes['name'] = $payload['name'];
        }

        if (array_key_exists('email', $payload)) {
            $attributes['email'] = $payload['email'];
        }

        if (array_key_exists('password', $payload)) {
            $attributes['password_hash'] = Hash::make((string) $payload['password']);
        }

        if (!empty($attributes)) {
            $salesAgent = $this->salesAgentRepository->update($salesAgent, $attributes);
        }

        $fresh = $this->salesAgentRepository->findById((int) $salesAgent->id);

        return $fresh ? (new SalesAgentDto($fresh))->toArray() : null;
    }

    public function updateStatus(int $id, string $status): ?array
    {
        $salesAgent = $this->salesAgentRepository->findById($id);

        if ($salesAgent === null) {
            return null;
        }

        $salesAgent = $this->salesAgentRepository->update($salesAgent, [
            'status' => $status,
        ]);

        $fresh = $this->salesAgentRepository->findById((int) $salesAgent->id);

        return $fresh ? (new SalesAgentDto($fresh))->toArray() : null;
    }

    public function delete(int $id): bool
    {
        $salesAgent = $this->salesAgentRepository->findById($id);

        if ($salesAgent === null) {
            return false;
        }

        $this->salesAgentRepository->delete($salesAgent);

        return true;
    }

    /**
     * @return array<string, int>
     */
    private function pagination(LengthAwarePaginator $paginator): array
    {
        return [
            'current_page' => $paginator->currentPage(),
            'last_page' => $paginator->lastPage(),
            'per_page' => $paginator->perPage(),
            'total' => $paginator->total(),
        ];
    }
}
