<?php

use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\CategoryController;
use App\Http\Controllers\Admin\ItemController;
use App\Http\Controllers\Admin\ItemImageController;
use App\Http\Controllers\Admin\ItemPriceController;
use App\Http\Controllers\Admin\OnboardingController;
use App\Http\Controllers\Admin\RevenueController;
use App\Http\Controllers\Admin\SalesAgentController;
use App\Http\Controllers\Admin\SalesAgentPerformanceController;
use App\Http\Controllers\Admin\SubscriptionController;
use App\Http\Controllers\Admin\SubscriptionManagementController;
use App\Http\Controllers\Admin\TenantController;
use App\Http\Controllers\Admin\TenantControlController;
use App\Http\Controllers\Admin\TenantUserController;
use App\Http\Controllers\Admin\UserController;
use App\Http\Controllers\Admin\UserManagementController;
use App\Http\Controllers\Owner\CategoryController as OwnerCategoryController;
use App\Http\Controllers\Owner\ItemController as OwnerItemController;
use App\Http\Controllers\Owner\OfferController as OwnerOfferController;
use App\Http\Controllers\Owner\ProfileController as OwnerProfileController;
use App\Http\Controllers\Public\BusinessTypeController;
use App\Http\Controllers\Public\CartController;
use App\Http\Controllers\Public\CatalogController as LegacyPublicCatalogController;
use App\Http\Controllers\Public\PublicCatalogController;
use App\Http\Controllers\Public\StoreDiscoveryController;
use App\Http\Controllers\SalesAgent\ProfileController as SalesAgentProfileController;
use App\Http\Controllers\EndUser\CartPersistenceController;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\EndUser\EndUserAuthController;
use App\Http\Controllers\EndUser\FavoritesController;
use App\Http\Controllers\EndUser\GuestCart\GuestCartController;
use App\Http\Controllers\EndUser\NotificationsController;
use App\Http\Controllers\EndUser\PreferencesController;
use App\Http\Controllers\EndUser\RecentlyViewedController;

Route::prefix('v1/admin')->group(function (): void {
    Route::prefix('auth')->group(function (): void {
        Route::post('login', [AuthController::class, 'login']);

        Route::middleware('auth:sanctum')->group(function (): void {
            Route::get('me', [AuthController::class, 'me']);
            Route::put('profile', [AuthController::class, 'updateProfile']);
            Route::post('logout', [AuthController::class, 'logout']);
        });
    });

    Route::middleware('auth:sanctum')->group(function (): void {
        Route::middleware('platform.admin')->group(function (): void {
            Route::post('users', [UserController::class, 'store']);
            Route::prefix('users')->group(function (): void {
                Route::get('/', [UserManagementController::class, 'index']);
                Route::get('{user_id}', [UserManagementController::class, 'show'])->whereNumber('user_id');
                Route::put('{user_id}', [UserManagementController::class, 'update'])->whereNumber('user_id');
                Route::delete('{user_id}', [UserManagementController::class, 'destroy'])->whereNumber('user_id');
            });
            Route::post('tenants', [TenantController::class, 'store']);
            Route::get('tenants', [TenantControlController::class, 'index']);

            Route::prefix('sales-agents')->group(function (): void {
                Route::post('/', [SalesAgentController::class, 'store']);
                Route::get('/', [SalesAgentController::class, 'index']);
                Route::get('{sales_agent}', [SalesAgentController::class, 'show']);
                Route::put('{sales_agent}', [SalesAgentController::class, 'update']);
                Route::patch('{sales_agent}/status', [SalesAgentController::class, 'updateStatus']);
                Route::delete('{sales_agent}', [SalesAgentController::class, 'destroy']);
            });

            Route::prefix('onboarding')->group(function (): void {
                Route::post('owner', [OnboardingController::class, 'storeOwner']);
            });

            Route::prefix('subscriptions')->group(function (): void {
                Route::post('codes', [SubscriptionController::class, 'storeCode']);
                Route::post('redeem', [SubscriptionController::class, 'redeem']);
            });

            // Revenue and subscription management (super_admin only)
            Route::prefix('revenue')->group(function (): void {
                Route::get('dashboard', [RevenueController::class, 'dashboard']);
                Route::get('by-agent', [RevenueController::class, 'byAgent']);
                Route::get('top-agents', [RevenueController::class, 'topAgents']);
            });

            Route::prefix('subscriptions-management')->group(function (): void {
                Route::get('/', [SubscriptionManagementController::class, 'index']);
                Route::get('active', [SubscriptionManagementController::class, 'active']);
                Route::get('expired', [SubscriptionManagementController::class, 'expired']);
                Route::get('expiring-soon', [SubscriptionManagementController::class, 'expiringSoon']);
                Route::get('{id}', [SubscriptionManagementController::class, 'show']);
                Route::post('{id}/action', [SubscriptionManagementController::class, 'action']);
            });

            Route::prefix('tenants')->group(function (): void {
                Route::get('{id}/controls', [TenantControlController::class, 'show']);
                Route::post('{id}/controls', [TenantControlController::class, 'action']);
            });

            Route::prefix('sales-agents')->group(function (): void {
                Route::get('reports/created-owners', [SalesAgentPerformanceController::class, 'createdOwnersReport']);
                Route::get('{id}/performance', [SalesAgentPerformanceController::class, 'show']);
                Route::get('performance/top-performers', [SalesAgentPerformanceController::class, 'topPerformers']);
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

Route::prefix('v1/owner')
    ->middleware(['auth:sanctum', 'tenant.resolve', 'tenant.access', 'tenant.owner'])
    ->group(function (): void {
        Route::put('profile', [OwnerProfileController::class, 'updateProfile']);

        Route::prefix('offers')->group(function (): void {
            Route::get('/', [OwnerOfferController::class, 'index']);
            Route::post('/', [OwnerOfferController::class, 'store']);
            Route::put('{offer}', [OwnerOfferController::class, 'update'])->whereNumber('offer');
            Route::delete('{offer}', [OwnerOfferController::class, 'destroy'])->whereNumber('offer');
        });
    });

Route::prefix('v1/public')->group(function (): void {
    Route::get('business-types', [BusinessTypeController::class, 'index']);

    Route::get('stores', [StoreDiscoveryController::class, 'index']);
    Route::get('stores/{tenant_slug}', [StoreDiscoveryController::class, 'show']);

    Route::get('catalog/{tenant_slug}/categories', [PublicCatalogController::class, 'categories']);
    Route::get('catalog/{tenant_slug}/items', [PublicCatalogController::class, 'items']);
    Route::get('catalog/{tenant_slug}', [LegacyPublicCatalogController::class, 'show']);
    Route::get('tenants/{tenant_id}/categories', [PublicCatalogController::class, 'categoriesByTenantId'])->whereNumber('tenant_id');
    Route::get('tenants/{tenant_id}/items', [PublicCatalogController::class, 'itemsByTenantId'])->whereNumber('tenant_id');
    Route::get('tenants/{tenant_id}/items/{item_id}', [PublicCatalogController::class, 'showItemByTenantId'])->whereNumber('tenant_id')->whereNumber('item_id');

    Route::get('cart', [CartController::class, 'show']);
    Route::post('cart/items', [CartController::class, 'addItem']);
    Route::post('cart/items/increment', [CartController::class, 'incrementItem']);
    Route::post('cart/items/decrement', [CartController::class, 'decrementItem']);
    Route::delete('cart/items/{item_id}', [CartController::class, 'removeItem']);
    Route::post('cart/clear', [CartController::class, 'clear']);
    Route::post('cart/checkout-whatsapp', [CartController::class, 'checkoutWhatsApp']);
});

Route::prefix('v1/enduser')->group(function (): void {
    Route::prefix('auth')->group(function (): void {
        Route::post('register', [EndUserAuthController::class, 'register']);
        Route::post('login', [EndUserAuthController::class, 'login']);

        Route::middleware('auth:sanctum')->group(function (): void {
            Route::get('me', [EndUserAuthController::class, 'me']);
            Route::post('logout', [EndUserAuthController::class, 'logout']);
            Route::get('profile', [EndUserAuthController::class, 'profile']);
            Route::put('profile', [EndUserAuthController::class, 'updateProfile']);
            Route::delete('profile', [EndUserAuthController::class, 'destroyAccount']);
        });
    });

    Route::middleware('auth:sanctum')->group(function (): void {
        Route::prefix('favorites')->group(function (): void {
            Route::get('/', [FavoritesController::class, 'index']);
            Route::post('/', [FavoritesController::class, 'store']);
            Route::get('check/{tenant_id}', [FavoritesController::class, 'check']);
            Route::put('{tenant_id}', [FavoritesController::class, 'update'])->whereNumber('tenant_id');
            Route::delete('{tenant_id}', [FavoritesController::class, 'destroy']);
        });

        Route::prefix('preferences')->group(function (): void {
            Route::get('/', [PreferencesController::class, 'show']);
            Route::put('/', [PreferencesController::class, 'update']);
        });

        Route::prefix('recently-viewed')->group(function (): void {
            Route::get('/', [RecentlyViewedController::class, 'index']);
            Route::post('{tenant_id}', [RecentlyViewedController::class, 'store']);
        });

        Route::prefix('cart')->group(function (): void {
            Route::get('/', [CartPersistenceController::class, 'show']);
            Route::post('merge-preview', [CartPersistenceController::class, 'previewMerge']);
            Route::post('merge-device', [CartPersistenceController::class, 'merge']);
        });

        Route::prefix('guest-cart')->group(function (): void {
            Route::post('preview', [GuestCartController::class, 'preview']);
            Route::post('merge', [GuestCartController::class, 'merge']);
        });

        Route::prefix('notifications')->group(function (): void {
            Route::get('/', [NotificationsController::class, 'index']);
            Route::post('{id}/read', [NotificationsController::class, 'markAsRead'])->whereNumber('id');
            Route::post('read-all', [NotificationsController::class, 'markAllAsRead']);
        });
    });
});

Route::prefix('v1/sales-agent')
    ->middleware('auth:sanctum')
    ->group(function (): void {
        Route::put('profile', [SalesAgentProfileController::class, 'updateProfile']);

        Route::get('owners', [SalesAgentProfileController::class, 'owners']);
        Route::get('owners/{id}', [SalesAgentProfileController::class, 'showOwner']);

        Route::get('stores', [SalesAgentProfileController::class, 'stores']);
        Route::get('stores/{id}', [SalesAgentProfileController::class, 'showStore']);

        Route::prefix('subscriptions')->group(function (): void {
            Route::get('active', [SalesAgentProfileController::class, 'activeSubscriptions']);
            Route::get('expiring', [SalesAgentProfileController::class, 'expiringSubscriptions']);
            Route::get('expired', [SalesAgentProfileController::class, 'expiredSubscriptions']);
            Route::post('renew', [SalesAgentProfileController::class, 'renewSubscription']);
        });
    });

