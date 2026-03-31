<?php

namespace App\Repositories\EndUser;

use App\Models\NotificationPreference;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

class EndUserRepository
{
    /**
     * Find user by email.
     */
    public function findByEmail(string $email): ?User
    {
        return User::query()->where('email', $email)->first();
    }

    /**
     * Create a new end user account.
     */
    public function register(array $data): User
    {
        $user = User::query()->create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password_hash' => Hash::make($data['password']),
            'status' => 'active',
            'email_verified_at' => null,
        ]);

        // Attach end_user global role
        $this->attachEndUserRole($user);

        // Create default notification preferences
        NotificationPreference::create([
            'user_id' => $user->id,
            'email_notifications_optin' => false,
            'email_verified' => false,
            'whatsapp_notifications_optin' => false,
            'preferred_timezone' => 'UTC',
        ]);

        return $user;
    }

    /**
     * Find user by ID.
     */
    public function findById(int $id): ?User
    {
        return User::query()->with(['roles', 'notificationPreferences'])->find($id);
    }

    /**
     * Update user profile.
     */
    public function updateProfile(User $user, array $data): User
    {
        $fillable = [];

        if (isset($data['name'])) {
            $fillable['name'] = $data['name'];
        }

        if (isset($data['email']) && $data['email'] !== $user->email) {
            $fillable['email'] = $data['email'];
        }

        if (isset($data['password'])) {
            $fillable['password_hash'] = Hash::make($data['password']);
        }

        if (!empty($fillable)) {
            $user->update($fillable);
        }

        return $user;
    }

    /**
     * Update last login timestamp.
     */
    public function updateLastLogin(User $user): void
    {
        $user->update(['last_login_at' => now()]);
    }

    /**
     * Delete end user account.
     */
    public function deleteAccount(User $user): void
    {
        $user->tokens()->delete();
        $user->delete();
    }

    /**
     * Attach end_user role to user.
     */
    private function attachEndUserRole(User $user): void
    {
        $endUserRole = \App\Models\Role::query()->where('slug', 'end_user')->first();

        if ($endUserRole) {
            $user->roles()->attach($endUserRole->id);
        }
    }
}
