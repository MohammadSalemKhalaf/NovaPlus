<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        DB::statement("UPDATE tenant_users tu JOIN (SELECT tenant_id, MIN(id) AS keep_id FROM tenant_users WHERE role = 'owner' GROUP BY tenant_id HAVING COUNT(*) > 1) d ON d.tenant_id = tu.tenant_id SET tu.role = 'admin' WHERE tu.role = 'owner' AND tu.id <> d.keep_id");

        DB::statement("UPDATE tenant_users tu JOIN (SELECT user_id, MIN(id) AS keep_id FROM tenant_users WHERE role = 'owner' GROUP BY user_id HAVING COUNT(*) > 1) d ON d.user_id = tu.user_id SET tu.role = 'admin' WHERE tu.role = 'owner' AND tu.id <> d.keep_id");

        if (!Schema::hasColumn('tenant_users', 'owner_tenant_guard')) {
            Schema::table('tenant_users', function (Blueprint $table): void {
                $table->unsignedBigInteger('owner_tenant_guard')
                    ->nullable()
                    ->storedAs("CASE WHEN role = 'owner' THEN tenant_id ELSE NULL END");
            });
        }

        if (!Schema::hasColumn('tenant_users', 'owner_user_guard')) {
            Schema::table('tenant_users', function (Blueprint $table): void {
                $table->unsignedBigInteger('owner_user_guard')
                    ->nullable()
                    ->storedAs("CASE WHEN role = 'owner' THEN user_id ELSE NULL END");
            });
        }

        $tenantIndexExists = DB::table('information_schema.statistics')
            ->where('table_schema', DB::raw('DATABASE()'))
            ->where('table_name', 'tenant_users')
            ->where('index_name', 'tenant_users_owner_unique_per_tenant')
            ->exists();

        if (!$tenantIndexExists) {
            DB::statement('ALTER TABLE tenant_users ADD UNIQUE tenant_users_owner_unique_per_tenant (owner_tenant_guard)');
        }

        $userIndexExists = DB::table('information_schema.statistics')
            ->where('table_schema', DB::raw('DATABASE()'))
            ->where('table_name', 'tenant_users')
            ->where('index_name', 'tenant_users_owner_unique_per_user')
            ->exists();

        if (!$userIndexExists) {
            DB::statement('ALTER TABLE tenant_users ADD UNIQUE tenant_users_owner_unique_per_user (owner_user_guard)');
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        $tenantIndexExists = DB::table('information_schema.statistics')
            ->where('table_schema', DB::raw('DATABASE()'))
            ->where('table_name', 'tenant_users')
            ->where('index_name', 'tenant_users_owner_unique_per_tenant')
            ->exists();

        if ($tenantIndexExists) {
            DB::statement('ALTER TABLE tenant_users DROP INDEX tenant_users_owner_unique_per_tenant');
        }

        $userIndexExists = DB::table('information_schema.statistics')
            ->where('table_schema', DB::raw('DATABASE()'))
            ->where('table_name', 'tenant_users')
            ->where('index_name', 'tenant_users_owner_unique_per_user')
            ->exists();

        if ($userIndexExists) {
            DB::statement('ALTER TABLE tenant_users DROP INDEX tenant_users_owner_unique_per_user');
        }

        if (Schema::hasColumn('tenant_users', 'owner_tenant_guard') || Schema::hasColumn('tenant_users', 'owner_user_guard')) {
            Schema::table('tenant_users', function (Blueprint $table): void {
                if (Schema::hasColumn('tenant_users', 'owner_tenant_guard')) {
                    $table->dropColumn('owner_tenant_guard');
                }
                if (Schema::hasColumn('tenant_users', 'owner_user_guard')) {
                    $table->dropColumn('owner_user_guard');
                }
            });
        }
    }
};
