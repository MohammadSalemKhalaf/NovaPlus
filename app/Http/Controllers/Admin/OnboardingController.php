<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\OwnerOnboardingRequest;
use App\Models\Subscription;
use App\Models\Tenant;
use App\Models\TenantUser;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class OnboardingController extends Controller
{
    public function storeOwner(OwnerOnboardingRequest $request)
    {
        try {
            $validated = $request->validated();

            [$owner, $tenant] = DB::transaction(function () use ($validated, $request) {
                $ownerEmail = $validated['activation_channel'] === 'internal'
                    ? 'owner-' . now()->timestamp . '-' . bin2hex(random_bytes(2)) . '@internal.novaplus'
                    : $validated['owner_email'];

                $owner = User::query()->create([
                    'name' => $validated['owner_name'],
                    'email' => $ownerEmail,
                    'password_hash' => $validated['activation_channel'] === 'email'
                        ? Hash::make($validated['password'])
                        : Hash::make(bin2hex(random_bytes(16))),
                    'status' => $validated['activation_channel'] === 'email' ? 'pending' : 'active',
                    'email_verified_at' => $validated['activation_channel'] === 'internal' ? now() : null,
                ]);

                $tenant = Tenant::query()->create([
                    'owner_user_id' => $owner->id,
                    'name' => $validated['tenant_name'],
                    'slug' => $validated['tenant_slug'],
                    'business_mode' => $validated['business_mode'],
                    'status' => $validated['activation_channel'] === 'email' ? 'pending' : 'active',
                    'primary_language' => 'en',
                    'currency_code' => 'USD',
                    'timezone' => 'UTC',
                ]);

                TenantUser::query()->create([
                    'tenant_id' => $tenant->id,
                    'user_id' => $owner->id,
                    'role' => 'owner',
                    'status' => 'active',
                ]);

                Subscription::query()->create([
                    'tenant_id' => $tenant->id,
                    'plan_code' => 'starter',
                    'code' => 'ONBOARD-' . strtoupper(bin2hex(random_bytes(4))),
                    'status' => 'active',
                    'starts_at' => now(),
                    'ends_at' => now()->addMonth(),
                    'billing_cycle' => 'monthly',
                    'activation_channel' => $validated['activation_channel'],
                    'created_by_admin_id' => $request->user()->id,
                    'redeemed_at' => now(),
                    'activated_by_user_id' => $request->user()->id,
                ]);

                return [$owner, $tenant];
            });

            return response()->json([
                'success' => true,
                'message' => 'Owner onboarded successfully.',
                'data' => [
                    'owner_user_id' => $owner->id,
                    'tenant_id' => $tenant->id,
                    'activation_channel' => $validated['activation_channel'],
                    'email' => $owner->email,
                    'requires_verification' => $validated['activation_channel'] === 'email',
                ],
                'meta' => (object) [],
            ], 201);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
                'data' => (object) [],
                'meta' => (object) [],
            ], 422);
        }
    }
}
