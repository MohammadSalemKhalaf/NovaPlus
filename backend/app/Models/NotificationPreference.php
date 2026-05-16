<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NotificationPreference extends Model
{
    protected $table = 'notification_preferences';

    protected $fillable = [
        'user_id',
        'email_notifications_optin',
        'email_verified',
        'whatsapp_notifications_optin',
        'preferred_city',
        'preferred_timezone',
        'notification_categories',
    ];

    protected $casts = [
        'email_notifications_optin' => 'boolean',
        'email_verified' => 'boolean',
        'whatsapp_notifications_optin' => 'boolean',
        'notification_categories' => 'json',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
