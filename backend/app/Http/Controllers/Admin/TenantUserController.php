<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\TenantUserAssignRequest;
use App\Models\Tenant;
use App\Models\TenantUser;
use Illuminate\Http\JsonResponse;

class TenantUserController extends Controller
{
    public function store(TenantUserAssignRequest $request, Tenant $tenant): JsonResponse
    {
        $actor = $request->user();

        // Allow super_admin, sales_agent, or tenant owner/admin to assign users
        $isSuperAdminOrAgent = $actor?->isSuperAdmin() || $actor?->isSalesAgent();
        
        $canAssign = $isSuperAdminOrAgent || TenantUser::query()
            ->where('tenant_id', $tenant->id)
            ->where('user_id', $actor?->id)
            ->where('status', 'active')
            ->whereIn('role', ['owner', 'admin'])
            ->exists();

        if (!$canAssign) {
            return response()->json([
                'success' => false,
                'message' => 'You are not authorized to access this resource.',
            ], 403);
        }

        $payload = $request->validated();

        $alreadyAssigned = TenantUser::query()
            ->where('tenant_id', $tenant->id)
            ->where('user_id', $payload['user_id'])
            ->exists();

        if ($alreadyAssigned) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed.',
                'errors' => [
                    'user_id' => ['This user is already assigned to the tenant.'],
                ],
            ], 422);
        }

        if ($payload['role'] === 'owner') {
            $tenantHasOwner = TenantUser::query()
                ->where('tenant_id', $tenant->id)
                ->where('role', 'owner')
                ->exists();

            if ($tenantHasOwner) {
                return response()->json([
                    'success' => false,
                    'message' => 'Validation failed.',
                    'errors' => [
                        'role' => ['This tenant already has an owner.'],
                    ],
                ], 422);
            }

            $userOwnsAnotherTenant = TenantUser::query()
                ->where('user_id', $payload['user_id'])
                ->where('role', 'owner')
                ->where('tenant_id', '!=', $tenant->id)
                ->exists();

            if ($userOwnsAnotherTenant) {
                return response()->json([
                    'success' => false,
                    'message' => 'Validation failed.',
                    'errors' => [
                        'user_id' => ['This user already owns another tenant.'],
                    ],
                ], 422);
            }
        }

        $tenantUser = TenantUser::query()->create([
            'tenant_id' => $tenant->id,
            'user_id' => $payload['user_id'],
            'role' => $payload['role'],
            'status' => 'active',
        ]);

        if ($payload['role'] === 'owner') {
            $tenant->update(['owner_user_id' => $payload['user_id']]);
        }

        return response()->json([
            'success' => true,
            'message' => 'User assigned to tenant successfully.',
            'data' => [
                'tenant_user' => [
                    'id' => $tenantUser->id,
                    'tenant_id' => $tenantUser->tenant_id,
                    'user_id' => $tenantUser->user_id,
                    'role' => $tenantUser->role,
                    'status' => $tenantUser->status,
                ],
            ],
            'meta' => (object) [],
        ], 201);
    }
}
