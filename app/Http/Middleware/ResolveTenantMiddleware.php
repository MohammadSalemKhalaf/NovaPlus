<?php

namespace App\Http\Middleware;

use App\Models\Tenant;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class ResolveTenantMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        $tenantIdRaw = $request->header('X-Tenant-ID');

        if ($tenantIdRaw === null || $tenantIdRaw === '') {
            return response()->json([
                'success' => false,
                'message' => 'Tenant context is required.',
                'errors' => [
                    'X-Tenant-ID' => ['The X-Tenant-ID header is required.'],
                ],
            ], 422);
        }

        $tenantId = (int) $tenantIdRaw;

        if ($tenantId <= 0) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed.',
                'errors' => [
                    'X-Tenant-ID' => ['The X-Tenant-ID header must be a valid integer.'],
                ],
            ], 422);
        }

        $tenant = Tenant::query()->whereKey($tenantId)->first();

        if ($tenant === null) {
            return response()->json([
                'success' => false,
                'message' => 'Tenant not found.',
            ], 404);
        }

        $request->attributes->set('tenant', $tenant);
        $request->attributes->set('tenant_id', $tenant->getKey());

        return $next($request);
    }
}

