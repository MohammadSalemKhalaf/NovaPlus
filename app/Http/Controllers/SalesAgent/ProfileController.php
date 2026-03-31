<?php

namespace App\Http\Controllers\SalesAgent;

use App\Http\Controllers\Controller;
use App\Http\Requests\SalesAgent\RenewSubscriptionRequest;
use App\Http\Requests\SalesAgent\UpdateProfileRequest;
use App\Models\Subscription;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;

class ProfileController extends Controller
{
    public function updateProfile(UpdateProfileRequest $request): JsonResponse
    {
        $agent = $this->requireSalesAgent($request);

        if ($agent instanceof JsonResponse) {
            return $agent;
        }

        $validated = $request->validated();

        if (array_key_exists('email', $validated) && $validated['email'] !== null) {
            $agent->update(['email' => $validated['email']]);
        }

        if (array_key_exists('password', $validated) && $validated['password'] !== null) {
            $agent->update(['password_hash' => Hash::make($validated['password'])]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Profile updated successfully.',
            'data' => [
                'user' => [
                    'id' => $agent->id,
                    'name' => $agent->name,
                    'email' => $agent->email,
                ],
            ],
            'meta' => (object) [],
        ]);
    }

    public function owners(Request $request): JsonResponse
    {
        $agent = $this->requireSalesAgent($request);

        if ($agent instanceof JsonResponse) {
            return $agent;
        }

        $owners = User::query()
            ->where($this->ownerCreatorColumn(), $agent->id)
            ->whereHas('roles', function ($query): void {
                $query->where('slug', 'store_owner');
            })
            ->orderByDesc('created_at')
            ->get(['id', 'name', 'email', 'status', 'created_at']);

        return response()->json([
            'success' => true,
            'message' => 'Owners fetched successfully.',
            'data' => [
                'owners' => $owners,
            ],
            'meta' => (object) [],
        ]);
    }

    public function showOwner(Request $request, int $id): JsonResponse
    {
        $agent = $this->requireSalesAgent($request);

        if ($agent instanceof JsonResponse) {
            return $agent;
        }

        $owner = User::query()
            ->where('id', $id)
            ->where($this->ownerCreatorColumn(), $agent->id)
            ->whereHas('roles', function ($query): void {
                $query->where('slug', 'store_owner');
            })
            ->with('ownedTenants:id,owner_user_id,name,slug,status')
            ->first();

        if ($owner === null) {
            return response()->json([
                'success' => false,
                'message' => 'Owner not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Owner fetched successfully.',
            'data' => [
                'owner' => [
                    'id' => $owner->id,
                    'name' => $owner->name,
                    'email' => $owner->email,
                    'status' => $owner->status,
                    'stores' => $owner->ownedTenants,
                ],
            ],
            'meta' => (object) [],
        ]);
    }

    public function stores(Request $request): JsonResponse
    {
        $agent = $this->requireSalesAgent($request);

        if ($agent instanceof JsonResponse) {
            return $agent;
        }

        $stores = Tenant::query()
            ->with('owner:id,name,email,status')
            ->whereHas('owner', function ($query) use ($agent): void {
                $query->where($this->ownerCreatorColumn(), $agent->id)
                    ->whereHas('roles', function ($roleQuery): void {
                        $roleQuery->where('slug', 'store_owner');
                    });
            })
            ->orderByDesc('created_at')
            ->get(['id', 'owner_user_id', 'name', 'slug', 'status', 'created_at']);

        return response()->json([
            'success' => true,
            'message' => 'Stores fetched successfully.',
            'data' => [
                'stores' => $stores,
            ],
            'meta' => (object) [],
        ]);
    }

    public function showStore(Request $request, int $id): JsonResponse
    {
        $agent = $this->requireSalesAgent($request);

        if ($agent instanceof JsonResponse) {
            return $agent;
        }

        $store = Tenant::query()
            ->with('owner:id,name,email,status')
            ->where('id', $id)
            ->whereHas('owner', function ($query) use ($agent): void {
                $query->where($this->ownerCreatorColumn(), $agent->id)
                    ->whereHas('roles', function ($roleQuery): void {
                        $roleQuery->where('slug', 'store_owner');
                    });
            })
            ->first(['id', 'owner_user_id', 'name', 'slug', 'status', 'business_type_id', 'created_at']);

        if ($store === null) {
            return response()->json([
                'success' => false,
                'message' => 'Store not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Store fetched successfully.',
            'data' => [
                'store' => $store,
            ],
            'meta' => (object) [],
        ]);
    }

    public function activeSubscriptions(Request $request): JsonResponse
    {
        $agent = $this->requireSalesAgent($request);

        if ($agent instanceof JsonResponse) {
            return $agent;
        }

        $subscriptions = $this->agentSubscriptionsBaseQuery($agent)
            ->where('status', 'active')
            ->where('starts_at', '<=', now())
            ->where('ends_at', '>', now())
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Active subscriptions fetched successfully.',
            'data' => [
                'subscriptions' => $subscriptions,
            ],
            'meta' => (object) [],
        ]);
    }

    public function expiringSubscriptions(Request $request): JsonResponse
    {
        $agent = $this->requireSalesAgent($request);

        if ($agent instanceof JsonResponse) {
            return $agent;
        }

        $subscriptions = $this->agentSubscriptionsBaseQuery($agent)
            ->where('status', 'active')
            ->whereBetween('ends_at', [now(), now()->addDays(5)])
            ->orderBy('ends_at')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Expiring subscriptions fetched successfully.',
            'data' => [
                'subscriptions' => $subscriptions,
            ],
            'meta' => (object) [],
        ]);
    }

    public function expiredSubscriptions(Request $request): JsonResponse
    {
        $agent = $this->requireSalesAgent($request);

        if ($agent instanceof JsonResponse) {
            return $agent;
        }

        $subscriptions = $this->agentSubscriptionsBaseQuery($agent)
            ->where(function ($query): void {
                $query->where('status', 'expired')
                    ->orWhere('ends_at', '<=', now());
            })
            ->orderByDesc('ends_at')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Expired subscriptions fetched successfully.',
            'data' => [
                'subscriptions' => $subscriptions,
            ],
            'meta' => (object) [],
        ]);
    }

    public function renewSubscription(RenewSubscriptionRequest $request): JsonResponse
    {
        $agent = $this->requireSalesAgent($request);

        if ($agent instanceof JsonResponse) {
            return $agent;
        }

        $validated = $request->validated();
        $tenantId = (int) $validated['tenant_id'];
        $months = (int) ($validated['months'] ?? 1);

        $tenant = Tenant::query()
            ->with('owner:id')
            ->where('id', $tenantId)
            ->whereHas('owner', function ($query) use ($agent): void {
                $query->where($this->ownerCreatorColumn(), $agent->id)
                    ->whereHas('roles', function ($roleQuery): void {
                        $roleQuery->where('slug', 'store_owner');
                    });
            })
            ->first();

        if ($tenant === null) {
            return response()->json([
                'success' => false,
                'message' => 'Tenant not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        $subscription = Subscription::query()
            ->where('tenant_id', $tenantId)
            ->orderByDesc('ends_at')
            ->orderByDesc('id')
            ->first();

        if ($subscription === null) {
            return response()->json([
                'success' => false,
                'message' => 'Subscription not found for tenant.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        $baseDate = $subscription->ends_at !== null && $subscription->ends_at->gt(now())
            ? $subscription->ends_at->copy()
            : now();

        $subscription->update([
            'status' => 'active',
            'starts_at' => $subscription->starts_at ?? now(),
            'ends_at' => $baseDate->addMonths($months),
            'sold_by_user_id' => $agent->id,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Subscription renewed successfully.',
            'data' => [
                'subscription' => $subscription->fresh(['tenant', 'tenant.owner']),
            ],
            'meta' => (object) [],
        ]);
    }

    private function agentSubscriptionsBaseQuery(User $agent)
    {
        return Subscription::query()
            ->with(['tenant:id,owner_user_id,name,slug,status', 'tenant.owner:id,name,email'])
            ->whereHas('tenant.owner', function ($query) use ($agent): void {
                $query->where($this->ownerCreatorColumn(), $agent->id)
                    ->whereHas('roles', function ($roleQuery): void {
                        $roleQuery->where('slug', 'store_owner');
                    });
            });
    }

    private function ownerCreatorColumn(): string
    {
        return Schema::hasColumn('users', 'created_by_user_id') ? 'created_by_user_id' : 'created_by';
    }

    private function requireSalesAgent(Request $request): User|JsonResponse
    {
        /** @var User|null $user */
        $user = $request->user();

        if ($user === null) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthenticated.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 401);
        }

        if (! $user->isSalesAgent()) {
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
