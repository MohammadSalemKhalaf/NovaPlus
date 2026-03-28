<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\SalesAgentListRequest;
use App\Http\Requests\Admin\SalesAgentStatusRequest;
use App\Http\Requests\Admin\SalesAgentStoreRequest;
use App\Http\Requests\Admin\SalesAgentUpdateRequest;
use App\Models\User;
use App\Services\Admin\SalesAgentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SalesAgentController extends Controller
{
    public function __construct(private readonly SalesAgentService $salesAgentService)
    {
    }

    public function store(SalesAgentStoreRequest $request): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $salesAgent = $this->salesAgentService->create($request->validated(), $actor);

        return response()->json([
            'success' => true,
            'message' => 'Sales agent created successfully.',
            'data' => [
                'sales_agent' => $salesAgent,
            ],
            'meta' => (object) [],
        ], 201);
    }

    public function index(SalesAgentListRequest $request): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $result = $this->salesAgentService->list($request->validated());

        return response()->json([
            'success' => true,
            'message' => 'Sales agents fetched successfully.',
            'data' => [
                'sales_agents' => $result['sales_agents'],
            ],
            'meta' => [
                'pagination' => $result['pagination'],
            ],
        ]);
    }

    public function show(Request $request, int $sales_agent): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $salesAgent = $this->salesAgentService->show($sales_agent);

        if ($salesAgent === null) {
            return response()->json([
                'success' => false,
                'message' => 'Sales agent not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Sales agent fetched successfully.',
            'data' => [
                'sales_agent' => $salesAgent,
            ],
            'meta' => (object) [],
        ]);
    }

    public function update(SalesAgentUpdateRequest $request, int $sales_agent): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $salesAgent = $this->salesAgentService->update($sales_agent, $request->validated());

        if ($salesAgent === null) {
            return response()->json([
                'success' => false,
                'message' => 'Sales agent not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Sales agent updated successfully.',
            'data' => [
                'sales_agent' => $salesAgent,
            ],
            'meta' => (object) [],
        ]);
    }

    public function updateStatus(SalesAgentStatusRequest $request, int $sales_agent): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $salesAgent = $this->salesAgentService->updateStatus($sales_agent, (string) $request->validated('status'));

        if ($salesAgent === null) {
            return response()->json([
                'success' => false,
                'message' => 'Sales agent not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Sales agent status updated successfully.',
            'data' => [
                'sales_agent' => $salesAgent,
            ],
            'meta' => (object) [],
        ]);
    }

    public function destroy(Request $request, int $sales_agent): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $deleted = $this->salesAgentService->delete($sales_agent);

        if (!$deleted) {
            return response()->json([
                'success' => false,
                'message' => 'Sales agent not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Sales agent deleted successfully.',
            'data' => [
                'deleted' => true,
                'id' => $sales_agent,
            ],
            'meta' => (object) [],
        ]);
    }

    /**
     * @return User|JsonResponse
     */
    private function requireSuperAdmin(Request $request): User|JsonResponse
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
