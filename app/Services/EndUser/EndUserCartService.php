<?php

namespace App\Services\EndUser;

use App\DTOs\EndUser\CartSummaryDto;
use App\Models\User;
use App\Repositories\Catalog\CartRepository;

class EndUserCartService
{
    public function __construct(private readonly CartRepository $cartRepository)
    {
    }

    public function getUserCart(User $user): array
    {
        $carts = $this->cartRepository->getActiveCartsByUser((int) $user->id);

        return (new CartSummaryDto($carts))->toArray();
    }

    public function previewMerge(User $user, string $deviceId): array
    {
        $deviceCarts = $this->cartRepository->getActiveCartsByDevice($deviceId);
        $userCarts = $this->cartRepository->getActiveCartsByUser((int) $user->id);

        return [
            'device' => [
                'stores_count' => (int) $deviceCarts->count(),
                'items_count' => (int) $deviceCarts->flatMap(fn ($cart) => $cart->items)->sum('quantity'),
            ],
            'user' => [
                'stores_count' => (int) $userCarts->count(),
                'items_count' => (int) $userCarts->flatMap(fn ($cart) => $cart->items)->sum('quantity'),
            ],
        ];
    }

    public function mergeDeviceCart(User $user, string $deviceId): array
    {
        $this->cartRepository->mergeDeviceCartsIntoUser($deviceId, $user);
        $this->cartRepository->attachDeviceCartsToUser($deviceId, (int) $user->id);

        $carts = $this->cartRepository->getActiveCartsByUser((int) $user->id);

        return (new CartSummaryDto($carts))->toArray();
    }
}
