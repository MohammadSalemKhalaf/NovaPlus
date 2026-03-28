<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('carts', function (Blueprint $table): void {
            if (!Schema::hasColumn('carts', 'user_id')) {
                $table->foreignId('user_id')->nullable()->after('device_id')->constrained('users')->nullOnDelete();
                $table->index(['user_id', 'tenant_id', 'status'], 'carts_user_tenant_status_index');
            }
        });

        Schema::table('cart_items', function (Blueprint $table): void {
            if (!Schema::hasColumn('cart_items', 'user_id')) {
                $table->foreignId('user_id')->nullable()->after('device_id')->constrained('users')->nullOnDelete();
                $table->index('user_id', 'cart_items_user_id_index');
            }
        });

        Schema::table('user_favorite_stores', function (Blueprint $table): void {
            if (!Schema::hasColumn('user_favorite_stores', 'notifications_optin')) {
                $table->boolean('notifications_optin')->default(false)->after('tenant_id');
            }
        });

        if (!$this->indexExists('user_store_views', 'user_store_views_user_tenant_unique')) {
            Schema::table('user_store_views', function (Blueprint $table): void {
                $table->unique(['user_id', 'tenant_id'], 'user_store_views_user_tenant_unique');
            });
        }
    }

    public function down(): void
    {
        if ($this->indexExists('user_store_views', 'user_store_views_user_tenant_unique')) {
            Schema::table('user_store_views', function (Blueprint $table): void {
                $table->dropUnique('user_store_views_user_tenant_unique');
            });
        }

        Schema::table('user_favorite_stores', function (Blueprint $table): void {
            if (Schema::hasColumn('user_favorite_stores', 'notifications_optin')) {
                $table->dropColumn('notifications_optin');
            }
        });

        Schema::table('cart_items', function (Blueprint $table): void {
            if (Schema::hasColumn('cart_items', 'user_id')) {
                $table->dropForeign(['user_id']);
                $table->dropIndex('cart_items_user_id_index');
                $table->dropColumn('user_id');
            }
        });

        Schema::table('carts', function (Blueprint $table): void {
            if (Schema::hasColumn('carts', 'user_id')) {
                $table->dropForeign(['user_id']);
                $table->dropIndex('carts_user_tenant_status_index');
                $table->dropColumn('user_id');
            }
        });
    }

    private function indexExists(string $table, string $indexName): bool
    {
        return DB::table('information_schema.statistics')
            ->where('table_schema', DB::getDatabaseName())
            ->where('table_name', $table)
            ->where('index_name', $indexName)
            ->exists();
    }
};
