<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $now = now();

        $rolePayloads = [
            ['name' => 'Super Admin', 'slug' => 'super_admin', 'created_at' => $now, 'updated_at' => $now],
            ['name' => 'Sales Agent', 'slug' => 'sales_agent', 'created_at' => $now, 'updated_at' => $now],
            ['name' => 'Store Owner', 'slug' => 'store_owner', 'created_at' => $now, 'updated_at' => $now],
            ['name' => 'End User', 'slug' => 'end_user', 'created_at' => $now, 'updated_at' => $now],
        ];

        DB::table('roles')->upsert($rolePayloads, ['slug'], ['name', 'updated_at']);

        $roleIds = DB::table('roles')
            ->whereIn('slug', ['super_admin', 'store_owner', 'end_user'])
            ->pluck('id', 'slug');

        $storeOwnerRoleId = (int) ($roleIds['store_owner'] ?? 0);
        $superAdminRoleId = (int) ($roleIds['super_admin'] ?? 0);
        $endUserRoleId = (int) ($roleIds['end_user'] ?? 0);

        if ($storeOwnerRoleId > 0) {
            $storeOwnerUserIds = DB::table('tenant_users')
                ->where('role', 'owner')
                ->distinct()
                ->pluck('user_id')
                ->map(fn ($id) => (int) $id)
                ->all();

            if (!empty($storeOwnerUserIds)) {
                $ownerRows = array_map(static fn (int $userId): array => [
                    'user_id' => $userId,
                    'role_id' => $storeOwnerRoleId,
                    'created_at' => $now,
                    'updated_at' => $now,
                ], $storeOwnerUserIds);

                DB::table('user_roles')->upsert($ownerRows, ['user_id', 'role_id'], ['updated_at']);
            }
        }

        if ($superAdminRoleId > 0) {
            $superAdminUserIds = DB::table('users')
                ->whereNotExists(function ($query): void {
                    $query->selectRaw('1')
                        ->from('tenant_users')
                        ->whereColumn('tenant_users.user_id', 'users.id')
                        ->where('tenant_users.status', 'active');
                })
                ->pluck('id')
                ->map(fn ($id) => (int) $id)
                ->all();

            if (!empty($superAdminUserIds)) {
                $adminRows = array_map(static fn (int $userId): array => [
                    'user_id' => $userId,
                    'role_id' => $superAdminRoleId,
                    'created_at' => $now,
                    'updated_at' => $now,
                ], $superAdminUserIds);

                DB::table('user_roles')->upsert($adminRows, ['user_id', 'role_id'], ['updated_at']);
            }
        }

        if ($endUserRoleId > 0) {
            $allUserIds = DB::table('users')
                ->pluck('id')
                ->map(fn ($id) => (int) $id)
                ->all();

            if (!empty($allUserIds)) {
                $endUserRows = array_map(static fn (int $userId): array => [
                    'user_id' => $userId,
                    'role_id' => $endUserRoleId,
                    'created_at' => $now,
                    'updated_at' => $now,
                ], $allUserIds);

                DB::table('user_roles')->upsert($endUserRows, ['user_id', 'role_id'], ['updated_at']);
            }
        }
    }

    public function down(): void
    {
        $roleIds = DB::table('roles')
            ->whereIn('slug', ['super_admin', 'sales_agent', 'store_owner', 'end_user'])
            ->pluck('id')
            ->map(fn ($id) => (int) $id)
            ->all();

        if (!empty($roleIds)) {
            DB::table('user_roles')
                ->whereIn('role_id', $roleIds)
                ->delete();
        }

        DB::table('roles')
            ->whereIn('slug', ['super_admin', 'sales_agent', 'store_owner', 'end_user'])
            ->delete();
    }
};
