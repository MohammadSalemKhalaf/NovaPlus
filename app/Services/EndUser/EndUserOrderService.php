<?php

namespace App\Services\EndUser;

use App\Models\Cart;
use App\Models\CartItem;
use App\Models\EndUserOrder;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;

class EndUserOrderService
{
    public function createFromWhatsappCheckout(
        User $user,
        Cart $cart,
        string $whatsappUrl,
        string $messagePreview,
    ): EndUserOrder {
        return DB::transaction(function () use ($user, $cart, $whatsappUrl, $messagePreview): EndUserOrder {
            $cart->loadMissing(['items.item', 'items.item.activePrice', 'tenant']);

            $order = EndUserOrder::query()->create([
                'user_id' => (int) $user->id,
                'tenant_id' => (int) $cart->tenant_id,
                'cart_id' => (int) $cart->id,
                'channel' => 'whatsapp',
                'status' => 'submitted_whatsapp',
                'currency_code' => 'USD',
                'subtotal' => 0,
                'device_id' => $cart->device_id,
                'whatsapp_url' => $whatsappUrl,
                'message_preview' => $messagePreview,
                'submitted_at' => now(),
            ]);

            $subtotal = 0.0;
            foreach ($cart->items as $cartItem) {
                if (!$cartItem instanceof CartItem) {
                    continue;
                }

                $unitPrice = $this->resolveEffectiveUnitPrice($cartItem);
                $quantity = max(1, (int) $cartItem->quantity);
                $lineTotal = round($unitPrice * $quantity, 2);
                $subtotal += $lineTotal;

                $order->items()->create([
                    'item_id' => $cartItem->item_id,
                    'item_name_snapshot' => (string) ($cartItem->item?->name ?? 'Item #'.$cartItem->item_id),
                    'quantity' => $quantity,
                    'unit_price_snapshot' => $unitPrice,
                    'line_total' => $lineTotal,
                ]);
            }

            $order->subtotal = round($subtotal, 2);
            $order->save();

            return $order->fresh(['items', 'tenant']);
        });
    }

    public function listUserOrders(User $user, int $perPage = 20): LengthAwarePaginator
    {
        return EndUserOrder::query()
            ->with(['items', 'tenant:id,name,slug'])
            ->where('user_id', (int) $user->id)
            ->orderByDesc('id')
            ->paginate($perPage);
    }

    private function resolveEffectiveUnitPrice(CartItem $cartItem): float
    {
        $item = $cartItem->item;
        $finalPrice = $item?->final_price;

        if ($finalPrice !== null) {
            return (float) $finalPrice;
        }

        return (float) ($cartItem->unit_price_snapshot ?? 0.0);
    }
}
