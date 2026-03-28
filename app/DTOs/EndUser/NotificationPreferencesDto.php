<?php

namespace App\DTOs\EndUser;

use App\Models\NotificationPreference;

class NotificationPreferencesDto
{
    public function __construct(private readonly NotificationPreference $preferences)
    {
    }

    public function toArray(): array
    {
        return [
            'user_id' => (int) $this->preferences->user_id,
            'email_notifications_optin' => $this->preferences->email_notifications_optin,
            'email_verified' => $this->preferences->email_verified,
            'whatsapp_notifications_optin' => $this->preferences->whatsapp_notifications_optin,
            'preferred_city' => $this->preferences->preferred_city,
            'preferred_timezone' => $this->preferences->preferred_timezone,
            'notification_categories' => (array) $this->preferences->notification_categories,
            'updated_at' => $this->preferences->updated_at?->toIso8601String(),
        ];
    }
}
