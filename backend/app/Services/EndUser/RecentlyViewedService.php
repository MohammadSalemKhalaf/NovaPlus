<?php

namespace App\Services\EndUser;

use App\DTOs\EndUser\RecentlyViewedStoreDto;
use App\Models\User;
use App\Repositories\EndUser\RecentlyViewedRepository;

class RecentlyViewedService
{
    public function __construct(private readonly RecentlyViewedRepository $repository)
    {
    }

    public function record(User $user, int $tenantId): array
    {
        $view = $this->repository->recordView($user, $tenantId);

        return (new RecentlyViewedStoreDto($view))->toArray();
    }

    public function list(User $user, array $filters = []): array
    {
        $paginated = $this->repository->paginate($user, $filters);

        return [
            'stores' => $paginated->getCollection()
                ->map(fn ($view) => (new RecentlyViewedStoreDto($view))->toArray())
                ->toArray(),
            'pagination' => [
                'current_page' => $paginated->currentPage(),
                'last_page' => $paginated->lastPage(),
                'per_page' => $paginated->perPage(),
                'total' => $paginated->total(),
            ],
        ];
    }
}
