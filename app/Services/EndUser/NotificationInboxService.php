<?php

namespace App\Services\EndUser;

use App\Models\User;
use App\Repositories\Notifications\NotificationRepository;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

class NotificationInboxService
{
    public function __construct(private readonly NotificationRepository $notificationRepository)
    {
    }

    /**
     * @param array{per_page?: int|null} $filters
     */
    public function list(User $user, array $filters = []): LengthAwarePaginator
    {
        $perPage = max(1, min(100, (int) ($filters['per_page'] ?? 15)));

        return $this->notificationRepository->paginateForUser((int) $user->id, $perPage);
    }

    public function markAsRead(User $user, int $notificationId): bool
    {
        return $this->notificationRepository->markAsReadByNotificationId((int) $user->id, $notificationId);
    }

    public function existsForUser(User $user, int $notificationId): bool
    {
        return $this->notificationRepository->existsForUserByNotificationId((int) $user->id, $notificationId);
    }

    public function markAllAsRead(User $user): int
    {
        return $this->notificationRepository->markAllAsRead((int) $user->id);
    }
}
