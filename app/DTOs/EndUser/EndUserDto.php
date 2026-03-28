<?php

namespace App\DTOs\EndUser;

use App\Models\User;

class EndUserDto
{
    public function __construct(private readonly User $user)
    {
        $this->user->loadMissing(['roles']);
    }

    public function toArray(): array
    {
        return [
            'id' => (int) $this->user->id,
            'name' => $this->user->name,
            'email' => $this->user->email,
            'status' => $this->user->status,
            'email_verified' => $this->user->email_verified_at !== null,
            'last_login_at' => $this->user->last_login_at?->toIso8601String(),
            'created_at' => $this->user->created_at?->toIso8601String(),
            'roles' => $this->user->roles->pluck('slug')->toArray(),
        ];
    }
}
