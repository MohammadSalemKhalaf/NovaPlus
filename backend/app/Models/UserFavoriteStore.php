<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserFavoriteStore extends Model
{
    protected $table = 'user_favorite_stores';

    protected $fillable = [
        'user_id',
        'tenant_id',
        'notifications_optin',
    ];

    protected $casts = [
        'notifications_optin' => 'boolean',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Tenant::class, 'tenant_id');
    }
}
