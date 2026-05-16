<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CartItem extends Model
{
    use HasFactory;

    /**
     * @var array<int, string>
     */
    protected $fillable = [
        'cart_id',
        'device_id',
        'user_id',
        'item_id',
        'quantity',
        'unit_price_snapshot',
    ];

    protected function casts(): array
    {
        return [
            'cart_id' => 'integer',
            'device_id' => 'string',
            'user_id' => 'integer',
            'item_id' => 'integer',
            'quantity' => 'integer',
            'unit_price_snapshot' => 'decimal:2',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function cart(): BelongsTo
    {
        return $this->belongsTo(Cart::class, 'cart_id');
    }

    public function item(): BelongsTo
    {
        return $this->belongsTo(Item::class, 'item_id');
    }
}
