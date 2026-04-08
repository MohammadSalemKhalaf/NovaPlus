<?php

namespace App\Http\Middleware;

use App\Models\Subscription;
use App\Models\Tenant;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureTenantAccessMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user === null) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthenticated.',
            ], 401);
        }

        if ($user->status !== 'active') {
            return response()->json([
                'success' => false,
                'message' => 'Tenant subscription inactive or expired',
            ], 403);
        }

        /** @var Tenant|null $tenant */
        $tenant = $request->attributes->get('tenant');

        if ($tenant === null) {
            return response()->json([
                'success' => false,
                'message' => 'Tenant context is required.',
            ], 400);
        }

        // Allow access if user is a tenant member OR is the tenant owner OR is a sales_agent.
        $isSalesAgent = $user->isSalesAgent();
        $isTenantOwner = (int) ($tenant->owner_user_id ?? 0) === (int) $user->id;
        
        $hasAccess = $isSalesAgent || $isTenantOwner || $user->tenantUsers()
            ->where('tenant_id', $tenant->getKey())
            ->where('status', 'active')
            ->exists();

        if (!$hasAccess) {
            return response()->json([
                'success' => false,
                'message' => 'You are not authorized to access this resource.',
            ], 403);
        }

        $tenantIsActive = $tenant->status === 'active';

        $hasActiveSubscription = Subscription::query()
            ->where('tenant_id', $tenant->getKey())
            ->where('status', 'active')
            ->where('starts_at', '<=', now())
            ->where('ends_at', '>', now())
            ->exists();

        if (!$tenantIsActive || !$hasActiveSubscription) {
            return response()->json([
                'success' => false,
                'message' => 'Tenant subscription inactive or expired',
            ], 403);
        }

        return $next($request);
    }
}

