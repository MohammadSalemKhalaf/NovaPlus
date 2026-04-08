<?php

namespace App\Http\Middleware;

use App\Models\Tenant;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureTenantOwnerMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
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

        $isOwnerByTenantMembership = $user->tenantUsers()
            ->where('tenant_id', $tenant->getKey())
            ->where('status', 'active')
            ->where('role', 'owner')
            ->exists();

        $isOwnerByTenantRecord = (int) ($tenant->owner_user_id ?? 0) === (int) $user->id;

        $isOwner = $isOwnerByTenantMembership || $isOwnerByTenantRecord;

        if (!$isOwner) {
            return response()->json([
                'success' => false,
                'message' => 'Only tenant owner can access this resource.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 403);
        }

        return $next($request);
    }
}
