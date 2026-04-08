<?php

namespace App\Http\Controllers\EndUser;

use App\Http\Controllers\Controller;
use App\Services\EndUser\EndUserOrderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class OrderController extends Controller
{
    public function __construct(private readonly EndUserOrderService $service)
    {
    }

    public function index(Request $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $perPage = max(1, min(100, (int) $request->query('per_page', 20)));
        $orders = $this->service->listUserOrders($user, $perPage);

        return response()->json([
            'success' => true,
            'message' => 'Orders fetched successfully.',
            'data' => collect($orders->items())->map(static function ($order): array {
                return [
                    'id' => (int) $order->id,
                    'status' => (string) $order->status,
                    'channel' => (string) $order->channel,
                    'tenant_id' => (int) $order->tenant_id,
                    'tenant_name' => $order->tenant?->name,
                    'items_count' => (int) $order->items->sum('quantity'),
                    'subtotal' => (float) $order->subtotal,
                    'created_at' => optional($order->created_at)?->toISOString(),
                    'items' => $order->items->map(static function ($item): array {
                        return [
                            'item_id' => $item->item_id !== null ? (int) $item->item_id : null,
                            'item_name' => (string) $item->item_name_snapshot,
                            'quantity' => (int) $item->quantity,
                            'unit_price' => (float) $item->unit_price_snapshot,
                            'line_total' => (float) $item->line_total,
                        ];
                    })->values()->all(),
                ];
            })->values()->all(),
            'meta' => [
                'pagination' => [
                    'current_page' => $orders->currentPage(),
                    'last_page' => $orders->lastPage(),
                    'per_page' => $orders->perPage(),
                    'total' => $orders->total(),
                ],
            ],
        ]);
    }
}
