<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\UserManagementIndexRequest;
use App\Http\Requests\Admin\UserManagementUpdateRequest;
use App\Models\User;
use App\Services\Admin\UserManagementService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class UserManagementController extends Controller
{
    public function __construct(private readonly UserManagementService $userManagementService)
    {
    }

    public function index(UserManagementIndexRequest $request): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $result = $this->userManagementService->list($request->validated());

        return response()->json([
            'success' => true,
            'message' => 'Users fetched successfully.',
            'data' => [
                'users' => $result['users'],
            ],
            'meta' => [
                'pagination' => $result['pagination'],
            ],
        ]);
    }

    public function show(Request $request, int $user_id): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        $user = $this->userManagementService->show($user_id);

        if ($user === null) {
            return response()->json([
                'success' => false,
                'message' => 'User not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'User fetched successfully.',
            'data' => [
                'user' => $user,
            ],
            'meta' => (object) [],
        ]);
    }

    public function update(UserManagementUpdateRequest $request, int $user_id): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        try {
            $user = $this->userManagementService->update($user_id, $request->validated());
        } catch (\InvalidArgumentException $exception) {
            return response()->json([
                'success' => false,
                'message' => $exception->getMessage(),
                'data' => (object) [],
                'meta' => (object) [],
            ], 422);
        }

        if ($user === null) {
            return response()->json([
                'success' => false,
                'message' => 'User not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'User updated successfully.',
            'data' => [
                'user' => $user,
            ],
            'meta' => (object) [],
        ]);
    }

    public function destroy(Request $request, int $user_id): JsonResponse
    {
        $actor = $this->requireSuperAdmin($request);

        if ($actor instanceof JsonResponse) {
            return $actor;
        }

        try {
            $deleted = $this->userManagementService->delete($user_id, $actor->id);
        } catch (\InvalidArgumentException $exception) {
            return response()->json([
                'success' => false,
                'message' => $exception->getMessage(),
                'data' => (object) [],
                'meta' => (object) [],
            ], 422);
        }

        if (!$deleted) {
            return response()->json([
                'success' => false,
                'message' => 'User not found.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'User deleted successfully.',
            'data' => [
                'deleted' => true,
                'id' => $user_id,
            ],
            'meta' => (object) [],
        ]);
    }

    /**
     * @return User|JsonResponse
     */
    private function requireSuperAdmin(Request $request): User|JsonResponse
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

        if (!$user->roles()->where('slug', 'super_admin')->exists()) {
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
