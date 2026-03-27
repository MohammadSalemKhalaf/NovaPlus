<?php

namespace App\Services\Public;

use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Item;
use App\Models\ItemPrice;
use App\Models\Tenant;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Http\Exceptions\HttpResponseException;

class CartService
{
    public function __construct(private readonly PublicTenantAccessService $tenantAccessService)
    {
    }

    public function getOrCreateCart(string $deviceId, ?Tenant $tenant = null): Cart
    {
        $cart = Cart::query()
            ->where('carts.device_id', $deviceId)
            ->where('carts.status', 'active')
            ->orderByDesc('carts.id')
            ->first();

        if ($cart !== null) {
            if ($tenant !== null && (int) $cart->tenant_id !== (int) $tenant->id) {
                $this->fail([
                    'success' => false,
                    'message' => 'Cart belongs to different store',
                    'data' => [],
                    'meta' => (object) [],
                ], 422);
            }

            return $cart;
        }

        if ($tenant === null) {
            return Cart::query()->firstOrCreate([
                'device_id' => $deviceId,
            ], [
                'status' => 'active',
            ]);
        }

        return Cart::query()->firstOrCreate([
            'tenant_id' => $tenant->id,
            'device_id' => $deviceId,
            'status' => 'active',
        ]);
    }

    /**
     * @return array{cart: Cart}
     */
    public function addItem(string $deviceId, int $itemId, int $quantity): array
    {
        $item = Item::query()
            ->where('items.id', $itemId)
            ->where('items.status', 'active')
            ->where('items.visibility', 'public')
            ->where(function (Builder $query): void {
                $query
                    ->whereHas('itemPrices', function (Builder $priceQuery): void {
                        $priceQuery
                            ->where('item_prices.pricing_status', 'active')
                            ->where('item_prices.effective_from', '<=', now())
                            ->where(function (Builder $nested): void {
                                $nested
                                    ->whereNull('item_prices.effective_to')
                                    ->orWhere('item_prices.effective_to', '>=', now());
                            });
                    })
                    ->orWhereDoesntHave('itemPrices');
            })
            ->with([
                'tenant' => function ($query): void {
                    $query->select([
                        'tenants.id',
                        'tenants.name',
                        'tenants.slug',
                        'tenants.status',
                        'tenants.whatsapp_number',
                    ]);
                },
            ])
            ->first();

        $activePrice = $item !== null
            ? ItemPrice::query()
                ->where('item_prices.tenant_id', $item->tenant_id)
                ->where('item_prices.item_id', $item->id)
                ->where('item_prices.pricing_status', 'active')
                ->where('item_prices.effective_from', '<=', now())
                ->where(function (Builder $query): void {
                    $query->whereNull('item_prices.effective_to')->orWhere('item_prices.effective_to', '>=', now());
                })
                ->orderByDesc('item_prices.id')
                ->first()
            : null;

        $hasAnyPrice = $item !== null ? $item->itemPrices()->exists() : false;

        if ($item !== null) {
            Log::info('Add to cart debug', [
                'item_id' => $itemId,
                'tenant_id' => $item->tenant_id,
                'has_price' => $hasAnyPrice,
            ]);

            if (!$hasAnyPrice) {
                Log::warning('Item has no price', [
                    'item_id' => $itemId,
                ]);
            }
        }

        if ($item === null || $item->tenant === null || !$this->tenantAccessService->isActiveSubscribedTenant($item->tenant)) {
            $this->fail([
                'success' => false,
                'message' => 'Item not available for ordering.',
                'data' => [],
                'meta' => (object) [],
            ], 404);
        }

        return DB::transaction(function () use ($deviceId, $item, $quantity, $activePrice): array {
            $cart = $this->getOrCreateCart($deviceId, $item->tenant);

            if ($cart->tenant_id && (int) $cart->tenant_id !== (int) $item->tenant_id) {
                $this->fail([
                    'success' => false,
                    'message' => 'Cart belongs to different store',
                    'data' => [],
                    'meta' => (object) [],
                ], 422);
            }

            if (!$cart->tenant_id) {
                $cart->tenant_id = $item->tenant_id;
                $cart->save();
                Log::info('Cart auto-assigned tenant', [
                    'device_id' => $deviceId,
                    'tenant_id' => $item->tenant_id,
                ]);
            }

            CartItem::updateOrCreate(
                [
                    'cart_id' => $cart->id,
                    'device_id' => $deviceId,
                    'item_id' => $item->id,
                ],
                [
                    'quantity' => DB::raw('CASE WHEN quantity IS NULL THEN '.(int) $quantity.' ELSE quantity + '.(int) $quantity.' END'),
                    'unit_price_snapshot' => $activePrice?->base_price_amount ?? 0,
                ]
            );

            Log::info('Cart Debug', [
                'device_id' => $deviceId,
                'cart_id' => $cart->id,
                'item_id' => $item->id,
                'quantity_added' => $quantity,
            ]);

            return [
                'cart' => $cart->fresh(['tenant', 'items.item.activePrice', 'items.item.primaryImage']),
            ];
        });
    }

    public function getActiveCart(string $deviceId): ?Cart
    {
        return Cart::query()
            ->where('carts.device_id', $deviceId)
            ->where('carts.status', 'active')
            ->with([
                'tenant' => function ($query): void {
                    $query->select([
                        'tenants.id',
                        'tenants.name',
                        'tenants.slug',
                        'tenants.status',
                        'tenants.whatsapp_number',
                    ]);
                },
                'items' => function ($query): void {
                    $query->select([
                        'cart_items.id',
                        'cart_items.cart_id',
                        'cart_items.device_id',
                        'cart_items.item_id',
                        'cart_items.quantity',
                        'cart_items.unit_price_snapshot',
                    ]);
                },
                'items.item' => function ($query): void {
                    $query->select([
                        'items.id',
                        'items.tenant_id',
                        'items.name',
                        'items.slug',
                        'items.status',
                        'items.visibility',
                    ]);
                },
            ])
                ->orderByDesc('carts.id')
            ->first();
    }

    /**
     * @return array{message: string, whatsapp_url: string, message_preview: string, stores: array<int, array<string, string>>, cart: Cart}
     */
    public function checkoutWhatsApp(string $deviceId): array
    {
        $cart = $this->getActiveCart($deviceId);

        if ($cart === null || $cart->tenant === null) {
            $this->fail([
                'success' => false,
                'message' => 'Cart not found for this device_id',
                'data' => [],
                'meta' => (object) [],
            ], 404);
        }

        if (!$this->tenantAccessService->isActiveSubscribedTenant($cart->tenant)) {
            $this->fail([
                'success' => false,
                'message' => 'Store is not available.',
                'data' => [],
                'meta' => (object) [],
            ], 403);
        }

        if (empty($cart->tenant->whatsapp_number)) {
            $this->fail([
                'success' => false,
                'message' => 'Store WhatsApp is not configured.',
                'data' => [],
                'meta' => (object) [],
            ], 422);
        }

        if ($cart->items->isEmpty()) {
            $this->fail([
                'success' => false,
                'message' => 'Cart is empty.',
                'data' => [],
                'meta' => (object) [],
            ], 422);
        }

        $groupedByTenant = $cart->items->groupBy(static fn ($cartItem) => (string) ($cartItem->item?->tenant_id ?? $cart->tenant_id));

        $storePayloads = [];

        foreach ($groupedByTenant as $tenantId => $tenantItems) {
            $tenantIdInt = (int) $tenantId;
            $tenant = $tenantIdInt === (int) $cart->tenant_id ? $cart->tenant : Tenant::query()->find($tenantIdInt);

            if ($tenant === null || !$this->tenantAccessService->isActiveSubscribedTenant($tenant)) {
                $this->fail([
                    'success' => false,
                    'message' => 'Store is not available.',
                    'data' => [],
                    'meta' => (object) [],
                ], 403);
            }

            if (empty($tenant->whatsapp_number)) {
                $this->fail([
                    'success' => false,
                    'message' => 'Store WhatsApp is not configured.',
                    'data' => [],
                    'meta' => (object) [],
                ], 422);
            }

            $lines = [];

            foreach ($tenantItems as $cartItem) {
                $lines[] = sprintf(
                    '* %s x%d',
                    $cartItem->item?->name ?? 'Item #'.$cartItem->item_id,
                    (int) $cartItem->quantity,
                );
            }

            $message = implode("\n", [
                'طلب جديد:',
                '',
                ...$lines,
            ]);

            $whatsappUrl = $tenant->getWhatsAppUrl($message);

            if (!$whatsappUrl) {
                $this->fail([
                    'success' => false,
                    'message' => 'Store WhatsApp is not properly configured.',
                    'data' => [],
                    'meta' => (object) [],
                ], 422);
            }

            $storePayloads[] = [
                'tenant_slug' => (string) $tenant->slug,
                'whatsapp_url' => $whatsappUrl,
                'message_preview' => $message,
            ];
        }

        $first = $storePayloads[0];

        return [
            'message' => 'WhatsApp checkout payload generated successfully.',
            'whatsapp_url' => $first['whatsapp_url'],
            'message_preview' => $first['message_preview'],
            'stores' => $storePayloads,
            'cart' => $cart,
        ];
    }

    public function removeItem(string $deviceId, int $itemId): Cart
    {
        $cart = $this->getOrCreateCart($deviceId);

        Log::info('Remove item from cart', [
            'device_id' => $deviceId,
            'cart_id' => $cart->id,
            'item_id' => $itemId,
        ]);

        CartItem::query()
            ->where('cart_items.cart_id', $cart->id)
            ->where('cart_items.device_id', $deviceId)
            ->where('cart_items.item_id', $itemId)
            ->delete();

        return $cart->fresh(['tenant', 'items.item.activePrice', 'items.item.primaryImage']);
    }

    public function clear(string $deviceId): void
    {
        $cart = $this->getOrCreateCart($deviceId);

        Log::info('Clear cart', [
            'device_id' => $deviceId,
            'cart_id' => $cart->id,
        ]);

        CartItem::query()
            ->where('cart_items.cart_id', $cart->id)
            ->where('cart_items.device_id', $deviceId)
            ->delete();
    }

    private function fail(array $payload, int $status): never
    {
        throw new HttpResponseException(response()->json($payload, $status));
    }
}
