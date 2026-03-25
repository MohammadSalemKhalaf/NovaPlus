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
        $user = User::query()->updateOrCreate(
            ['email' => 'admin@novaplus.test'],
            [
                'name' => 'Test Admin',
                'password_hash' => Hash::make('password123'),
                'status' => 'active',
                'last_login_at' => null,
                'email_verified_at' => null,
            ],
        );

        $tenant = Tenant::query()->updateOrCreate(
            ['slug' => 'novaplus-demo'],
            [
                'owner_user_id' => $user->id,
                'name' => 'NovaPlus Demo',
                'business_mode' => 'product',
                'status' => 'active',
                'primary_language' => 'en',
                'currency_code' => 'USD',
                'timezone' => 'Asia/Hebron',
                'onboarding_completed_at' => null,
            ],
        );

        if ((int) $tenant->owner_user_id !== (int) $user->id) {
            $tenant->owner_user_id = $user->id;
            $tenant->save();
        }

        TenantUser::query()->updateOrCreate(
            [
                'tenant_id' => $tenant->id,
                'user_id' => $user->id,
            ],
            [
                'role' => 'owner',
                'status' => 'active',
            ],
        );
    }
}

