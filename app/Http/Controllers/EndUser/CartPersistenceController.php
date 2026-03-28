<?php

namespace App\Http\Controllers\EndUser;

use App\Http\Controllers\Controller;
use App\Http\Requests\EndUser\LinkDeviceCartRequest;
use App\Services\EndUser\EndUserCartService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CartPersistenceController extends Controller
{
    public function __construct(private readonly EndUserCartService $service)
    {
    }

    public function show(Request $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $cart = $this->service->getUserCart($user);

        return response()->json([
            'success' => true,
            'message' => 'User cart fetched successfully.',
            'data' => $cart,
            'meta' => (object) [],
        ]);
    }

    public function previewMerge(LinkDeviceCartRequest $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $preview = $this->service->previewMerge($user, (string) $request->validated('device_id'));

        return response()->json([
            'success' => true,
            'message' => 'Cart merge preview generated successfully.',
            'data' => $preview,
            'meta' => (object) [],
        ]);
    }

    public function merge(LinkDeviceCartRequest $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $cart = $this->service->mergeDeviceCart($user, (string) $request->validated('device_id'));

        return response()->json([
            'success' => true,
            'message' => 'Device cart merged into user cart successfully.',
            'data' => $cart,
            'meta' => (object) [],
        ]);
    }
}
