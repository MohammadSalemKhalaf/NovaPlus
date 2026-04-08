<?php

namespace App\Services\Public;

use App\Helpers\PhoneHelper;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Item;
use App\Models\Tenant;
use App\Models\User;
use App\Services\EndUser\EndUserOrderService;
use App\Repositories\Catalog\CartRepository;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Http\Exceptions\HttpResponseException;

class CartService
{
    private const DEFAULT_CURRENCY_SYMBOL = '$';

    public function __construct(
        private readonly PublicTenantAccessService $tenantAccessService,
        private readonly CartRepository $cartRepository,
        private readonly EndUserOrderService $endUserOrderService,
    )
    {
    }

    public function getOrCreateCart(string $deviceId, int $tenantId, ?User $user = null): Cart
    {
        if ($user !== null) {
            $this->syncDeviceCartToUserIfNeeded($deviceId, $tenantId, $user);
            return $this->cartRepository->firstOrCreateActiveByUserAndTenant((int) $user->id, $tenantId, $deviceId);
        }

        return $this->cartRepository->firstOrCreateActiveByDeviceAndTenant($deviceId, $tenantId);
    }

    /**
     * @return array{cart: Cart}
     */
    public function addItem(string $deviceId, int $tenantId, int $itemId, int $quantity, ?User $user = null): array
    {
        $with = [
            'tenant' => function ($query): void {
                $query->select([
                    'tenants.id',
                    'tenants.name',
                    'tenants.slug',
                    'tenants.status',
                    'tenants.whatsapp_number',
                ]);
            },
            'activePrice' => function ($query): void {
                $query
                    ->where('item_prices.pricing_status', 'active')
                    ->where('item_prices.effective_from', '<=', now())
                    ->where(function (Builder $nested): void {
                        $nested
                            ->whereNull('item_prices.effective_to')
                            ->orWhere('item_prices.effective_to', '>=', now());
                    })
                    ->select([
                        'item_prices.id',
                        'item_prices.tenant_id',
                        'item_prices.item_id',
                        'item_prices.currency_code',
                        'item_prices.base_price_amount',
                    ]);
            },
        ];

        if (Schema::hasTable('offers') && Schema::hasTable('offer_items')) {
            $with['offers'] = function ($query): void {
                $query->select([
                    'offers.id',
                    'offers.tenant_id',
                    'offers.title',
                    'offers.discount_type',
                    'offers.discount_value',
                    'offers.starts_at',
                    'offers.ends_at',
                    'offers.status',
                ]);
            };
        }

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
            ->with($with)
            ->first();

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

        if ((int) $item->tenant_id !== $tenantId) {
            $this->fail([
                'success' => false,
                'message' => 'Item belongs to a different store.',
                'data' => [],
                'meta' => (object) [],
            ], 422);
        }

        $activePrice = $item->activePrice;
        $unitPrice = (float) ($item->final_price ?? $activePrice?->base_price_amount ?? 0.0);

        return DB::transaction(function () use ($deviceId, $tenantId, $item, $quantity, $unitPrice, $user): array {
            $cart = $this->getOrCreateCart($deviceId, $tenantId, $user);

            $cartItem = $this->cartRepository->findCartItemForUpdate((int) $cart->id, (int) $item->id);

            if ($cartItem === null) {
                CartItem::query()->create([
                    'cart_id' => $cart->id,
                    'device_id' => $deviceId,
                    'user_id' => $user?->id,
                    'item_id' => $item->id,
                    'quantity' => $quantity,
                    'unit_price_snapshot' => $unitPrice,
                ]);
            } else {
                $cartItem->quantity = (int) $cartItem->quantity + $quantity;
                $cartItem->setAttribute('unit_price_snapshot', $unitPrice);
                $cartItem->save();
            }

            Log::info('Cart Debug', [
                'device_id' => $deviceId,
                'cart_id' => $cart->id,
                'tenant_id' => $tenantId,
                'item_id' => $item->id,
                'quantity_added' => $quantity,
            ]);

            return [
                'cart' => $cart->fresh(['tenant', 'items.item.activePrice', 'items.item.primaryImage']),
            ];
        });
    }

    /**
     * @return array{cart: Cart}
     */
    public function incrementItem(string $deviceId, int $itemId, ?User $user = null): array
    {
        $item = Item::query()
            ->select(['id', 'tenant_id'])
            ->whereKey($itemId)
            ->first();

        if ($item === null) {
            $this->fail([
                'success' => false,
                'message' => 'Item not available for ordering.',
                'data' => [],
                'meta' => (object) [],
            ], 404);
        }

        return $this->addItem($deviceId, (int) $item->tenant_id, $itemId, 1, $user);
    }

    public function getActiveCart(string $deviceId, int $tenantId, ?User $user = null): ?Cart
    {
        if ($user !== null) {
            $this->syncDeviceCartToUserIfNeeded($deviceId, $tenantId, $user);
            return $this->cartRepository->findActiveByUserAndTenant((int) $user->id, $tenantId);
        }

        return $this->cartRepository->findActiveByDeviceAndTenant($deviceId, $tenantId);
    }

    /**
     * @return array<string, mixed>
     */
    public function showCart(string $deviceId, int $tenantId, ?User $user = null): array
    {
        if ($user !== null) {
            $this->syncDeviceCartToUserIfNeeded($deviceId, $tenantId, $user);
        }

        $cart = $user !== null
            ? $this->cartRepository->findActiveByUserAndTenant((int) $user->id, $tenantId)
            : $this->cartRepository->findActiveByDeviceAndTenant($deviceId, $tenantId);

        if ($cart === null) {
            return [
                'id' => null,
                'device_id' => $deviceId,
                'store' => [
                    'id' => $tenantId,
                ],
                'total_items' => 0,
                'total_price' => '0.00',
                'items' => [],
                'totals' => [
                    'subtotal' => 0.0,
                ],
            ];
        }

        $items = $cart->items;
        $totalItems = (int) $items->sum(static fn ($cartItem) => (int) $cartItem->quantity);
        $totalPrice = (float) $items->sum(function ($cartItem): float {
            $price = $this->resolveEffectiveUnitPrice($cartItem);
            $quantity = (int) $cartItem->quantity;

            return $price * $quantity;
        });

        return [
            'id' => $cart->id,
            'device_id' => $deviceId,
            'store' => [
                'id' => $tenantId,
                'name' => $cart->tenant?->name,
                'slug' => $cart->tenant?->slug,
            ],
            'total_items' => $totalItems,
            'total_price' => number_format($totalPrice, 2, '.', ''),
            'items' => $items->map(function ($cartItem): array {
                $price = $this->resolveEffectiveUnitPrice($cartItem);
                $quantity = (int) $cartItem->quantity;

                return [
                    'item_id' => (int) $cartItem->item_id,
                    'item_name' => (string) ($cartItem->item?->name ?? ''),
                    'quantity' => $quantity,
                    'price' => number_format($price, 2, '.', ''),
                    'total' => number_format($price * $quantity, 2, '.', ''),
                ];
            })->values()->all(),
            'totals' => [
                'subtotal' => $totalPrice,
            ],
        ];
    }

    /**
     * @return array{message: string, whatsapp_url: string, message_preview: string, stores: array<int, array<string, string>>, cart: Cart}
     */
    public function checkoutWhatsApp(string $deviceId, int $tenantId, ?User $user = null): array
    {
        $cart = $user !== null
            ? $this->cartRepository->findActiveByUserAndTenant((int) $user->id, $tenantId)
            : $this->cartRepository->findActiveByDeviceAndTenant($deviceId, $tenantId);

        if ($cart === null) {
            $this->fail([
                'success' => false,
                'message' => 'Cart not found for this device_id',
                'data' => [],
                'meta' => (object) [],
            ], 404);
        }

        if ($cart->tenant === null) {
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

        $allItems = $cart->items;

        if ($allItems->isEmpty()) {
            $this->fail([
                'success' => false,
                'message' => 'Cart is empty.',
                'data' => [],
                'meta' => (object) [],
            ], 422);
        }

        $groupedByTenant = $allItems->groupBy(static fn ($cartItem) => (string) ($cartItem->item?->tenant_id ?? $tenantId));

        $storePayloads = [];

        foreach ($groupedByTenant as $groupTenantId => $tenantItems) {
            $groupTenantIdInt = (int) $groupTenantId;
            $tenant = $groupTenantIdInt === (int) $tenantId ? $cart->tenant : Tenant::query()->find($groupTenantIdInt);

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

            $message = $this->buildCheckoutMessageForStore($tenant, $tenantItems);
            $whatsappUrl = $this->buildEncodedWhatsAppUrl($tenant, $message);

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

        if ($user !== null) {
            $this->endUserOrderService->createFromWhatsappCheckout(
                user: $user,
                cart: $cart,
                whatsappUrl: (string) $first['whatsapp_url'],
                messagePreview: (string) $first['message_preview'],
            );
        }

        return [
            'message' => 'WhatsApp checkout payload generated successfully.',
            'whatsapp_url' => $first['whatsapp_url'],
            'message_preview' => $first['message_preview'],
            'stores' => $storePayloads,
            'cart' => $cart,
        ];
    }

    /**
     * @param \Illuminate\Support\Collection<int, CartItem> $tenantItems
     */
    private function buildCheckoutMessageForStore(Tenant $tenant, \Illuminate\Support\Collection $tenantItems): string
    {
        $orderLines = [];
        $total = 0.0;
        $hasAnyOffer = false;

        foreach ($tenantItems as $cartItem) {
            $itemName = (string) ($cartItem->item?->name ?? 'Item #'.$cartItem->item_id);
            $quantity = max(1, (int) $cartItem->quantity);

            $unitOriginal = (float) ($cartItem->item?->activePrice?->base_price_amount ?? $cartItem->unit_price_snapshot ?? 0.0);
            $unitFinal = (float) ($cartItem->item?->final_price ?? $cartItem->unit_price_snapshot ?? 0.0);
            $lineOriginal = round($unitOriginal * $quantity, 2);
            $lineFinal = round($unitFinal * $quantity, 2);

            $total += $lineFinal;

            $line = sprintf(
                '* %s x%d = %s%s',
                $itemName,
                $quantity,
                self::DEFAULT_CURRENCY_SYMBOL,
                $this->formatAmount($lineFinal),
            );

            if ($cartItem->item?->has_offer === true) {
                $hasAnyOffer = true;
            }

            if ($cartItem->item?->has_offer === true && $lineOriginal > $lineFinal) {
                $line .= sprintf(' (was %s%s)', self::DEFAULT_CURRENCY_SYMBOL, $this->formatAmount($lineOriginal));
            }

            $orderLines[] = $line;
        }

        $parts = [
            'Hello 👋',
            '',
            'Store: '.(string) $tenant->name,
            '',
            '🛒 Your Order:',
            '',
            ...$orderLines,
            '',
            '💰 Total: '.self::DEFAULT_CURRENCY_SYMBOL.$this->formatAmount($total),
        ];

        if ($hasAnyOffer) {
            $parts[] = '🔥 Offers applied!';
        }

        $parts[] = '';
        $parts[] = 'Please confirm and send your location 📍';

        return implode("\n", $parts);
    }

    private function buildEncodedWhatsAppUrl(Tenant $tenant, string $message): ?string
    {
        $normalized = PhoneHelper::normalize($tenant->whatsapp_number);

        if (!PhoneHelper::isValid($normalized)) {
            return null;
        }

        return 'https://wa.me/'.$normalized.'?text='.rawurlencode($message);
    }

    private function formatAmount(float $amount): string
    {
        return number_format($amount, 2, '.', '');
    }

    /**
     * @return array<string, mixed>
     */
    public function removeItem(string $deviceId, int $tenantId, int $itemId, ?User $user = null): array
    {
        $cart = $user !== null
            ? $this->cartRepository->findActiveByUserAndTenant((int) $user->id, $tenantId)
            : $this->cartRepository->findActiveByDeviceAndTenant($deviceId, $tenantId);

        if ($cart !== null) {
            Log::info('Remove item from cart', [
                'device_id' => $deviceId,
                'cart_id' => $cart->id,
                'tenant_id' => $tenantId,
                'item_id' => $itemId,
            ]);

            $this->cartRepository->deleteItemFromCart((int) $cart->id, $deviceId, $itemId);
        }

            return $this->showCart($deviceId, $tenantId, $user);
    }

    /**
     * @return array{cart: Cart}
     */
    public function decrementItem(string $deviceId, int $itemId, ?User $user = null): array
    {
        $item = Item::query()
            ->select(['id', 'tenant_id'])
            ->whereKey($itemId)
            ->first();

        if ($item === null) {
            $this->fail([
                'success' => false,
                'message' => 'Item not available for ordering.',
                'data' => [],
                'meta' => (object) [],
            ], 404);
        }

        return DB::transaction(function () use ($deviceId, $item, $user): array {
            $cart = $user !== null
                ? $this->cartRepository->findActiveByUserAndTenantForUpdate((int) $user->id, (int) $item->tenant_id)
                : $this->cartRepository->findActiveByDeviceAndTenantForUpdate($deviceId, (int) $item->tenant_id);

            if ($cart === null) {
                return ['cart' => $this->getOrCreateCart($deviceId, (int) $item->tenant_id, $user)];
            }

            $cartItem = $this->cartRepository->findCartItemForUpdate((int) $cart->id, (int) $item->id);

            if ($cartItem === null) {
                return ['cart' => $cart->fresh(['tenant', 'items.item.activePrice', 'items.item.primaryImage'])];
            }

            if ((int) $cartItem->quantity > 1) {
                $cartItem->quantity = (int) $cartItem->quantity - 1;
                $cartItem->save();
            } else {
                $cartItem->delete();
            }

            return ['cart' => $cart->fresh(['tenant', 'items.item.activePrice', 'items.item.primaryImage'])];
        });
    }

    public function clear(string $deviceId, int $tenantId, ?User $user = null): void
    {
        $cart = $user !== null
            ? $this->cartRepository->findActiveByUserAndTenant((int) $user->id, $tenantId)
            : $this->cartRepository->findActiveByDeviceAndTenant($deviceId, $tenantId);

        if ($cart !== null) {
            Log::info('Clear cart', [
                'device_id' => $deviceId,
                'cart_id' => $cart->id,
                'tenant_id' => $tenantId,
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
            'items' => $allItems->map(function ($cartItem): array {
                $unitPrice = $this->resolveEffectiveUnitPrice($cartItem);
                $lineTotal = $unitPrice * (int) $cartItem->quantity;

                return [
                    'id' => $cartItem->id,
                    'item_id' => $cartItem->item_id,
                    'item_name' => $cartItem->item?->name,
                    'quantity' => (int) $cartItem->quantity,
                    'unit_price_snapshot' => $unitPrice,
                    'line_total' => $lineTotal,
                ];
            })->values()->all(),
            'totals' => [
                'subtotal' => (float) $allItems->sum(function ($cartItem): float {
                    return $this->resolveEffectiveUnitPrice($cartItem) * (int) $cartItem->quantity;
                }),
            ],
        ];
    }

    private function resolveEffectiveUnitPrice($cartItem): float
    {
        if (!$cartItem instanceof CartItem) {
            return 0.0;
        }

        $item = $cartItem->item;
        $finalPrice = $item?->final_price;

        if ($finalPrice !== null) {
            return (float) $finalPrice;
        }

        return (float) ($cartItem->unit_price_snapshot ?? 0.0);
    }

    private function fail(array $payload, int $status): never
    {
        throw new HttpResponseException(response()->json($payload, $status));
    }

    private function syncDeviceCartToUserIfNeeded(string $deviceId, int $tenantId, User $user): void
    {
        $guestCart = $this->cartRepository->findActiveByDeviceAndTenant($deviceId, $tenantId);
        if ($guestCart === null) {
            return;
        }

        $guestCartUserId = $guestCart->user_id !== null ? (int) $guestCart->user_id : null;
        if ($guestCartUserId === (int) $user->id) {
            return;
        }

        $this->cartRepository->mergeDeviceCartsIntoUser($deviceId, $user);
    }
}
