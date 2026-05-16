<?php

namespace App\Services\EndUser;

use App\DTOs\EndUser\NotificationPreferencesDto;
use App\Repositories\EndUser\NotificationPreferencesRepository;
use App\Models\User;

class NotificationPreferencesService
{
    public function __construct(
        private NotificationPreferencesRepository $preferencesRepository
    ) {}

    /**
     * Get user notification preferences.
     */
    public function getPreferences(User $user): NotificationPreferencesDto
    {
        $preferences = $this->preferencesRepository->getOrCreate($user);
        return new NotificationPreferencesDto($preferences);
    }

    /**
     * Update notification preferences.
     */
    public function updatePreferences(User $user, array $data): NotificationPreferencesDto
    {
        $preferences = $this->preferencesRepository->getOrCreate($user);

        $updateData = [];

        if (isset($data['email_notifications_optin'])) {
            $updateData['email_notifications_optin'] = (bool) $data['email_notifications_optin'];
        }

        if (isset($data['whatsapp_notifications_optin'])) {
            $updateData['whatsapp_notifications_optin'] = (bool) $data['whatsapp_notifications_optin'];
        }

        if (isset($data['preferred_city'])) {
            $updateData['preferred_city'] = $data['preferred_city'];
        }

        if (isset($data['preferred_timezone'])) {
            $updateData['preferred_timezone'] = $data['preferred_timezone'];
        }

        if (isset($data['notification_categories'])) {
            $updateData['notification_categories'] = is_array($data['notification_categories'])
                ? $data['notification_categories']
                : [];
        }

        if (!empty($updateData)) {
            $preferences = $this->preferencesRepository->update($preferences, $updateData);
        }

        return new NotificationPreferencesDto($preferences);
    }

    /**
     * Enable email notifications.
     */
    public function enableEmailNotifications(User $user): NotificationPreferencesDto
    {
        $preferences = $this->preferencesRepository->getOrCreate($user);
        $preferences = $this->preferencesRepository->enableEmailNotifications($preferences);

        return new NotificationPreferencesDto($preferences);
    }

    /**
     * Disable email notifications.
     */
    public function disableEmailNotifications(User $user): NotificationPreferencesDto
    {
        $preferences = $this->preferencesRepository->getOrCreate($user);
        $preferences = $this->preferencesRepository->disableEmailNotifications($preferences);

        return new NotificationPreferencesDto($preferences);
    }
}
