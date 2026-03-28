<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\Schema;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * @var array<int, string>
     */
    protected $fillable = [
        'name',
        'email',
        'password_hash',
        'status',
        'created_by',
        'last_login_at',
        'email_verified_at',
    ];

    /**
     * @var array<int, string>
     */
    protected $hidden = [
        'password_hash',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'last_login_at' => 'datetime',
            'password_hash' => 'hashed',
        ];
    }

    public function getAuthPasswordName(): string
    {
        return 'password_hash';
    }

    public function tenantUsers(): HasMany
    {
        return $this->hasMany(TenantUser::class, 'user_id');
    }

    public function carts(): HasMany
    {
        return $this->hasMany(Cart::class, 'user_id');
    }

    public function cartItems(): HasMany
    {
        return $this->hasMany(CartItem::class, 'user_id');
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(self::class, 'created_by');
    }

    public function createdUsers(): HasMany
    {
        return $this->hasMany(self::class, 'created_by');
    }

    public function ownedTenants(): HasMany
    {
        return $this->hasMany(Tenant::class, 'owner_user_id');
    }

    public function tenants(): BelongsToMany
    {
        return $this->belongsToMany(Tenant::class, 'tenant_users', 'user_id', 'tenant_id')
            ->withPivot(['role', 'status'])
            ->withTimestamps();
    }

    public function roles(): BelongsToMany
    {
        return $this->belongsToMany(Role::class, 'user_roles', 'user_id', 'role_id')
            ->withTimestamps();
    }

    public function isSuperAdmin(): bool
    {
        return $this->hasRole('super_admin');
    }

    public function isSalesAgent(): bool
    {
        return $this->hasRole('sales_agent');
    }

    public function isStoreOwner(): bool
    {
        return $this->hasRole('store_owner');
    }

    public function isEndUser(): bool
    {
        return $this->hasRole('end_user');
    }

    public function hasRole(string $slug): bool
    {
        $normalizedSlug = trim(strtolower($slug));

        if ($normalizedSlug === '') {
            return false;
        }

        if (Schema::hasTable('roles') && Schema::hasTable('user_roles')) {
            if ($this->relationLoaded('roles')) {
                /** @var \Illuminate\Database\Eloquent\Collection<int, Role> $roles */
                $roles = $this->roles;

                if ($roles->contains(fn (Role $role) => $role->slug === $normalizedSlug)) {
                    return true;
                }
            } elseif ($this->roles()->where('slug', $normalizedSlug)->exists()) {
                return true;
            }
        }

        // Backward compatibility for legacy ownership checks before role rollout.
        if ($normalizedSlug === 'store_owner') {
            return $this->tenantUsers()
                ->where('role', 'owner')
                ->where('status', 'active')
                ->exists();
        }

        if ($normalizedSlug === 'super_admin') {
            return !$this->tenantUsers()->where('status', 'active')->exists();
        }

        if ($normalizedSlug === 'end_user') {
            return !$this->hasRole('super_admin') && !$this->hasRole('store_owner');
        }

        return false;
    }

    public function favoriteStores(): HasMany
    {
        return $this->hasMany(UserFavoriteStore::class, 'user_id');
    }

    public function storeViews(): HasMany
    {
        return $this->hasMany(UserStoreView::class, 'user_id');
    }

    public function notificationPreferences(): HasOne
    {
        return $this->hasOne(NotificationPreference::class, 'user_id');
    }
}

