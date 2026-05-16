<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MessageReaction extends Model
{
    protected $fillable = [
        'message_id',
        'user_id',
        'reaction_type',
    ];

    protected function casts(): array
    {
        return [
            'message_id' => 'integer',
            'user_id' => 'integer',
        ];
    }

    public function message(): BelongsTo
    {
        return $this->belongsTo(ConversationMessage::class, 'message_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public static function allowedReactions(): array
    {
        return ['like', 'love', 'laugh', 'fire'];
    }
}
