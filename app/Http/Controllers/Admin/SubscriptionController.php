<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\CreateSubscriptionCodeRequest;
use App\Http\Requests\Admin\RedeemSubscriptionCodeRequest;
use App\Models\Subscription;
use App\Models\SubscriptionCode;
use App\Models\Tenant;
use App\Models\TenantUser;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Auth;
use Illuminate\Http\Request;

class SubscriptionController extends Controller
{
    /**
     * Get latest active (unused) subscription code for current sales agent/admin.
     */
    public function latestActiveCode(Request $request)
    {
        try {
            $user = $request->user();

            $query = SubscriptionCode::query()
                ->active()
                ->latest('id');

            // Sales agents should only see their own generated codes.
            if ($user !== null) {
                $query->where('sold_by_user_id', $user->id);
            }

            $subscriptionCode = $query->first();

            return response()->json([
                'success' => true,
                'message' => $subscriptionCode === null
                    ? 'No active subscription code found.'
                    : 'Latest active subscription code fetched successfully.',
                'data' => $subscriptionCode === null
                    ? (object) []
                    : [
                        'subscription_code_id' => $subscriptionCode->id,
                        'code' => $subscriptionCode->code,
                        'duration_months' => $subscriptionCode->duration_months,
                        'status' => $subscriptionCode->status,
                        'created_at' => $subscriptionCode->created_at,
                    ],
                'meta' => (object) [],
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
                'data' => (object) [],
                'meta' => (object) [],
            ], 422);
        }
    }

    /**
     * Create a new subscription code
     */
    public function storeCode(CreateSubscriptionCodeRequest $request)
    {
        try {
            $validated = $request->validated();

            // Check if code already exists
            $existingCode = SubscriptionCode::where('code', $validated['code'])->first();
            if ($existingCode) {
                return response()->json([
                    'success' => false,
                    'message' => 'Subscription code already exists.',
                    'data' => (object) [],
                    'meta' => (object) [],
                ], 422);
            }

            // Create subscription code
            $subscriptionCode = SubscriptionCode::create([
                'code' => $validated['code'],
                'duration_months' => $validated['duration_months'],
                'note' => $validated['note'] ?? null,
                'created_by_admin_id' => Auth::user()->id,
                'sold_by_user_id' => $validated['sold_by_user_id'] ?? null,
                'status' => 'active',
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Subscription code created successfully.',
                'data' => [
                    'subscription_code_id' => $subscriptionCode->id,
                    'code' => $subscriptionCode->code,
                    'duration_months' => $subscriptionCode->duration_months,
                    'status' => $subscriptionCode->status,
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

    /**
     * Redeem a subscription code
     */
    public function redeem(RedeemSubscriptionCodeRequest $request)
    {
        try {
            $validated = $request->validated();

            // Find subscription code
            $subscriptionCode = SubscriptionCode::where('code', $validated['code'])->first();
            if (!$subscriptionCode) {
                return response()->json([
                    'success' => false,
                    'message' => 'Subscription code not found.',
                    'data' => (object) [],
                    'meta' => (object) [],
                ], 404);
            }

            // Check if code is already used
            if ($subscriptionCode->status === 'used' || $subscriptionCode->redeemed_at) {
                return response()->json([
                    'success' => false,
                    'message' => 'Subscription code has already been redeemed.',
                    'data' => (object) [],
                    'meta' => (object) [],
                ], 422);
            }

            if ($subscriptionCode->status !== 'active') {
                return response()->json([
                    'success' => false,
                    'message' => 'Subscription code is not active.',
                    'data' => (object) [],
                    'meta' => (object) [],
                ], 422);
            }

            // Find tenant
            $tenant = Tenant::findOrFail($validated['tenant_id']);

            $subscription = DB::transaction(function () use ($tenant, $subscriptionCode) {
                Subscription::query()
                    ->where('tenant_id', $tenant->id)
                    ->where('status', 'active')
                    ->update([
                        'status' => 'expired',
                        'ends_at' => now(),
                    ]);

                $startsAt = now();
                $endsAt = $startsAt->copy()->addMonths((int) $subscriptionCode->duration_months);

                $subscription = Subscription::query()->create([
                    'tenant_id' => $tenant->id,
                    'plan_code' => 'standard',
                    'code' => $subscriptionCode->code,
                    'activation_channel' => 'internal',
                    'status' => 'active',
                    'starts_at' => $startsAt,
                    'ends_at' => $endsAt,
                    'billing_cycle' => 'monthly',
                    'created_by_admin_id' => $subscriptionCode->created_by_admin_id,
                    'sold_by_user_id' => $subscriptionCode->sold_by_user_id,
                    'activated_by_user_id' => Auth::id(),
                    'redeemed_at' => now(),
                ]);

                $subscriptionCode->update([
                    'status' => 'used',
                    'redeemed_at' => now(),
                    'redeemed_by_subscription_id' => $subscription->id,
                ]);

                $tenant->status = 'active';
                $tenant->save();

                $ownerUserId = TenantUser::query()
                    ->where('tenant_id', $tenant->id)
                    ->where('role', 'owner')
                    ->value('user_id');

                if ($ownerUserId !== null) {
                    User::query()
                        ->whereKey($ownerUserId)
                        ->update(['status' => 'active']);
                }

                return $subscription;
            });

            return response()->json([
                'success' => true,
                'message' => 'Subscription activated successfully.',
                'data' => [
                    'subscription_id' => $subscription->id,
                    'tenant_id' => $subscription->tenant_id,
                    'status' => $subscription->status,
                    'starts_at' => $subscription->starts_at,
                    'ends_at' => $subscription->ends_at,
                    'activated_at' => $subscription->redeemed_at,
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
