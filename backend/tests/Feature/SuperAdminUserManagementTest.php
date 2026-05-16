<?php

use App\Models\Role;
use App\Models\User;
use Database\Seeders\RoleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;

uses(RefreshDatabase::class);

it('allows super admin to list show update and delete users', function (): void {
    $this->seed(RoleSeeder::class);

    $superAdmin = User::query()->create([
        'name' => 'Super Admin',
        'email' => 'superadmin+' . uniqid() . '@novaplus.test',
        'password_hash' => Hash::make('password123'),
        'status' => 'active',
    ]);

    $targetUser = User::query()->create([
        'name' => 'Managed User',
        'email' => 'managed+' . uniqid() . '@novaplus.test',
        'password_hash' => Hash::make('password123'),
        'status' => 'active',
    ]);

    $superAdminRole = Role::query()->where('slug', 'super_admin')->firstOrFail();
    $endUserRole = Role::query()->where('slug', 'end_user')->firstOrFail();

    $superAdmin->roles()->attach($superAdminRole->id);
    $targetUser->roles()->attach($endUserRole->id);

    Sanctum::actingAs($superAdmin);

    $this->getJson('/api/v1/admin/users?role=end_user')
        ->assertOk()
        ->assertJsonPath('success', true);

    $this->getJson('/api/v1/admin/users/' . $targetUser->id)
        ->assertOk()
        ->assertJsonPath('success', true)
        ->assertJsonPath('data.user.id', $targetUser->id);

    $this->putJson('/api/v1/admin/users/' . $targetUser->id, [
        'name' => 'Managed User Updated',
        'status' => 'inactive',
    ])->assertOk()
      ->assertJsonPath('success', true)
      ->assertJsonPath('data.user.name', 'Managed User Updated')
      ->assertJsonPath('data.user.status', 'inactive');

    $this->deleteJson('/api/v1/admin/users/' . $targetUser->id)
        ->assertOk()
        ->assertJsonPath('success', true)
        ->assertJsonPath('data.deleted', true);

    $this->assertDatabaseMissing('users', ['id' => $targetUser->id]);
});
