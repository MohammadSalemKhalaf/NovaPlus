<?php

namespace App\Repositories\EndUser;

use App\Models\NotificationPreference;
use App\Models\User;

class NotificationPreferencesRepository
{
    /**
     * Get or create notification preferences for user.
     */
    public function getOrCreate(User $user): NotificationPreference
    {
        return NotificationPreference::firstOrCreate(
            ['user_id' => $user->id],
            [
                'email_notifications_optin' => false,
                'email_verified' => false,
                'whatsapp_notifications_optin' => false,
                'preferred_timezone' => 'UTC',
            ]
        );
    }

    /**
     * Find by user ID.
     */
    public function findByUserId(int $userId): ?NotificationPreference
    {
        return NotificationPreference::query()->where('user_id', $userId)->first();
    }

    /**
     * Update notification preferences.
     */
    public function update(NotificationPreference $preferences, array $data): NotificationPreference
    {
        $preferences->update($data);
        return $preferences;
    }

    /**
     * Mark email as verified.
     */
    public function markEmailVerified(NotificationPreference $preferences): NotificationPreference
    {
        $preferences->update(['email_verified' => true]);
        return $preferences;
    }

    /**
     * Enable email notifications.
     */
    public function enableEmailNotifications(NotificationPreference $preferences): NotificationPreference
    {
        $preferences->update([
            'email_notifications_optin' => true,
            'email_verified' => true,
        ]);
        return $preferences;
    }

    /**
     * Disable email notifications.
     */
    public function disableEmailNotifications(NotificationPreference $preferences): NotificationPreference
    {
        $preferences->update(['email_notifications_optin' => false]);
        return $preferences;
    }
}
