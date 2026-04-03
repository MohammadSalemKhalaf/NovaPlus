<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Conversation extends Model
{
    protected $fillable = [
        'tenant_id',
        'end_user_id',
        'status',
        'last_message_at',
        'last_message_preview',
    ];

    protected function casts(): array
    {
        return [
            'tenant_id' => 'integer',
            'end_user_id' => 'integer',
            'last_message_at' => 'datetime',
        ];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class, 'tenant_id');
    }

    public function endUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'end_user_id');
    }

    public function messages(): HasMany
    {
        return $this->hasMany(ConversationMessage::class, 'conversation_id');
    }
}
