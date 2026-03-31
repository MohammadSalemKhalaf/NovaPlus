<?php

use App\Models\Item;
use App\Models\Role;
use App\Models\Tenant;
use App\Models\User;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;

uses(RefreshDatabase::class);

it('merges guest cart on end-user login when device_id is provided', function (): void {
    $this->seed(RoleSeeder::class);

    $owner = User::query()->create([
        'name' => 'Tenant Owner',
        'email' => 'owner+' . uniqid() . '@novaplus.test',
        'password_hash' => Hash::make('password123'),
        'status' => 'active',
    ]);

    $tenant = Tenant::query()->create([
        'owner_user_id' => $owner->id,
        'name' => 'Guest Cart Tenant',
        'slug' => 'guest-cart-' . uniqid(),
        'business_mode' => 'product',
        'status' => 'active',
        'primary_language' => 'ar',
        'currency_code' => 'ILS',
        'timezone' => 'Asia/Gaza',
    ]);

    $endUser = User::query()->create([
        'name' => 'End User',
        'email' => 'enduser+' . uniqid() . '@novaplus.test',
        'password_hash' => Hash::make('password123'),
        'status' => 'active',
    ]);

    $endUserRole = Role::query()->where('slug', 'end_user')->firstOrFail();
    $endUser->roles()->attach($endUserRole->id);

    $item = Item::query()->create([
        'tenant_id' => $tenant->id,
        'category_id' => null,
        'name' => 'Guest Item',
        'slug' => 'guest-item-' . uniqid(),
        'description' => 'test',
        'status' => 'active',
        'visibility' => 'public',
        'created_by_user_id' => $owner->id,
        'updated_by_user_id' => $owner->id,
    ]);

    $deviceId = 'device-' . uniqid();

    $this->withHeader('X-Device-ID', $deviceId)
        ->postJson('/api/v1/public/cart/items', [
            'item_id' => $item->id,
            'quantity' => 1,
        ])->assertStatus(200);

    $login = $this->postJson('/api/v1/enduser/auth/login', [
        'email' => $endUser->email,
        'password' => 'password123',
        'device_id' => $deviceId,
    ]);

    $login->assertOk()
        ->assertJsonPath('success', true)
        ->assertJsonPath('data.user.email', $endUser->email)
        ->assertJsonPath('data.cart_merge.device_id', $deviceId);
});
