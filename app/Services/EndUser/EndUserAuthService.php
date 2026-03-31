<?php

namespace App\Services\EndUser;

use App\DTOs\EndUser\EndUserDto;
use App\Repositories\EndUser\EndUserRepository;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

class EndUserAuthService
{
    public function __construct(
        private EndUserRepository $userRepository
    ) {}

    /**
     * Register a new end user.
     */
    public function register(array $data): array
    {
        // Check if email already exists
        if ($this->userRepository->findByEmail($data['email'])) {
            throw new \InvalidArgumentException('User with this email already exists');
        }

        // Create user
        $user = $this->userRepository->register($data);

        // Generate API token
        $token = $user->createToken('auth_token')->plainTextToken;

        return [
            'user' => new EndUserDto($user),
            'token' => $token,
        ];
    }

    /**
     * Login user with email and password.
     */
    public function login(string $email, string $password): array
    {
        $user = $this->userRepository->findByEmail($email);

        if (!$user || !Hash::check($password, $user->password_hash)) {
            throw new \InvalidArgumentException('Invalid credentials');
        }

        if ($user->status !== 'active') {
            throw new \InvalidArgumentException('Account is not active');
        }

        // Update last login
        $this->userRepository->updateLastLogin($user);

        // Generate API token
        $token = $user->createToken('auth_token')->plainTextToken;

        return [
            'user' => new EndUserDto($user),
            'token' => $token,
        ];
    }

    /**
     * Logout user (revoke all tokens).
     */
    public function logout(User $user): void
    {
        $user->tokens()->delete();
    }

    /**
     * Get user profile.
     */
    public function getProfile(User $user): EndUserDto
    {
        $user->loadMissing(['roles', 'notificationPreferences']);
        return new EndUserDto($user);
    }

    /**
     * Update user profile.
     */
    public function updateProfile(User $user, array $data): EndUserDto
    {
        // Check if email is taken by another user
        if (isset($data['email']) && $data['email'] !== $user->email) {
            if ($this->userRepository->findByEmail($data['email'])) {
                throw new \InvalidArgumentException('Email is already taken');
            }
        }

        $user = $this->userRepository->updateProfile($user, $data);
        $user->loadMissing(['roles', 'notificationPreferences']);

        return new EndUserDto($user);
    }

    /**
     * Delete user account.
     */
    public function deleteAccount(User $user): void
    {
        $this->userRepository->deleteAccount($user);
    }
}
