<?php

namespace App\Http\Controllers\Owner;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\OfferStoreRequest;
use App\Http\Requests\Admin\OfferUpdateRequest;
use App\Http\Resources\OfferResource;
use App\Services\Admin\OfferService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;

class OfferController extends Controller
{
    public function __construct(private readonly OfferService $offerService)
    {
    }

    public function index(Request $request): JsonResponse
    {
        $tenantId = $this->resolveTenantId($request);

        if ($tenantId === null) {
            return $this->tenantContextRequiredResponse();
        }

        $offers = $this->offerService->getByTenant($tenantId, [
            'per_page' => $request->integer('per_page', 15),
            'status' => $request->input('status'),
            'search' => $request->input('search'),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Offers fetched successfully.',
            'data' => [
                'offers' => OfferResource::collection($offers->items()),
            ],
            'meta' => [
                'pagination' => [
                    'current_page' => $offers->currentPage(),
                    'last_page' => $offers->lastPage(),
                    'per_page' => $offers->perPage(),
                    'total' => $offers->total(),
                ],
            ],
        ]);
    }

    public function store(OfferStoreRequest $request): JsonResponse
    {
        $tenantId = $this->resolveTenantId($request);

        if ($tenantId === null) {
            return $this->tenantContextRequiredResponse();
        }

        $offer = $this->offerService->createForTenant(
            $request->validated(),
            $tenantId,
            (int) $request->user()->id,
        );
        if (Schema::hasTable('offer_items')) {
            $offer->load('items:id');
        }

        return response()->json([
            'success' => true,
            'message' => 'Offer created successfully.',
            'data' => [
                'offer' => new OfferResource($offer),
            ],
            'meta' => (object) [],
        ], 201);
    }

    public function update(OfferUpdateRequest $request, int $offer): JsonResponse
    {
        $tenantId = $this->resolveTenantId($request);

        if ($tenantId === null) {
            return $this->tenantContextRequiredResponse();
        }

        $record = $this->offerService->findForTenant($tenantId, $offer);

        if ($record === null) {
            return $this->notFoundResponse('Offer not found.');
        }

        $updated = $this->offerService->updateForTenant($record, $request->validated(), $tenantId);
        if (Schema::hasTable('offer_items')) {
            $updated->load('items:id');
        }

        return response()->json([
            'success' => true,
            'message' => 'Offer updated successfully.',
            'data' => [
                'offer' => new OfferResource($updated),
            ],
            'meta' => (object) [],
        ]);
    }

    public function destroy(Request $request, int $offer): JsonResponse
    {
        $tenantId = $this->resolveTenantId($request);

        if ($tenantId === null) {
            return $this->tenantContextRequiredResponse();
        }

        $record = $this->offerService->findForTenant($tenantId, $offer);

        if ($record === null) {
            return $this->notFoundResponse('Offer not found.');
        }

        $this->offerService->deleteForTenant($record, $tenantId);

        return response()->json([
            'success' => true,
            'message' => 'Offer deleted successfully.',
            'data' => [
                'deleted' => true,
                'id' => $offer,
            ],
            'meta' => (object) [],
        ]);
    }

    private function resolveTenantId(Request $request): ?int
    {
        $tenant = $request->attributes->get('tenant');

        if (is_object($tenant) && method_exists($tenant, 'getKey')) {
            return (int) $tenant->getKey();
        }

        $tenantId = $request->attributes->get('tenant_id');

        return is_numeric($tenantId) ? (int) $tenantId : null;
    }

    private function tenantContextRequiredResponse(): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => 'Tenant context is required.',
            'data' => (object) [],
            'meta' => (object) [],
        ], 400);
    }

    private function notFoundResponse(string $message): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => $message,
            'data' => (object) [],
            'meta' => (object) [],
        ], 404);
    }
}
