<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\TenantStoreRequest;
use App\Models\Tenant;
use App\Models\TenantUser;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class TenantController extends Controller
{
    public function store(TenantStoreRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $payload = $request->validated();

        $result = DB::transaction(function () use ($user, $payload) {
            $tenant = Tenant::query()->create([
                'owner_user_id' => $user->id,
                'name' => $payload['name'],
                'slug' => Str::slug($payload['slug']),
                'business_mode' => $payload['business_mode'],
                'business_type_id' => $payload['business_type_id'],
                'status' => 'draft',
                'primary_language' => $payload['primary_language'],
                'currency_code' => $payload['currency_code'],
                'timezone' => $payload['timezone'],
                'whatsapp_number' => $payload['whatsapp_number'] ?? null,
                'store_image' => $payload['store_image'] ?? null,
                'onboarding_completed_at' => null,
            ]);

            TenantUser::query()->create([
                'tenant_id' => $tenant->id,
                'user_id' => $user->id,
                'role' => 'owner',
                'status' => 'active',
            ]);

            return $tenant;
        });

        return response()->json([
            'success' => true,
            'message' => 'Tenant created successfully.',
            'data' => [
                'tenant' => [
                    'id' => $result->id,
                    'name' => $result->name,
                    'slug' => $result->slug,
                    'role' => 'owner',
                ],
            ],
            'meta' => (object) [],
        ], 201);
    }

    public function current(Request $request): JsonResponse
    {
        /** @var Tenant|null $tenant */
        $tenant = $request->attributes->get('tenant');

        if ($tenant === null) {
            return response()->json([
                'success' => false,
                'message' => 'Tenant context is required.',
            ], 400);
        }

        return response()->json([
            'success' => true,
            'message' => 'Tenant fetched successfully.',
            'data' => [
                'tenant' => [
                    'id' => $tenant->id,
                    'name' => $tenant->name,
                    'slug' => $tenant->slug,
                    'business_mode' => $tenant->business_mode,
                    'business_type_id' => $tenant->business_type_id,
                    'whatsapp_number' => $tenant->whatsapp_number,
                    'store_image' => $tenant->store_image,
                    'primary_language' => $tenant->primary_language,
                    'currency_code' => $tenant->currency_code,
                    'timezone' => $tenant->timezone,
                    'onboarding_completed_at' => $tenant->onboarding_completed_at,
                ],
            ],
            'meta' => (object) [],
        ]);
    }
}

