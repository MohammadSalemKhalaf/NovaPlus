<?php

namespace App\Repositories\Notifications;

use App\Models\Notification;
use App\Models\NotificationRecipient;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class NotificationRepository
{
    public function findExisting(
        string $type,
        string $notifiableType,
        int $notifiableId,
        ?string $relatedType,
        ?int $relatedId
    ): ?Notification {
        return Notification::query()
            ->where('type', $type)
            ->where('notifiable_type', $notifiableType)
            ->where('notifiable_id', $notifiableId)
            ->where('related_type', $relatedType)
            ->where('related_id', $relatedId)
            ->first();
    }

    /**
     * @param array<string, mixed> $attributes
     */
    public function create(array $attributes): Notification
    {
        return Notification::query()->create($attributes);
    }

    /**
     * @param array<int, int> $userIds
     */
    public function attachRecipients(int $notificationId, array $userIds): void
    {
        if ($userIds === []) {
            return;
        }

        $now = now();
        $rows = Collection::make($userIds)
            ->unique()
            ->values()
            ->map(static fn (int $userId): array => [
                'notification_id' => $notificationId,
                'user_id' => $userId,
                'is_read' => false,
                'delivery_status' => 'delivered',
                'created_at' => $now,
                'updated_at' => $now,
            ])
            ->all();

        DB::table('notification_recipients')->insertOrIgnore($rows);
    }

    public function paginateForUser(int $userId, int $perPage = 15): LengthAwarePaginator
    {
        return NotificationRecipient::query()
            ->where('user_id', $userId)
            ->select([
                'id',
                'notification_id',
                'user_id',
                'is_read',
                'read_at',
                'delivery_status',
                'created_at',
                'updated_at',
            ])
            ->with([
                'notification' => static function ($query): void {
                    $query->select([
                        'id',
                        'type',
                        'title',
                        'body',
                        'notifiable_type',
                        'notifiable_id',
                        'related_type',
                        'related_id',
                        'channel',
                        'priority',
                        'status',
                        'created_by',
                        'created_at',
                        'updated_at',
                    ]);
                },
            ])
            ->latest('id')
            ->paginate($perPage);
    }

    public function markAsReadByNotificationId(int $userId, int $notificationId): bool
    {
        $updated = NotificationRecipient::query()
            ->where('user_id', $userId)
            ->where('notification_id', $notificationId)
            ->where('is_read', false)
            ->update([
                'is_read' => true,
                'read_at' => now(),
                'updated_at' => now(),
            ]);

        return $updated > 0;
    }

    public function existsForUserByNotificationId(int $userId, int $notificationId): bool
    {
        return NotificationRecipient::query()
            ->where('user_id', $userId)
            ->where('notification_id', $notificationId)
            ->exists();
    }

    public function markAllAsRead(int $userId): int
    {
        return NotificationRecipient::query()
            ->where('user_id', $userId)
            ->where('is_read', false)
            ->update([
                'is_read' => true,
                'read_at' => now(),
                'updated_at' => now(),
            ]);
    }

    public function getUnreadCount(int $userId): int
    {
        return NotificationRecipient::query()
            ->where('user_id', $userId)
            ->where('is_read', false)
            ->count();
    }

    /**
     * @param array<int, int> $userIds
     * @return array<int, int>
     */
    public function getUnreadCountsForUsers(array $userIds): array
    {
        $ids = array_values(array_unique(array_map('intval', $userIds)));

        if ($ids === []) {
            return [];
        }

        return NotificationRecipient::query()
            ->whereIn('user_id', $ids)
            ->where('is_read', false)
            ->groupBy('user_id')
            ->selectRaw('user_id, COUNT(*) as unread_count')
            ->pluck('unread_count', 'user_id')
            ->mapWithKeys(static fn ($count, $userId): array => [(int) $userId => (int) $count])
            ->all();
    }

    public function getForUser(int $userId, int $notificationId): ?NotificationRecipient
    {
        return NotificationRecipient::query()
            ->where('user_id', $userId)
            ->where('notification_id', $notificationId)
            ->select([
                'id',
                'notification_id',
                'user_id',
                'is_read',
                'read_at',
                'delivery_status',
                'created_at',
                'updated_at',
            ])
            ->with([
                'notification' => static function ($query): void {
                    $query->select([
                        'id',
                        'type',
                        'title',
                        'body',
                        'notifiable_type',
                        'notifiable_id',
                        'related_type',
                        'related_id',
                        'channel',
                        'priority',
                        'status',
                        'created_by',
                        'created_at',
                        'updated_at',
                    ]);
                },
            ])
            ->first();
    }
}
