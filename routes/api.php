<?php

use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\TenantController;
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
        Route::post('tenants', [TenantController::class, 'store']);

        Route::middleware(['tenant.resolve', 'tenant.access'])->group(function (): void {
            Route::get('tenants/current', [TenantController::class, 'current']);
        });
    });
});

