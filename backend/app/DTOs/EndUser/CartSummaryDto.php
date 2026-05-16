<?php

namespace App\DTOs\EndUser;

use App\Models\Cart;
use Illuminate\Database\Eloquent\Collection;

class CartSummaryDto
{
    /**
     * @param Collection<int, Cart> $carts
     */
    public function __construct(private readonly Collection $carts)
    {
    }

    public function toArray(): array
    {
        $items = $this->carts->flatMap(static function (Cart $cart) {
            return $cart->items->map(static function ($item) use ($cart): array {
                $lineTotal = (float) $item->unit_price_snapshot * (int) $item->quantity;

                return [
                    'cart_id' => (int) $cart->id,
                    'tenant_id' => (int) $cart->tenant_id,
                    'tenant_name' => $cart->tenant?->name,
                    'tenant_slug' => $cart->tenant?->slug,
                    'item_id' => (int) $item->item_id,
                    'item_name' => $item->item?->name,
                    'quantity' => (int) $item->quantity,
                    'unit_price_snapshot' => (float) $item->unit_price_snapshot,
                    'line_total' => $lineTotal,
                ];
            });
        })->values();

        $stores = $this->carts
            ->map(static fn (Cart $cart): array => [
                'cart_id' => (int) $cart->id,
                'tenant_id' => (int) $cart->tenant_id,
                'tenant_name' => $cart->tenant?->name,
                'tenant_slug' => $cart->tenant?->slug,
                'items_count' => (int) $cart->items->sum('quantity'),
            ])
            ->values();

        return [
            'stores' => $stores,
            'items' => $items,
            'totals' => [
                'stores_count' => (int) $stores->count(),
                'items_count' => (int) $items->sum('quantity'),
                'subtotal' => (float) $items->sum('line_total'),
            ],
        ];
    }
}
