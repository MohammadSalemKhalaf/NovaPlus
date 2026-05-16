<?php

namespace App\Http\Controllers\EndUser;

use App\Http\Controllers\Controller;
use App\Http\Requests\EndUser\RegisterRequest;
use App\Http\Requests\EndUser\LoginRequest;
use App\Http\Requests\EndUser\UpdateProfileRequest;
use App\Services\EndUser\EndUserAuthService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class EndUserAuthController extends Controller
{
    public function __construct(
        private EndUserAuthService $authService
    ) {}

    /**
     * Register a new end user.
     * POST /api/v1/enduser/auth/register
     */
    public function register(RegisterRequest $request): JsonResponse
    {
        try {
            $result = $this->authService->register($request->validated());

            return response()->json([
                'success' => true,
                'message' => 'User registered successfully',
                'data' => [
                    'user' => $result['user']->toArray(),
                    'token' => $result['token'],
                ],
            ], 201);
        } catch (\InvalidArgumentException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
                'data' => null,
            ], 422);
        }
    }

    /**
     * Login user.
     * POST /api/v1/enduser/auth/login
     */
    public function login(LoginRequest $request): JsonResponse
    {
        try {
            $result = $this->authService->login(
                $request->validated('email'),
                $request->validated('password'),
                $request->validated('device_id')
            );

            return response()->json([
                'success' => true,
                'message' => 'Login successful',
                'data' => [
                    'user' => $result['user']->toArray(),
                    'token' => $result['token'],
                    'cart_merge' => $result['cart_merge'] ?? null,
                ],
            ], 200);
        } catch (\InvalidArgumentException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
                'data' => null,
            ], 401);
        } catch (\Throwable $e) {
            return response()->json([
                'success' => false,
                'message' => 'Login failed due to a server error.',
                'data' => null,
                'meta' => [
                    'error' => $e->getMessage(),
                ],
            ], 500);
        }
    }

    /**
     * Logout user.
     * POST /api/v1/enduser/auth/logout
     */
    public function logout(Request $request): JsonResponse
    {
        $this->authService->logout($request->user('sanctum'));

        return response()->json([
            'success' => true,
            'message' => 'Logged out successfully',
            'data' => null,
        ], 200);
    }

    /**
     * Get user profile.
     * GET /api/v1/enduser/auth/profile
     */
    public function profile(Request $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $profile = $this->authService->getProfile($user);

        return response()->json([
            'success' => true,
            'message' => 'Profile retrieved successfully',
            'data' => $profile->toArray(),
        ], 200);
    }

    /**
     * Get authenticated user info.
     * GET /api/v1/enduser/auth/me
     */
    public function me(Request $request): JsonResponse
    {
        return $this->profile($request);
    }

    /**
     * Update user profile.
     * PUT /api/v1/enduser/auth/profile
     */
    public function updateProfile(UpdateProfileRequest $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $profile = $this->authService->updateProfile($user, $request->validated());

        return response()->json([
            'success' => true,
            'message' => 'Profile updated successfully',
            'data' => $profile->toArray(),
        ], 200);
    }

    /**
     * Delete user account.
     * DELETE /api/v1/enduser/auth/profile
     */
    public function destroyAccount(Request $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $this->authService->deleteAccount($user);

        return response()->json([
            'success' => true,
            'message' => 'Account deleted successfully',
            'data' => null,
        ], 200);
    }
}
