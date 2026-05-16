<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ConversationOrderDraft extends Model
{
    protected $table = 'conversation_order_drafts';

    protected $fillable = [
        'conversation_id',
        'tenant_id',
        'end_user_id',
        'items',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'conversation_id' => 'integer',
            'tenant_id' => 'integer',
            'end_user_id' => 'integer',
            'items' => 'array',
        ];
    }

    public function conversation(): BelongsTo
    {
        return $this->belongsTo(Conversation::class, 'conversation_id');
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class, 'tenant_id');
    }

    public function endUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'end_user_id');
    }
}
