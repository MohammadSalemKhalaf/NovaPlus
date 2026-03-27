<?php

namespace App\Http\Controllers\Public;

use App\Http\Controllers\Controller;
use App\Services\Public\BusinessTypeService;
use Illuminate\Http\JsonResponse;

class BusinessTypeController extends Controller
{
    public function __construct(private readonly BusinessTypeService $businessTypeService)
    {
    }

    public function index(): JsonResponse
    {
        $businessTypes = $this->businessTypeService->listActiveBusinessTypes();

        return response()->json([
            'success' => true,
            'message' => 'Business types fetched successfully.',
            'data' => $businessTypes->map(static function ($businessType): array {
                return [
                    'id' => $businessType->id,
                    'name' => $businessType->name,
                    'slug' => $businessType->slug,
                ];
            })->values(),
            'meta' => (object) [],
        ]);
    }
}
