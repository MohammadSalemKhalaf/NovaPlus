<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserStoreView extends Model
{
    protected $table = 'user_store_views';

    protected $fillable = [
        'user_id',
        'tenant_id',
        'last_viewed_at',
        'view_count',
    ];

    protected $casts = [
        'last_viewed_at' => 'datetime',
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
