<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SubscriptionCode extends Model
{
    use HasFactory;

    /**
     * @var array<int, string>
     */
    protected $fillable = [
        'code',
        'duration_months',
        'note',
        'created_by_admin_id',
        'sold_by_user_id',
        'redeemed_at',
        'redeemed_by_subscription_id',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'redeemed_at' => 'datetime',
            'status' => 'string',
        ];
    }

    public function createdByAdmin(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by_admin_id');
    }

    public function soldByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sold_by_user_id');
    }

    public function redeemedBySubscription(): BelongsTo
    {
        return $this->belongsTo(Subscription::class, 'redeemed_by_subscription_id');
    }

    /**
     * Scope to get active codes
     */
    public function scopeActive($query)
    {
        return $query->where('status', 'active')->whereNull('redeemed_at');
    }
}
