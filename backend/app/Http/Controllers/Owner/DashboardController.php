<?php

namespace App\Http\Controllers\Owner;

use App\Http\Controllers\Controller;
use App\Models\Tenant;
use App\Models\User;
use App\Services\Owner\OwnerDashboardService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function __construct(private readonly OwnerDashboardService $dashboardService)
    {
    }

    public function index(Request $request): JsonResponse
    {
        /** @var User|null $user */
        $user = $request->user();

        if ($user === null) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthenticated.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 401);
        }

        /** @var Tenant|null $tenant */
        $tenant = $request->attributes->get('tenant');

        if ($tenant === null) {
            return response()->json([
                'success' => false,
                'message' => 'Tenant context is required.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 400);
        }

        if ((int) $tenant->owner_user_id !== (int) $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'Only owner can access this dashboard.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 403);
        }

        $data = $this->dashboardService->getDashboard($tenant);

        return response()->json([
            'success' => true,
            'message' => 'Dashboard metrics retrieved successfully.',
            'data' => $data,
            'meta' => (object) [],
        ]);
    }
}
