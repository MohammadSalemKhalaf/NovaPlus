<?php

use App\Models\Tenant;
use App\Models\User;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;

uses(RefreshDatabase::class);

it('supports end user self-service CRUD and favorites by tenant_id', function (): void {
    $this->seed(RoleSeeder::class);

    $owner = User::query()->create([
        'name' => 'Tenant Owner',
        'email' => 'owner+' . uniqid() . '@novaplus.test',
        'password_hash' => Hash::make('password123'),
        'status' => 'active',
    ]);

    $tenant = Tenant::query()->create([
        'owner_user_id' => $owner->id,
        'name' => 'Tenant One',
        'slug' => 'tenant-one-' . uniqid(),
        'business_mode' => 'product',
        'status' => 'active',
        'primary_language' => 'ar',
        'currency_code' => 'ILS',
        'timezone' => 'Asia/Gaza',
    ]);

    $registerPayload = [
        'name' => 'End User One',
        'email' => 'enduser+' . uniqid() . '@novaplus.test',
        'password' => 'password123',
        'password_confirmation' => 'password123',
    ];

    $register = $this->postJson('/api/v1/enduser/auth/register', $registerPayload);
    $register->assertStatus(201)
        ->assertJsonPath('success', true)
        ->assertJsonPath('data.user.email', $registerPayload['email']);

    $user = User::query()->where('email', $registerPayload['email'])->firstOrFail();

    Sanctum::actingAs($user);

    $this->getJson('/api/v1/enduser/auth/me')
        ->assertOk()
        ->assertJsonPath('success', true)
        ->assertJsonPath('data.email', $registerPayload['email']);

    $this->putJson('/api/v1/enduser/auth/profile', [
        'name' => 'Updated End User',
    ])->assertOk()->assertJsonPath('data.name', 'Updated End User');

    $this->postJson('/api/v1/enduser/favorites', [
        'tenant_id' => $tenant->id,
        'notifications_optin' => false,
    ])->assertStatus(201)->assertJsonPath('success', true);

    $this->putJson('/api/v1/enduser/favorites/' . $tenant->id, [
        'notifications_optin' => true,
    ])->assertOk()->assertJsonPath('success', true);

    $this->getJson('/api/v1/enduser/favorites/check/' . $tenant->id)
        ->assertOk()
        ->assertJsonPath('data.is_favorited', true);

    $this->deleteJson('/api/v1/enduser/auth/profile')
        ->assertOk()
        ->assertJsonPath('success', true);

    $this->assertDatabaseMissing('users', ['id' => $user->id]);
});
