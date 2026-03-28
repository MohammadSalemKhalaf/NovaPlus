<?php

namespace App\Repositories\EndUser;

use App\Models\User;
use App\Models\UserStoreView;
use Illuminate\Pagination\LengthAwarePaginator;

class RecentlyViewedRepository
{
    public function recordView(User $user, int $tenantId): UserStoreView
    {
        $view = UserStoreView::query()
            ->where('user_id', $user->id)
            ->where('tenant_id', $tenantId)
            ->first();

        if ($view === null) {
            return UserStoreView::query()->create([
                'user_id' => $user->id,
                'tenant_id' => $tenantId,
                'last_viewed_at' => now(),
                'view_count' => 1,
            ]);
        }

        $view->increment('view_count');
        $view->update(['last_viewed_at' => now()]);

        return $view->fresh(['store.businessType']);
    }

    public function paginate(User $user, array $filters = []): LengthAwarePaginator
    {
        $perPage = isset($filters['per_page']) ? min((int) $filters['per_page'], 100) : 15;

        return UserStoreView::query()
            ->where('user_id', $user->id)
            ->with(['store.businessType'])
            ->orderByDesc('last_viewed_at')
            ->paginate($perPage);
    }
}
