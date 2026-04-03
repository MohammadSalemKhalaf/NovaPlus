<?php

namespace App\Repositories\Catalog;

use App\Models\Cart;
use App\Models\CartItem;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

class CartRepository
{
    /**
     * @return array<int, string>
     */
    private function cartRelations(): array
    {
        return [
            'tenant:id,name,slug,status,whatsapp_number,business_type_id',
            'items:id,cart_id,device_id,user_id,item_id,quantity,unit_price_snapshot',
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

    public function findActiveByUserAndTenant(int $userId, int $tenantId): ?Cart
    {
        return Cart::query()
            ->where('user_id', $userId)
            ->where('tenant_id', $tenantId)
            ->where('status', 'active')
            ->with($this->cartRelations())
            ->orderByDesc('id')
            ->first();
    }

    public function firstOrCreateActiveByUserAndTenant(int $userId, int $tenantId, ?string $deviceId = null): Cart
    {
        return Cart::query()->firstOrCreate([
            'user_id' => $userId,
            'tenant_id' => $tenantId,
            'status' => 'active',
        ], [
            'device_id' => $deviceId,
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

    /**
     * @return Collection<int, Cart>
     */
    public function getActiveCartsByUser(int $userId): Collection
    {
        return Cart::query()
            ->where('user_id', $userId)
            ->where('status', 'active')
            ->with($this->cartRelations())
            ->orderByDesc('id')
            ->get();
    }

    public function attachDeviceCartsToUser(string $deviceId, int $userId): void
    {
        Cart::query()
            ->where('device_id', $deviceId)
            ->where('status', 'active')
            ->update(['user_id' => $userId]);

        CartItem::query()
            ->where('device_id', $deviceId)
            ->update(['user_id' => $userId]);
    }

    public function mergeDeviceCartsIntoUser(string $deviceId, User $user): void
    {
        DB::transaction(function () use ($deviceId, $user): void {
            $deviceCarts = Cart::query()
                ->where('device_id', $deviceId)
                ->where('status', 'active')
                ->with('items')
                ->get();

            foreach ($deviceCarts as $deviceCart) {
                if (!$deviceCart instanceof Cart) {
                    continue;
                }

                $targetCart = $this->findActiveByUserAndTenant((int) $user->id, (int) $deviceCart->tenant_id);

                // No user cart for this tenant yet: promote guest cart to user cart directly.
                if ($targetCart === null) {
                    $deviceCart->update(['user_id' => (int) $user->id]);

                    CartItem::query()
                        ->where('cart_id', $deviceCart->id)
                        ->update(['user_id' => (int) $user->id]);

                    continue;
                }

                // Same physical cart already belongs to this user/tenant, no merge needed.
                if ((int) $targetCart->id === (int) $deviceCart->id) {
                    continue;
                }

                foreach ($deviceCart->items as $item) {
                    $existing = CartItem::query()
                        ->where('cart_id', $targetCart->id)
                        ->where('item_id', $item->item_id)
                        ->lockForUpdate()
                        ->first();

                    if ($existing === null) {
                        CartItem::query()->create([
                            'cart_id' => $targetCart->id,
                            'device_id' => $deviceId,
                            'user_id' => $user->id,
                            'item_id' => $item->item_id,
                            'quantity' => (int) $item->quantity,
                            'unit_price_snapshot' => $item->unit_price_snapshot,
                        ]);
                    } else {
                        $existing->quantity = (int) $existing->quantity + (int) $item->quantity;
                        $existing->unit_price_snapshot = $item->unit_price_snapshot;
                        $existing->save();
                    }
                }

                CartItem::query()->where('cart_id', $deviceCart->id)->delete();
                $deviceCart->delete();
            }
        });
    }

    public function findCartItemForUpdate(int $cartId, int $itemId): ?CartItem
    {
        return CartItem::query()
            ->where('cart_id', $cartId)
            ->where('item_id', $itemId)
            ->lockForUpdate()
            ->first();
    }

    public function findActiveByDeviceAndTenantForUpdate(string $deviceId, int $tenantId): ?Cart
    {
        return Cart::query()
            ->where('device_id', $deviceId)
            ->where('tenant_id', $tenantId)
            ->where('status', 'active')
            ->with($this->cartRelations())
            ->lockForUpdate()
            ->orderByDesc('id')
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
