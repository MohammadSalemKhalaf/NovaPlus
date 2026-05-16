<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\SalesAgentCreatedOwnersReportRequest;
use App\Services\Admin\SalesAgentAnalyticsService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SalesAgentPerformanceController extends Controller
{
    public function __construct(private readonly SalesAgentAnalyticsService $service) {}

    /**
     * Get owners and stores created by sales agents.
     */
    public function createdOwnersReport(SalesAgentCreatedOwnersReportRequest $request): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $validated = $request->validated();
        $perPage = isset($validated['per_page']) ? (int) $validated['per_page'] : 15;
        $salesAgentId = isset($validated['sales_agent_id']) ? (int) $validated['sales_agent_id'] : null;

        $data = $this->service->getCreatedOwnersAndStores($salesAgentId, $perPage);

        return response()->json([
            'success' => true,
            'message' => 'Sales agents owners/stores report fetched successfully.',
            'data' => $data,
            'meta' => (object) [],
        ]);
    }

    /**
     * Get performance metrics for a specific agent.
     */
    public function show(Request $request, int $id): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $metrics = $this->service->getAgentMetrics($id);

        if (!$metrics) {
            return response()->json([
                'success' => false,
                'message' => 'Sales agent not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Sales agent metrics fetched successfully.',
            'data' => [
                'agent' => $metrics,
            ],
            'meta' => (object) [],
        ]);
    }

    /**
     * Get top performing agents.
     */
    public function topPerformers(Request $request): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $limit = min((int) ($request->query('limit') ?? 10), 100);
        $agents = $this->service->getTopPerformers($limit);

        return response()->json([
            'success' => true,
            'message' => 'Top performing agents fetched successfully.',
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
