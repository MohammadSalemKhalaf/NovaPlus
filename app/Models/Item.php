<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Item extends Model
{
    use HasFactory;

    /**
     * @var array<int, string>
     */
    protected $fillable = [
        'tenant_id',
        'category_id',
        'name',
        'slug',
        'short_description',
        'long_description',
        'item_type',
        'status',
        'visibility',
        'primary_image_id',
        'sort_order',
        'created_by_user_id',
        'updated_by_user_id',
    ];

    protected function casts(): array
    {
        return [
            'sort_order' => 'integer',
            'status' => 'string',
            'visibility' => 'string',
            'item_type' => 'string',
            'primary_image_id' => 'integer',
            'tenant_id' => 'integer',
            'category_id' => 'integer',
            'created_by_user_id' => 'integer',
            'updated_by_user_id' => 'integer',
        ];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class, 'tenant_id');
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class, 'category_id');
    }

    public function itemPrices(): HasMany
    {
        return $this->hasMany(ItemPrice::class, 'item_id');
    }

    public function activePrice(): HasOne
    {
        return $this->hasOne(ItemPrice::class, 'item_id')
            ->where('pricing_status', 'active')
            ->latestOfMany('id');
    }

    public function itemImages(): HasMany
    {
        return $this->hasMany(ItemImage::class, 'item_id');
    }

    public function primaryImage(): BelongsTo
    {
        return $this->belongsTo(ItemImage::class, 'primary_image_id');
    }

    public function createdBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by_user_id');
    }

    public function updatedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'updated_by_user_id');
    }
}

