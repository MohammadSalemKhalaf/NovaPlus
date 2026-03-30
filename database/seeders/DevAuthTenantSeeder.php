<?php

namespace Database\Seeders;

use App\Models\BusinessType;
use App\Models\Role;
use App\Models\Subscription;
use App\Models\Tenant;
use App\Models\TenantUser;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DevAuthTenantSeeder extends Seeder
{
    public function run(): void
    {
        $businessTypeId = BusinessType::query()
            ->where('slug', 'general-trading')
            ->where('status', 'active')
            ->value('id');

        $admin = User::query()->updateOrCreate(
            ['email' => 'admin@novaplus.test'],
            [
                'name' => 'Test Admin',
                'password_hash' => Hash::make('password123'),
                'status' => 'active',
                'last_login_at' => null,
                'email_verified_at' => null,
            ],
        );

        $salesAgent = User::query()->updateOrCreate(
            ['email' => 'agent@novaplus.test'],
            [
                'name' => 'Test Sales Agent',
                'password_hash' => Hash::make('password123'),
                'status' => 'active',
                'last_login_at' => null,
                'email_verified_at' => null,
            ],
        );

        $owner = User::query()->updateOrCreate(
            ['email' => 'owner@novaplus.test'],
            [
                'name' => 'Demo Owner',
                'password_hash' => Hash::make('password123'),
                'status' => 'active',
                'last_login_at' => null,
                'email_verified_at' => now(),
            ],
        );

        $tenant = Tenant::query()->updateOrCreate(
            ['slug' => 'novaplus-demo'],
            [
                'owner_user_id' => $owner->id,
                'name' => 'NovaPlus Demo',
                'business_mode' => 'product',
                'business_type_id' => $businessTypeId,
                'status' => 'active',
                'primary_language' => 'en',
                'currency_code' => 'USD',
                'timezone' => 'Asia/Hebron',
                'whatsapp_number' => '+970599000111',
                'onboarding_completed_at' => null,
            ],
        );

        if ((int) $tenant->owner_user_id !== (int) $owner->id) {
            $tenant->owner_user_id = $owner->id;
            $tenant->save();
        }

        TenantUser::query()
            ->where('tenant_id', $tenant->id)
            ->where('user_id', $admin->id)
            ->delete();

        TenantUser::query()->updateOrCreate(
            [
                'tenant_id' => $tenant->id,
                'user_id' => $owner->id,
            ],
            [
                'role' => 'owner',
                'status' => 'active',
            ],
        );

        Subscription::query()->updateOrCreate(
            [
                'tenant_id' => $tenant->id,
                'plan_code' => 'starter',
            ],
            [
                'status' => 'active',
                'starts_at' => now()->subDay(),
                'ends_at' => now()->addMonth(),
                'billing_cycle' => 'monthly',
            ],
        );

        $rolesBySlug = Role::query()
            ->whereIn('slug', ['super_admin', 'sales_agent', 'store_owner', 'end_user'])
            ->pluck('id', 'slug');

        $ownerRoleIds = array_values(array_filter([
            $rolesBySlug['store_owner'] ?? null,
            $rolesBySlug['end_user'] ?? null,
        ]));

        if (!empty($ownerRoleIds)) {
            $owner->roles()->syncWithoutDetaching($ownerRoleIds);
        }

        $adminRoleIds = array_values(array_filter([
            $rolesBySlug['super_admin'] ?? null,
            $rolesBySlug['end_user'] ?? null,
        ]));

        if (!empty($adminRoleIds)) {
            $admin->roles()->syncWithoutDetaching($adminRoleIds);
        }

        $salesAgentRoleIds = array_values(array_filter([
            $rolesBySlug['sales_agent'] ?? null,
            $rolesBySlug['end_user'] ?? null,
        ]));

        if (!empty($salesAgentRoleIds)) {
            $salesAgent->roles()->syncWithoutDetaching($salesAgentRoleIds);
        }
    }
}

