<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsurePlatformAdminMiddleware
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

        // Allow super_admin (no tenant membership) or sales_agent (global role)
        $isSuperAdmin = !$user->tenantUsers()
            ->where('status', 'active')
            ->exists();

        $isSalesAgent = $user->isSalesAgent();

        if (!($isSuperAdmin || $isSalesAgent)) {
            return response()->json([
                'success' => false,
                'message' => 'You are not authorized to access this resource.',
            ], 403);
        }

        return $next($request);
    }
}
