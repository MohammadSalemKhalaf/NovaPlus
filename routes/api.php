<?php

use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\CategoryController;
use App\Http\Controllers\Admin\ItemController;
use App\Http\Controllers\Admin\ItemImageController;
use App\Http\Controllers\Admin\ItemPriceController;
use App\Http\Controllers\Admin\OnboardingController;
use App\Http\Controllers\Admin\SubscriptionController;
use App\Http\Controllers\Admin\TenantController;
use App\Http\Controllers\Admin\TenantUserController;
use App\Http\Controllers\Admin\UserController;
use App\Http\Controllers\Owner\CategoryController as OwnerCategoryController;
use App\Http\Controllers\Owner\ItemController as OwnerItemController;
use App\Http\Controllers\Public\BusinessTypeController;
use App\Http\Controllers\Public\CartController;
use App\Http\Controllers\Public\CatalogController as LegacyPublicCatalogController;
use App\Http\Controllers\Public\PublicCatalogController;
use App\Http\Controllers\Public\StoreDiscoveryController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1/admin')->group(function (): void {
    Route::prefix('auth')->group(function (): void {
        Route::post('login', [AuthController::class, 'login']);

        Route::middleware('auth:sanctum')->group(function (): void {
            Route::get('me', [AuthController::class, 'me']);
            Route::post('logout', [AuthController::class, 'logout']);
        });
    });

    Route::middleware('auth:sanctum')->group(function (): void {
        Route::middleware('platform.admin')->group(function (): void {
            Route::post('users', [UserController::class, 'store']);
            Route::post('tenants', [TenantController::class, 'store']);

            Route::prefix('onboarding')->group(function (): void {
                Route::post('owner', [OnboardingController::class, 'storeOwner']);
            });

            Route::prefix('subscriptions')->group(function (): void {
                Route::post('codes', [SubscriptionController::class, 'storeCode']);
                Route::post('redeem', [SubscriptionController::class, 'redeem']);
            });
        });

        Route::post('tenants/{tenant}/users', [TenantUserController::class, 'store']);

        Route::middleware(['tenant.resolve', 'tenant.access'])->group(function (): void {
            Route::get('tenants/current', [TenantController::class, 'current']);
        });
    });
});

Route::prefix('v1/admin/catalog')
    ->middleware(['auth:sanctum', 'tenant.resolve', 'tenant.access'])
    ->group(function (): void {
        Route::get('categories', [CategoryController::class, 'index']);
        Route::post('categories', [CategoryController::class, 'store']);
        Route::get('categories/{id}', [CategoryController::class, 'show']);
        Route::put('categories/{id}', [CategoryController::class, 'update']);
        Route::delete('categories/{id}', [CategoryController::class, 'destroy']);

        Route::get('items', [ItemController::class, 'index']);
        Route::post('items', [ItemController::class, 'store']);
        Route::get('items/{id}', [ItemController::class, 'show']);
        Route::put('items/{id}', [ItemController::class, 'update']);
        Route::delete('items/{id}', [ItemController::class, 'destroy']);

        Route::post('items/{item}/prices/active', [ItemPriceController::class, 'setActive']);
        Route::post('items/{item}/prices/draft', [ItemPriceController::class, 'createDraft']);
        Route::put('items/{item}/prices/{price}', [ItemPriceController::class, 'update']);

        Route::get('items/{item}/images', [ItemImageController::class, 'index']);
        Route::post('items/{item}/images', [ItemImageController::class, 'store']);
        Route::put('items/{item}/images/{image}/primary', [ItemImageController::class, 'setPrimary']);
        Route::delete('items/{item}/images/{image}', [ItemImageController::class, 'destroy']);
    });

Route::prefix('v1/owner/catalog')
    ->middleware(['auth:sanctum', 'tenant.resolve', 'tenant.access', 'tenant.owner'])
    ->group(function (): void {
        Route::get('categories', [OwnerCategoryController::class, 'index']);
        Route::post('categories', [OwnerCategoryController::class, 'store']);
        Route::get('categories/{category}', [OwnerCategoryController::class, 'show']);
        Route::put('categories/{category}', [OwnerCategoryController::class, 'update']);
        Route::delete('categories/{category}', [OwnerCategoryController::class, 'destroy']);

        Route::get('items', [OwnerItemController::class, 'index']);
        Route::post('items', [OwnerItemController::class, 'store']);
        Route::get('items/{item}', [OwnerItemController::class, 'show']);
        Route::put('items/{item}', [OwnerItemController::class, 'update']);
        Route::delete('items/{item}', [OwnerItemController::class, 'destroy']);
    });

Route::prefix('v1/public')->group(function (): void {
    Route::get('business-types', [BusinessTypeController::class, 'index']);

    Route::get('stores', [StoreDiscoveryController::class, 'index']);
    Route::get('stores/{tenant_slug}', [StoreDiscoveryController::class, 'show']);

    Route::get('catalog/{tenant_slug}/categories', [PublicCatalogController::class, 'categories']);
    Route::get('catalog/{tenant_slug}/items', [PublicCatalogController::class, 'items']);
    Route::get('catalog/{tenant_slug}', [LegacyPublicCatalogController::class, 'show']);

    Route::get('cart', [CartController::class, 'show']);
    Route::post('cart/items', [CartController::class, 'addItem']);
    Route::delete('cart/items/{item_id}', [CartController::class, 'removeItem']);
    Route::post('cart/clear', [CartController::class, 'clear']);
    Route::post('cart/checkout-whatsapp', [CartController::class, 'checkoutWhatsApp']);
});

