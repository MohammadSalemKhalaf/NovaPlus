<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        api: __DIR__.'/../routes/api.php',
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'platform.admin' => App\Http\Middleware\EnsurePlatformAdminMiddleware::class,
            'tenant.resolve' => App\Http\Middleware\ResolveTenantMiddleware::class,
            'tenant.access' => App\Http\Middleware\EnsureTenantAccessMiddleware::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->render(function (NotFoundHttpException $exception, Request $request) {
            if ($request->is('api/v1/public/catalog/*')) {
                return response()->json([
                    'success' => false,
                    'message' => 'Catalog not found.',
                    'data' => [],
                    'meta' => (object) [],
                ], 404);
            }

            return null;
        });
    })->create();
