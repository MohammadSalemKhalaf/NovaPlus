<?php

namespace App\Http\Controllers\Public;

use App\Http\Controllers\Controller;
use App\Http\Requests\Public\AddCartItemRequest;
use App\Http\Requests\Public\CartCheckoutWhatsAppRequest;
use App\Http\Requests\Public\RemoveCartItemRequest;
use App\Http\Requests\Public\ShowCartRequest;
use App\Services\Public\CartService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class CartController extends Controller
{
    public function __construct(private readonly CartService $cartService)
    {
    }

    public function show(ShowCartRequest $request): JsonResponse
    {
        $deviceId = $this->getDeviceIdOrFail($request);
        $tenantId = $this->getTenantIdOrFail($request);
        $cart = $this->cartService->showCart($deviceId, $tenantId);

        if ($cart['id'] === null) {
            return response()->json([
                'success' => true,
                'message' => 'Cart is empty.',
                'data' => $cart,
                'meta' => (object) [],
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Cart fetched successfully.',
            'data' => $cart,
            'meta' => (object) [],
        ]);
    }

    public function addItem(AddCartItemRequest $request): JsonResponse
    {
        $payload = $request->validated();
        $deviceId = $this->getDeviceIdOrFail($request);
        $tenantId = $this->getTenantIdOrFail($request);

        $result = $this->cartService->addItem(
            $deviceId,
            $tenantId,
            (int) $payload['item_id'],
            (int) $payload['quantity'],
        );

        return response()->json([
            'success' => true,
            'message' => 'Item added to cart successfully.',
            'data' => [
                'cart' => $this->formatCart($result['cart']),
            ],
            'meta' => (object) [],
        ]);
    }

    public function checkoutWhatsApp(CartCheckoutWhatsAppRequest $request): JsonResponse
    {
        $deviceId = $this->getDeviceIdOrFail($request);
        $tenantId = $this->getTenantIdOrFail($request);
        $result = $this->cartService->checkoutWhatsApp($deviceId, $tenantId);

        return response()->json([
            'success' => true,
            'message' => $result['message'],
            'data' => [
                'whatsapp_url' => $result['whatsapp_url'],
                'message_preview' => $result['message_preview'],
                'stores' => $result['stores'],
            ],
            'meta' => (object) [],
        ]);
    }

    public function removeItem(RemoveCartItemRequest $request): JsonResponse
    {
        $payload = $request->validated();
        $deviceId = $this->getDeviceIdOrFail($request);
        $tenantId = $this->getTenantIdOrFail($request);
        $itemId = (int) $payload['item_id'];

        $cart = $this->cartService->removeItem($deviceId, $tenantId, $itemId);

        return response()->json([
            'success' => true,
            'message' => 'Item removed from cart successfully.',
            'data' => [
                'cart' => $cart,
            ],
            'meta' => (object) [],
        ]);
    }

    public function clear(ShowCartRequest $request): JsonResponse
    {
        $deviceId = $this->getDeviceIdOrFail($request);
        $tenantId = $this->getTenantIdOrFail($request);
        $this->cartService->clear($deviceId, $tenantId);

        return response()->json([
            'success' => true,
            'message' => 'Cart cleared successfully.',
            'data' => [],
            'meta' => (object) [],
        ]);
    }

    private function getDeviceIdOrFail(Request $request): string
    {
        $deviceId = (string) $request->header('X-Device-ID', '');

        if (!$deviceId) {
            Log::warning('Missing X-Device-ID header', [
                'endpoint' => $request->path(),
            ]);

            throw new \Illuminate\Http\Exceptions\HttpResponseException(
                response()->json([
                    'success' => false,
                    'message' => 'X-Device-ID header is required',
                    'data' => [],
                    'meta' => (object) [],
                ], 400)
            );
        }

        Log::info('Cart Request', [
            'device_id' => $deviceId,
            'tenant_id' => $request->header('X-Tenant-ID'),
            'endpoint' => $request->path(),
        ]);

        return $deviceId;
    }

    private function getTenantIdOrFail(Request $request): int
    {
        $tenantId = (int) $request->header('X-Tenant-ID', 0);

        if ($tenantId <= 0) {
            throw new \Illuminate\Http\Exceptions\HttpResponseException(
                response()->json([
                    'success' => false,
                    'message' => 'X-Tenant-ID header is required',
                    'data' => [],
                    'meta' => (object) [],
                ], 400)
            );
        }

        return $tenantId;
    }

    private function formatCart($cart): array
    {
        return [
            'id' => $cart->id,
            'device_id' => $cart->device_id,
            'store' => [
                'id' => $cart->tenant?->id,
                'name' => $cart->tenant?->name,
                'slug' => $cart->tenant?->slug,
            ],
            'items' => $cart->items->map(static function ($cartItem): array {
                $lineTotal = (float) $cartItem->unit_price_snapshot * (int) $cartItem->quantity;

                return [
                    'id' => $cartItem->id,
                    'item_id' => $cartItem->item_id,
                    'item_name' => $cartItem->item?->name,
                    'quantity' => (int) $cartItem->quantity,
                    'unit_price_snapshot' => (float) $cartItem->unit_price_snapshot,
                    'line_total' => $lineTotal,
                ];
            })->values(),
            'totals' => [
                'subtotal' => (float) $cart->items->sum(static function ($cartItem): float {
                    return (float) $cartItem->unit_price_snapshot * (int) $cartItem->quantity;
                }),
            ],
        ];
    }
}
