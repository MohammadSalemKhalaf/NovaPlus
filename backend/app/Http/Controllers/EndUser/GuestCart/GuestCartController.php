<?php

namespace App\Http\Controllers\EndUser\GuestCart;

use App\Http\Controllers\Controller;
use App\Http\Requests\EndUser\LinkDeviceCartRequest;
use App\Services\EndUser\EndUserCartService;
use Illuminate\Http\JsonResponse;

class GuestCartController extends Controller
{
    public function __construct(private readonly EndUserCartService $service)
    {
    }

    public function preview(LinkDeviceCartRequest $request): JsonResponse
    {
        try {
            $user = $request->user('sanctum');
            $deviceId = (string) $request->validated('device_id');

            $preview = $this->service->previewMerge($user, $deviceId);

            return response()->json([
                'success' => true,
                'message' => 'Guest cart preview generated successfully.',
                'data' => [
                    'device_id' => $deviceId,
                    'preview' => $preview,
                ],
                'meta' => (object) [],
            ]);
        } catch (\Throwable $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to preview guest cart merge.',
                'data' => null,
                'meta' => [
                    'error' => $e->getMessage(),
                ],
            ], 500);
        }
    }

    public function merge(LinkDeviceCartRequest $request): JsonResponse
    {
        try {
            $user = $request->user('sanctum');
            $deviceId = (string) $request->validated('device_id');

            $preview = $this->service->previewMerge($user, $deviceId);
            $cart = $this->service->mergeDeviceCart($user, $deviceId);

            return response()->json([
                'success' => true,
                'message' => 'Guest cart merged into user cart successfully.',
                'data' => [
                    'device_id' => $deviceId,
                    'preview' => $preview,
                    'cart' => $cart,
                ],
                'meta' => (object) [],
            ]);
        } catch (\Throwable $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to merge guest cart.',
                'data' => null,
                'meta' => [
                    'error' => $e->getMessage(),
                ],
            ], 500);
        }
    }
}
