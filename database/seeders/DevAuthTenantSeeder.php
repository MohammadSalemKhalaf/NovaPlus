<?php

namespace Database\Seeders;

use App\Models\Tenant;
use App\Models\TenantUser;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DevAuthTenantSeeder extends Seeder
{
    public function run(): void
    {
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
                'status' => 'active',
                'primary_language' => 'en',
                'currency_code' => 'USD',
                'timezone' => 'Asia/Hebron',
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
    }
}

