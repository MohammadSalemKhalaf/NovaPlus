<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\RevenueFilterRequest;
use App\Services\Admin\RevenueService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RevenueController extends Controller
{
    public function __construct(private readonly RevenueService $service) {}

    /**
     * Get revenue dashboard with all metrics.
     */
    public function dashboard(Request $request): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $data = $this->service->getDashboard();

        return response()->json([
            'success' => true,
            'message' => 'Revenue dashboard fetched successfully.',
            'data' => $data,
            'meta' => (object) [],
        ]);
    }

    /**
     * Get revenue by sales agent with optional filters.
     */
    public function byAgent(RevenueFilterRequest $request): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $validated = $request->validated();

        $agents = $this->service->getByAgent(
            salesAgentId: $validated['sales_agent_id'] ?? null,
            dateFrom: $validated['created_from'] ?? null,
            dateTo: $validated['created_to'] ?? null,
        );

        return response()->json([
            'success' => true,
            'message' => 'Revenue by agent fetched successfully.',
            'data' => [
                'agents' => $agents,
            ],
            'meta' => (object) [],
        ]);
    }

    /**
     * Get top performing agents by revenue.
     */
    public function topAgents(Request $request): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $limit = min((int) ($request->query('limit') ?? 10), 100);
        $agents = $this->service->getTopAgentsByRevenue($limit);

        return response()->json([
            'success' => true,
            'message' => 'Top agents by revenue fetched successfully.',
            'data' => [
                'agents' => $agents,
            ],
            'meta' => (object) [],
        ]);
    }

    /**
     * Helper to ensure super admin.
     */
    private function requireSuperAdmin(Request $request): \App\Models\User|JsonResponse
    {
        /** @var \App\Models\User|null $user */
        $user = $request->user();

        if ($user === null) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthenticated.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 401);
        }

        if (!$user->isSuperAdmin()) {
            return response()->json([
                'success' => false,
                'message' => 'You are not authorized to access this resource.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 403);
        }

        return $user;
    }
}
