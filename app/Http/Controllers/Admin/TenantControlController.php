<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\TenantControlRequest;
use App\Services\Admin\TenantControlService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TenantControlController extends Controller
{
    public function __construct(private readonly TenantControlService $service) {}

    /**
     * Get tenant details and status.
     */
    public function show(Request $request, int $id): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $tenant = $this->service->show($id);

        if (!$tenant) {
            return response()->json([
                'success' => false,
                'message' => 'Tenant not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Tenant fetched successfully.',
            'data' => [
                'tenant' => $tenant,
            ],
            'meta' => (object) [],
        ]);
    }

    /**
     * Perform control action on tenant.
     */
    public function action(TenantControlRequest $request, int $id): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $validated = $request->validated();
        $action = $validated['action'];

        $result = match ($action) {
            'activate' => $this->service->activate($id),
            'suspend' => $this->service->suspend($id),
            'delete' => $this->handleDelete($id),
            'deactivate_owner' => $this->service->deactivateOwner($id),
            'activate_owner' => $this->service->activateOwner($id),
            default => null,
        };

        if ($result === null && $action !== 'delete') {
            return response()->json([
                'success' => false,
                'message' => 'Tenant not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        if ($action === 'delete') {
            return response()->json([
                'success' => true,
                'message' => 'Tenant deleted successfully.',
                'data' => (object) [],
                'meta' => (object) [],
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => "Tenant {$action}d successfully.",
            'data' => [
                'tenant' => $result,
            ],
            'meta' => (object) [],
        ]);
    }

    /**
     * Helper for delete action.
     */
    private function handleDelete(int $id): bool
    {
        return $this->service->delete($id);
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
