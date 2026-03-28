<?php

namespace App\Services\Public;

use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Item;
use App\Models\ItemPrice;
use App\Models\Tenant;
use App\Repositories\Catalog\CartRepository;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Http\Exceptions\HttpResponseException;

class CartService
{
    public function __construct(
        private readonly PublicTenantAccessService $tenantAccessService,
        private readonly CartRepository $cartRepository,
    )
    {
    }

    public function getOrCreateCart(string $deviceId, int $tenantId): Cart
    {
        return $this->cartRepository->firstOrCreateActiveByDeviceAndTenant($deviceId, $tenantId);
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
            $cart = $this->getOrCreateCart($deviceId, (int) $item->tenant_id);

            $cartItem = $this->cartRepository->findCartItemForUpdate((int) $cart->id, (int) $item->id);

            if ($cartItem === null) {
                CartItem::query()->create([
                    'cart_id' => $cart->id,
                    'device_id' => $deviceId,
                    'item_id' => $item->id,
                    'quantity' => $quantity,
                    'unit_price_snapshot' => $activePrice?->base_price_amount ?? 0,
                ]);
            } else {
                $cartItem->quantity = (int) $cartItem->quantity + $quantity;
                $cartItem->unit_price_snapshot = $activePrice?->base_price_amount ?? 0;
                $cartItem->save();
            }

            Log::info('Cart Debug', [
                'device_id' => $deviceId,
                'cart_id' => $cart->id,
                'tenant_id' => $item->tenant_id,
                'item_id' => $item->id,
                'quantity_added' => $quantity,
            ]);

            return [
                'cart' => $cart->fresh(['tenant', 'items.item.activePrice', 'items.item.primaryImage']),
            ];
        });
    }

    public function getActiveCart(string $deviceId, int $tenantId): ?Cart
    {
        return $this->cartRepository->findActiveByDeviceAndTenant($deviceId, $tenantId);
    }

    /**
     * @return array<string, mixed>
     */
    public function showCart(string $deviceId): array
    {
        $carts = $this->cartRepository->getActiveCartsByDevice($deviceId);

        if ($carts->isEmpty()) {
            return [
                'id' => null,
                'device_id' => $deviceId,
                'store' => null,
                'items' => [],
                'totals' => [
                    'subtotal' => 0.0,
                ],
            ];
        }

        return $this->formatMergedCartPayload($deviceId, $carts);
    }

    /**
     * @return array{message: string, whatsapp_url: string, message_preview: string, stores: array<int, array<string, string>>, cart: Cart}
     */
    public function checkoutWhatsApp(string $deviceId): array
    {
        $carts = $this->cartRepository->getActiveCartsByDevice($deviceId);

        if ($carts->isEmpty()) {
            $this->fail([
                'success' => false,
                'message' => 'Cart not found for this device_id',
                'data' => [],
                'meta' => (object) [],
            ], 404);
        }

        /** @var Cart $primaryCart */
        $primaryCart = $carts->first();

        if ($primaryCart->tenant === null) {
            $this->fail([
                'success' => false,
                'message' => 'Cart not found for this device_id',
                'data' => [],
                'meta' => (object) [],
            ], 404);
        }

        if (!$this->tenantAccessService->isActiveSubscribedTenant($primaryCart->tenant)) {
            $this->fail([
                'success' => false,
                'message' => 'Store is not available.',
                'data' => [],
                'meta' => (object) [],
            ], 403);
        }

        if (empty($primaryCart->tenant->whatsapp_number)) {
            $this->fail([
                'success' => false,
                'message' => 'Store WhatsApp is not configured.',
                'data' => [],
                'meta' => (object) [],
            ], 422);
        }

        $allItems = $carts->flatMap(static fn (Cart $cart) => $cart->items);

        if ($allItems->isEmpty()) {
            $this->fail([
                'success' => false,
                'message' => 'Cart is empty.',
                'data' => [],
                'meta' => (object) [],
            ], 422);
        }

        $groupedByTenant = $allItems->groupBy(static fn ($cartItem) => (string) ($cartItem->item?->tenant_id ?? $primaryCart->tenant_id));

        $storePayloads = [];

        foreach ($groupedByTenant as $tenantId => $tenantItems) {
            $tenantIdInt = (int) $tenantId;
            $tenant = $tenantIdInt === (int) $primaryCart->tenant_id ? $primaryCart->tenant : Tenant::query()->find($tenantIdInt);

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
            'cart' => $primaryCart,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function removeItem(string $deviceId, int $itemId): array
    {
        $item = Item::query()
            ->select(['id', 'tenant_id'])
            ->whereKey($itemId)
            ->first();

        if ($item !== null) {
            $cart = $this->cartRepository->findActiveByDeviceAndTenant($deviceId, (int) $item->tenant_id);

            if ($cart !== null) {
                Log::info('Remove item from cart', [
                    'device_id' => $deviceId,
                    'cart_id' => $cart->id,
                    'tenant_id' => $item->tenant_id,
                    'item_id' => $itemId,
                ]);

                $this->cartRepository->deleteItemFromCart((int) $cart->id, $deviceId, $itemId);
            }
        }

        return $this->showCart($deviceId);
    }

    public function clear(string $deviceId): void
    {
        $carts = $this->cartRepository->getActiveCartsByDevice($deviceId);

        foreach ($carts as $cart) {
            Log::info('Clear cart', [
                'device_id' => $deviceId,
                'cart_id' => $cart->id,
                'tenant_id' => $cart->tenant_id,
            ]);

            $this->cartRepository->clearCart((int) $cart->id, $deviceId);
        }
    }

    /**
     * @param Collection<int, Cart> $carts
     * @return array<string, mixed>
     */
    private function formatMergedCartPayload(string $deviceId, Collection $carts): array
    {
        /** @var Cart $primary */
        $primary = $carts->first();
        $allItems = $carts->flatMap(static fn (Cart $cart) => $cart->items)->values();
        $singleStore = $carts->pluck('tenant_id')->filter()->unique()->count() === 1;

        return [
            'id' => $primary->id,
            'device_id' => $deviceId,
            'store' => $singleStore ? [
                'id' => $primary->tenant?->id,
                'name' => $primary->tenant?->name,
                'slug' => $primary->tenant?->slug,
            ] : null,
            'items' => $allItems->map(static function ($cartItem): array {
                $lineTotal = (float) $cartItem->unit_price_snapshot * (int) $cartItem->quantity;

                return [
                    'id' => $cartItem->id,
                    'item_id' => $cartItem->item_id,
                    'item_name' => $cartItem->item?->name,
                    'quantity' => (int) $cartItem->quantity,
                    'unit_price_snapshot' => (float) $cartItem->unit_price_snapshot,
                    'line_total' => $lineTotal,
                ];
            })->values()->all(),
            'totals' => [
                'subtotal' => (float) $allItems->sum(static function ($cartItem): float {
                    return (float) $cartItem->unit_price_snapshot * (int) $cartItem->quantity;
                }),
            ],
        ];
    }

    private function fail(array $payload, int $status): never
    {
        throw new HttpResponseException(response()->json($payload, $status));
    }
}
