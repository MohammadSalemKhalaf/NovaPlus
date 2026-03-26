<?php

use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\CategoryController;
use App\Http\Controllers\Admin\ItemController;
use App\Http\Controllers\Admin\ItemImageController;
use App\Http\Controllers\Admin\ItemPriceController;
use App\Http\Controllers\Admin\TenantController;
use App\Http\Controllers\Admin\TenantUserController;
use App\Http\Controllers\Admin\UserController;
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
        Route::post('users', [UserController::class, 'store']);
        Route::post('tenants', [TenantController::class, 'store']);
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

