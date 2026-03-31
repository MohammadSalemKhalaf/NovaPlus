<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\LoginRequest;
use App\Http\Requests\Admin\UpdateAdminProfileRequest;
use App\Models\Subscription;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function login(LoginRequest $request): JsonResponse
    {
        $credentials = $request->validated();

        $user = User::query()
            ->where('email', $credentials['email'])
            ->first();

        if ($user === null || !Hash::check($credentials['password'], $user->password_hash)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid credentials.',
            ], 401);
        }

        if (! $user->isSuperAdmin() && ! $user->isSalesAgent()) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid credentials.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 401);
        }

        if ($user->status !== 'active') {
            return response()->json([
                'success' => false,
                'message' => 'Account not activated. Please activate your subscription.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 200);
        }

        $activeTenantMemberships = $user->tenantUsers()
            ->with('tenant:id,status')
            ->where('status', 'active')
            ->get();

        if ($activeTenantMemberships->isNotEmpty()) {
            $tenantIds = $activeTenantMemberships
                ->pluck('tenant.id')
                ->filter()
                ->map(fn ($id) => (int) $id)
                ->values();

            $hasActiveTenantAndSubscription = $tenantIds->isNotEmpty()
                && $activeTenantMemberships->contains(fn ($membership) => $membership->tenant?->status === 'active')
                && Subscription::query()
                    ->whereIn('tenant_id', $tenantIds->all())
                    ->where('status', 'active')
                    ->where('starts_at', '<=', now())
                    ->where('ends_at', '>', now())
                    ->exists();

            if (!$hasActiveTenantAndSubscription) {
                return response()->json([
                    'success' => false,
                    'message' => 'Account not activated. Please activate your subscription.',
                    'data' => (object) [],
                    'meta' => (object) [],
                ], 200);
            }
        }

        $token = $user->createToken('admin')->plainTextToken;

        $tenants = $user->tenantUsers()
            ->with('tenant:id,name,slug')
            ->get()
            ->map(function ($membership) {
                return [
                    'id' => $membership->tenant->id,
                    'name' => $membership->tenant->name,
                    'slug' => $membership->tenant->slug,
                    'role' => $membership->role,
                ];
            })
            ->values();

        return response()->json([
            'success' => true,
            'message' => 'Login successful.',
            'data' => [
                'token' => $token,
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                ],
                'tenants' => $tenants,
            ],
            'meta' => (object) [],
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $tenants = $user->tenantUsers()
            ->with('tenant:id,name,slug')
            ->get()
            ->map(function ($membership) {
                return [
                    'id' => $membership->tenant->id,
                    'name' => $membership->tenant->name,
                    'slug' => $membership->tenant->slug,
                    'role' => $membership->role,
                ];
            })
            ->values();

        return response()->json([
            'success' => true,
            'message' => 'User fetched successfully.',
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                ],
                'tenants' => $tenants,
            ],
            'meta' => (object) [],
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user !== null && $request->user()->currentAccessToken() !== null) {
            $request->user()->currentAccessToken()->delete();
        }

        return response()->json([
            'success' => true,
            'message' => 'Logout successful.',
            'data' => (object) [],
            'meta' => (object) [],
        ]);
    }

    public function updateProfile(UpdateAdminProfileRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $validated = $request->validated();

        if (isset($validated['email'])) {
            $user->update(['email' => $validated['email']]);
        }

        if (isset($validated['password'])) {
            $user->update(['password_hash' => Hash::make($validated['password'])]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Profile updated successfully.',
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                ],
            ],
            'meta' => (object) [],
        ]);
    }
}

