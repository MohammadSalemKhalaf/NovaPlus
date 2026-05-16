<?php

namespace App\Http\Controllers\Owner;

use App\Http\Controllers\Controller;
use App\Http\Requests\Owner\UpdateProfileRequest;
use App\Models\Tenant;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;

class ProfileController extends Controller
{
    public function updateProfile(UpdateProfileRequest $request): JsonResponse
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

        /** @var Tenant|null $tenant */
        $tenant = $request->attributes->get('tenant');

        if ($tenant === null) {
            return response()->json([
                'success' => false,
                'message' => 'Tenant context is required.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 400);
        }

        if ((int) $tenant->owner_user_id !== (int) $user->id) {
            return response()->json([
                'success' => false,
                'message' => 'Only owner can update this profile.',
                'data' => (object) [],
                'meta' => (object) [],
            ], 403);
        }

        $validated = $request->validated();

        if (array_key_exists('name', $validated) && $validated['name'] !== null) {
            $user->update(['name' => $validated['name']]);
        }

        if (array_key_exists('password', $validated) && $validated['password'] !== null) {
            $user->update(['password_hash' => Hash::make($validated['password'])]);
        }

        if (array_key_exists('tenant_whatsapp_number', $validated) && $validated['tenant_whatsapp_number'] !== null) {
            $tenant->update(['whatsapp_number' => $validated['tenant_whatsapp_number']]);
        }

        if (array_key_exists('tenant_store_image', $validated)) {
            $tenant->update(['store_image' => $validated['tenant_store_image']]);
        }

        /** @var UploadedFile|null $tenantStoreImageFile */
        $tenantStoreImageFile = $request->file('tenant_store_image_file');
        if ($tenantStoreImageFile !== null) {
            $storedPath = $tenantStoreImageFile->store('store_images', 'public');

            if (! empty($tenant->store_image) && str_starts_with($tenant->store_image, 'store_images/')) {
                Storage::disk('public')->delete($tenant->store_image);
            }

            $tenant->update(['store_image' => $storedPath]);
        }

        $user = $user->fresh();
        $tenant = $tenant->fresh();

        return response()->json([
            'success' => true,
            'message' => 'Owner profile updated successfully.',
            'data' => [
                'owner' => [
                    'id' => $user?->id,
                    'name' => $user?->name,
                    'email' => $user?->email,
                ],
                'tenant' => [
                    'id' => $tenant?->id,
                    'name' => $tenant?->name,
                    'slug' => $tenant?->slug,
                    'whatsapp_number' => $tenant?->whatsapp_number,
                    'store_image' => $tenant?->store_image,
                ],
            ],
            'meta' => (object) [],
        ]);
    }
}
