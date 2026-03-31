<?php

namespace App\Http\Controllers\EndUser;

use App\Http\Controllers\Controller;
use App\Http\Requests\EndUser\FavoritesRequest;
use App\Http\Requests\EndUser\UpdateFavoriteRequest;
use App\Services\EndUser\FavoritesService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FavoritesController extends Controller
{
    public function __construct(
        private FavoritesService $favoritesService
    ) {}

    /**
     * Get user's favorite stores.
     * GET /api/v1/enduser/favorites
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $favorites = $this->favoritesService->listFavorites($user, [
            'per_page' => $request->query('per_page'),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Favorites retrieved successfully',
            'data' => $favorites->items(),
            'meta' => [
                'current_page' => $favorites->currentPage(),
                'per_page' => $favorites->perPage(),
                'total' => $favorites->total(),
                'last_page' => $favorites->lastPage(),
            ],
        ], 200);
    }

    /**
     * Add store to favorites.
     * POST /api/v1/enduser/favorites
     */
    public function store(FavoritesRequest $request): JsonResponse
    {
        $user = $request->user('sanctum');
        $validated = $request->validated();

        $favorite = $this->favoritesService->addFavorite(
            $user,
            (int) $validated['tenant_id'],
            (bool) ($validated['notifications_optin'] ?? false)
        );

        return response()->json([
            'success' => true,
            'message' => 'Store added to favorites',
            'data' => $favorite->toArray(),
        ], 201);
    }

    /**
     * Remove store from favorites.
     * DELETE /api/v1/enduser/favorites/{id}
     */
    public function destroy(Request $request, int $tenantId): JsonResponse
    {
        $user = $request->user('sanctum');

        if (!$this->favoritesService->isFavorited($user, $tenantId)) {
            return response()->json([
                'success' => false,
                'message' => 'Store is not in favorites',
                'data' => null,
            ], 404);
        }

        $this->favoritesService->removeFavorite($user, $tenantId);

        return response()->json([
            'success' => true,
            'message' => 'Store removed from favorites',
            'data' => null,
        ], 200);
    }

    /**
     * Check if store is favorited.
     * GET /api/v1/enduser/favorites/check/{id}
     */
    public function check(Request $request, int $tenantId): JsonResponse
    {
        $user = $request->user('sanctum');
        $isFavorited = $this->favoritesService->isFavorited($user, $tenantId);

        return response()->json([
            'success' => true,
            'message' => 'Check completed',
            'data' => ['is_favorited' => $isFavorited],
        ], 200);
    }

    /**
     * Update favorite store settings.
     * PUT /api/v1/enduser/favorites/{tenant_id}
     */
    public function update(UpdateFavoriteRequest $request, int $tenant_id): JsonResponse
    {
        $user = $request->user('sanctum');

        if (!$this->favoritesService->isFavorited($user, $tenant_id)) {
            return response()->json([
                'success' => false,
                'message' => 'Store is not in favorites',
                'data' => null,
            ], 404);
        }

        $favorite = $this->favoritesService->updateFavorite(
            $user,
            $tenant_id,
            (bool) $request->validated('notifications_optin')
        );

        return response()->json([
            'success' => true,
            'message' => 'Favorite store updated successfully',
            'data' => $favorite->toArray(),
        ], 200);
    }
}
