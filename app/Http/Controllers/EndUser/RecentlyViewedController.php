<?php

namespace App\Http\Controllers\EndUser;

use App\Http\Controllers\Controller;
use App\Http\Requests\EndUser\RecentlyViewedIndexRequest;
use App\Models\Tenant;
use App\Services\EndUser\RecentlyViewedService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RecentlyViewedController extends Controller
{
    public function __construct(private readonly RecentlyViewedService $service)
    {
    }

    public function index(RecentlyViewedIndexRequest $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $result = $this->service->list($user, $request->validated());

        return response()->json([
            'success' => true,
            'message' => 'Recently viewed stores fetched successfully.',
            'data' => [
                'stores' => $result['stores'],
            ],
            'meta' => [
                'pagination' => $result['pagination'],
            ],
        ]);
    }

    public function store(Request $request, int $tenantId): JsonResponse
    {
        if (!Tenant::query()->whereKey($tenantId)->exists()) {
            return response()->json([
                'success' => false,
                'message' => 'Store not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        $user = $request->user('sanctum');
        $record = $this->service->record($user, $tenantId);

        return response()->json([
            'success' => true,
            'message' => 'Recently viewed store recorded successfully.',
            'data' => [
                'store' => $record,
            ],
            'meta' => (object) [],
        ], 201);
    }
}
