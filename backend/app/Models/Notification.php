<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Notification extends Model
{
    protected $fillable = [
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
    ];

    protected function casts(): array
    {
        return [
            'notifiable_id' => 'integer',
            'related_id' => 'integer',
            'created_by' => 'integer',
        ];
    }

    public function recipients(): HasMany
    {
        return $this->hasMany(NotificationRecipient::class, 'notification_id');
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
