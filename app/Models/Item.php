<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Schema;

class Item extends Model
{
    use HasFactory;

    private ?Offer $resolvedActiveOffer = null;
    private bool $activeOfferResolved = false;

    private ?ItemPrice $resolvedActivePrice = null;
    private bool $activePriceResolved = false;

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

    public function offers(): BelongsToMany
    {
        return $this->belongsToMany(Offer::class, 'offer_items', 'item_id', 'offer_id');
    }

    public function activePrice(): HasOne
    {
        return $this->hasOne(ItemPrice::class, 'item_id')
            ->where('item_prices.pricing_status', 'active')
            ->latestOfMany('id');
    }

    public function itemImages(): HasMany
    {
        return $this->hasMany(ItemImage::class, 'item_id');
    }

    public function primaryImage(): HasOne
    {
        return $this->hasOne(ItemImage::class, 'item_id')
            ->where('item_images.is_primary', true)
            ->latestOfMany('id');
    }

    public function createdBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by_user_id');
    }

    public function updatedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'updated_by_user_id');
    }

    public function getActiveOfferAttribute(): ?Offer
    {
        if ($this->activeOfferResolved) {
            return $this->resolvedActiveOffer;
        }

        $offer = null;

        if ($this->relationLoaded('offers')) {
            /** @var Collection<int, Offer> $offers */
            $offers = $this->getRelation('offers');
            $offer = $this->resolveLatestValidOffer($offers);
        } elseif (Schema::hasTable('offer_items') && Schema::hasTable('offers')) {
                /** @var Collection<int, Offer> $offers */
                $offers = $this->offers()
                    ->where('offers.tenant_id', (int) $this->tenant_id)
                    ->where('offers.status', 'active')
                    ->where(function ($query): void {
                        $query->whereNull('offers.starts_at')->orWhere('offers.starts_at', '<=', now());
                    })
                    ->where(function ($query): void {
                        $query->whereNull('offers.ends_at')->orWhere('offers.ends_at', '>=', now());
                    })
                    ->orderByDesc('offers.id')
                    ->get([
                        'offers.id',
                        'offers.tenant_id',
                        'offers.title',
                        'offers.description',
                        'offers.discount_type',
                        'offers.discount_value',
                        'offers.starts_at',
                        'offers.ends_at',
                        'offers.status',
                        'offers.created_at',
                    ]);

                $offer = $offers->first();
        }

        $this->resolvedActiveOffer = $offer;
        $this->activeOfferResolved = true;

        return $this->resolvedActiveOffer;
    }

    public function getHasOfferAttribute(): bool
    {
        return $this->active_offer !== null;
    }

    public function getFinalPriceAttribute(): ?float
    {
        $originalPrice = $this->resolveOriginalPrice();

        if ($originalPrice === null) {
            return null;
        }

        $offer = $this->active_offer;

        if ($offer === null) {
            return $originalPrice;
        }

        $discountValue = (float) ($offer->discount_value ?? 0);

        if ($discountValue <= 0) {
            return $originalPrice;
        }

        if ($offer->discount_type === 'percentage') {
            $discounted = $originalPrice - (($originalPrice * $discountValue) / 100);

            return max(0.0, round($discounted, 2));
        }

        if ($offer->discount_type === 'fixed') {
            return max(0.0, round($originalPrice - $discountValue, 2));
        }

        return $originalPrice;
    }

    private function resolveOriginalPrice(): ?float
    {
        if ($this->activePriceResolved) {
            return $this->resolvedActivePrice !== null
                ? (float) $this->resolvedActivePrice->base_price_amount
                : null;
        }

        $price = null;

        if ($this->relationLoaded('activePrice')) {
            $loaded = $this->getRelation('activePrice');
            $price = $loaded instanceof ItemPrice ? $loaded : null;
        } else {
            $price = ItemPrice::query()
                ->where('item_prices.tenant_id', (int) $this->tenant_id)
                ->where('item_prices.item_id', (int) $this->id)
                ->where('item_prices.pricing_status', 'active')
                ->where('item_prices.effective_from', '<=', now())
                ->where(function ($query): void {
                    $query->whereNull('item_prices.effective_to')->orWhere('item_prices.effective_to', '>=', now());
                })
                ->orderByDesc('item_prices.id')
                ->first([
                    'item_prices.id',
                    'item_prices.tenant_id',
                    'item_prices.item_id',
                    'item_prices.base_price_amount',
                    'item_prices.currency_code',
                ]);
        }

        $this->resolvedActivePrice = $price;
        $this->activePriceResolved = true;

        return $this->resolvedActivePrice !== null
            ? (float) $this->resolvedActivePrice->base_price_amount
            : null;
    }

    /**
     * @param Collection<int, Offer> $offers
     */
    private function resolveLatestValidOffer(Collection $offers): ?Offer
    {
        $now = now();

        return $offers
            ->filter(function ($offer) use ($now): bool {
                if (!$offer instanceof Offer) {
                    return false;
                }

                if ((int) $offer->tenant_id !== (int) $this->tenant_id) {
                    return false;
                }

                if ($offer->status !== 'active') {
                    return false;
                }

                if ($offer->starts_at !== null && $offer->starts_at->gt($now)) {
                    return false;
                }

                if ($offer->ends_at !== null && $offer->ends_at->lt($now)) {
                    return false;
                }

                return true;
            })
            ->sortByDesc(static fn (Offer $offer): int => (int) $offer->id)
            ->first();
    }
}

