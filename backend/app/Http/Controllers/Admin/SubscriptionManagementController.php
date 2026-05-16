<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\SubscriptionActionRequest;
use App\Http\Requests\Admin\SubscriptionFilterRequest;
use App\Services\Admin\SubscriptionManagementService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SubscriptionManagementController extends Controller
{
    public function __construct(private readonly SubscriptionManagementService $service) {}

    /**
     * List subscriptions with filters and pagination.
     */
    public function index(SubscriptionFilterRequest $request): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $data = $this->service->list($request->validated());

        return response()->json([
            'success' => true,
            'message' => 'Subscriptions fetched successfully.',
            'data' => $data,
            'meta' => (object) [],
        ]);
    }

    /**
     * Get single subscription.
     */
    public function show(Request $request, int $id): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $subscription = $this->service->show($id);

        if (!$subscription) {
            return response()->json([
                'success' => false,
                'message' => 'Subscription not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Subscription fetched successfully.',
            'data' => [
                'subscription' => $subscription,
            ],
            'meta' => (object) [],
        ]);
    }

    /**
     * Get active subscriptions.
     */
    public function active(SubscriptionFilterRequest $request): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $data = $this->service->getActive($request->validated());

        return response()->json([
            'success' => true,
            'message' => 'Active subscriptions fetched successfully.',
            'data' => $data,
            'meta' => (object) [],
        ]);
    }

    /**
     * Get expired subscriptions.
     */
    public function expired(SubscriptionFilterRequest $request): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $data = $this->service->getExpired($request->validated());

        return response()->json([
            'success' => true,
            'message' => 'Expired subscriptions fetched successfully.',
            'data' => $data,
            'meta' => (object) [],
        ]);
    }

    /**
     * Get expiring subscriptions (soon).
     */
    public function expiringSoon(SubscriptionFilterRequest $request): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $days = min((int) ($request->query('days') ?? 7), 365);
        $data = $this->service->getExpiringIn($days, $request->validated());

        return response()->json([
            'success' => true,
            'message' => 'Expiring subscriptions fetched successfully.',
            'data' => $data,
            'meta' => (object) [],
        ]);
    }

    /**
     * Perform action on subscription (activate, suspend, cancel, renew).
     */
    public function action(SubscriptionActionRequest $request, int $id): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $validated = $request->validated();
        $action = $validated['action'];
        $months = $validated['months'] ?? 1;

        $result = match ($action) {
            'activate' => $this->service->activate($id),
            'suspend' => $this->service->suspend($id),
            'cancel' => $this->service->cancel($id),
            'renew' => $this->service->renew($id, $months),
            default => null,
        };

        if ($result === null) {
            return response()->json([
                'success' => false,
                'message' => 'Subscription not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => "Subscription {$action}d successfully.",
            'data' => [
                'subscription' => $result,
            ],
            'meta' => (object) [],
        ]);
    }

    /**
     * Helper to ensure super admin.
     */
    private function requireSuperAdmin(Request $request): \App\Models\User|JsonResponse
    {
        /** @var \App\Models\User|null $user */
        $user = $request->user();

        if ($user === null) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthenticated.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 401);
        }

        if (!$user->isSuperAdmin()) {
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
