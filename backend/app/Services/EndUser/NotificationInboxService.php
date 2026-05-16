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

    public function getUnreadCount(User $user): int
    {
        return $this->notificationRepository->getUnreadCount((int) $user->id);
    }

    /**
     * Get single notification for user with auto-mark option.
     * Optionally mark the notification as read after retrieval.
     *
     * @param bool $autoMarkAsRead If true, mark the notification as read after retrieval
     * @return array<string, mixed>|null
     */
    public function getForUser(User $user, int $notificationId, bool $autoMarkAsRead = false): ?array
    {
        $recipient = $this->notificationRepository->getForUser((int) $user->id, $notificationId);

        if ($recipient === null) {
            return null;
        }

        // Auto-mark as read if requested and not already read
        if ($autoMarkAsRead && !$recipient->is_read) {
            $this->markAsRead($user, $notificationId);
            // Refresh to get updated state
            $recipient = $this->notificationRepository->getForUser((int) $user->id, $notificationId);
        }

        return $recipient?->toArray();
    }
}
