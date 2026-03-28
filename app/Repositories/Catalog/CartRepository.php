<?php

namespace App\Repositories\Catalog;

use App\Models\Cart;
use App\Models\CartItem;
use Illuminate\Database\Eloquent\Collection;

class CartRepository
{
    /**
     * @return array<int, string>
     */
    private function cartRelations(): array
    {
        return [
            'tenant:id,name,slug,status,whatsapp_number',
            'items:id,cart_id,device_id,item_id,quantity,unit_price_snapshot',
            'items.item:id,tenant_id,name,slug,status,visibility',
            'items.item.activePrice' => static function ($query): void {
                $query->select([
                    'item_prices.id',
                    'item_prices.tenant_id',
                    'item_prices.item_id',
                    'item_prices.currency_code',
                    'item_prices.base_price_amount',
                    'item_prices.pricing_status',
                    'item_prices.effective_from',
                    'item_prices.effective_to',
                ]);
            },
            'items.item.primaryImage' => static function ($query): void {
                $query->select([
                    'item_images.id',
                    'item_images.item_id',
                    'item_images.storage_path',
                    'item_images.is_primary',
                ]);
            },
        ];
    }

    public function findActiveByDeviceAndTenant(string $deviceId, int $tenantId): ?Cart
    {
        return Cart::query()
            ->where('device_id', $deviceId)
            ->where('tenant_id', $tenantId)
            ->where('status', 'active')
            ->with($this->cartRelations())
            ->orderByDesc('id')
            ->first();
    }

    public function firstOrCreateActiveByDeviceAndTenant(string $deviceId, int $tenantId): Cart
    {
        return Cart::query()->firstOrCreate([
            'device_id' => $deviceId,
            'tenant_id' => $tenantId,
            'status' => 'active',
        ]);
    }

    /**
     * @return Collection<int, Cart>
     */
    public function getActiveCartsByDevice(string $deviceId): Collection
    {
        return Cart::query()
            ->where('device_id', $deviceId)
            ->where('status', 'active')
            ->with($this->cartRelations())
            ->orderByDesc('id')
            ->get();
    }

    public function findCartItemForUpdate(int $cartId, int $itemId): ?CartItem
    {
        return CartItem::query()
            ->where('cart_id', $cartId)
            ->where('item_id', $itemId)
            ->lockForUpdate()
            ->first();
    }

    public function deleteItemFromCart(int $cartId, string $deviceId, int $itemId): void
    {
        CartItem::query()
            ->where('cart_id', $cartId)
            ->where('device_id', $deviceId)
            ->where('item_id', $itemId)
            ->delete();
    }

    public function clearCart(int $cartId, string $deviceId): void
    {
        CartItem::query()
            ->where('cart_id', $cartId)
            ->where('device_id', $deviceId)
            ->delete();
    }
}
