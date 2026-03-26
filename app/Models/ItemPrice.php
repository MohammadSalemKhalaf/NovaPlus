<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ItemPrice extends Model
{
    use HasFactory;

    /**
     * @var array<int, string>
     */
    protected $fillable = [
        'tenant_id',
        'item_id',
        'currency_code',
        'base_price_amount',
        'compare_at_price_amount',
        'pricing_status',
        'effective_from',
        'effective_to',
    ];

    protected function casts(): array
    {
        return [
            'tenant_id' => 'integer',
            'item_id' => 'integer',
            'base_price_amount' => 'decimal:2',
            'compare_at_price_amount' => 'decimal:2',
            'pricing_status' => 'string',
            'effective_from' => 'datetime',
            'effective_to' => 'datetime',
        ];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class, 'tenant_id');
    }

    public function item(): BelongsTo
    {
        return $this->belongsTo(Item::class, 'item_id');
    }
}

