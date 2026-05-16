<?php

namespace App\DTOs\Admin;

use App\Models\User;

class SalesAgentDto
{
    public function __construct(private readonly User $user)
    {
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(): array
    {
        return [
            'id' => (int) $this->user->id,
            'name' => (string) $this->user->name,
            'email' => (string) $this->user->email,
            'status' => (string) $this->user->status,
            'created_at' => optional($this->user->created_at)?->toISOString(),
            'updated_at' => optional($this->user->updated_at)?->toISOString(),
            'created_by' => $this->user->creator ? [
                'id' => (int) $this->user->creator->id,
                'name' => (string) $this->user->creator->name,
                'email' => (string) $this->user->creator->email,
            ] : null,
            'roles' => $this->user->roles
                ->pluck('slug')
                ->map(static fn (string $slug): string => $slug)
                ->values()
                ->all(),
        ];
    }
}
