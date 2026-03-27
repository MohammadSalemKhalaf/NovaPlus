<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Validation\ValidationException;

class TenantUser extends Model
{
    use HasFactory;

    protected static function booted(): void
    {
        static::creating(function (TenantUser $tenantUser): void {
            if ($tenantUser->role !== 'owner') {
                return;
            }

            $tenantHasOwner = self::query()
                ->where('tenant_id', $tenantUser->tenant_id)
                ->where('role', 'owner')
                ->exists();

            if ($tenantHasOwner) {
                throw ValidationException::withMessages([
                    'role' => ['This tenant already has an owner.'],
                ]);
            }

            $userOwnsTenant = self::query()
                ->where('user_id', $tenantUser->user_id)
                ->where('role', 'owner')
                ->exists();

            if ($userOwnsTenant) {
                throw ValidationException::withMessages([
                    'user_id' => ['This user already owns another tenant.'],
                ]);
            }
        });
    }

    /**
     * @var array<int, string>
     */
    protected $fillable = [
        'tenant_id',
        'user_id',
        'role',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'role' => 'string',
            'status' => 'string',
        ];
    }

    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class, 'tenant_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}

