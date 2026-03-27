<?php

namespace App\Providers;

use App\Models\Category;
use App\Models\Item;
use App\Models\Tenant;
use App\Policies\CategoryPolicy;
use App\Policies\ItemPolicy;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Gate::policy(Category::class, CategoryPolicy::class);
        Gate::policy(Item::class, ItemPolicy::class);

        Route::bind('tenant_slug', static function (string $value): Tenant {
            return Tenant::query()->where('slug', $value)->firstOrFail();
        });
    }
}
