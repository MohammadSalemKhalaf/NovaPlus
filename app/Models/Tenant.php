<?php

namespace App\Models;

use App\Helpers\PhoneHelper;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Tenant extends Model
{
    use HasFactory;

    /**
     * @var array<int, string>
     */
    protected $fillable = [
        'owner_user_id',
        'name',
        'slug',
        'business_mode',
        'business_type_id',
        'status',
        'primary_language',
        'currency_code',
        'timezone',
        'whatsapp_number',
        'onboarding_completed_at',
    ];

    protected function casts(): array
    {
        return [
            'business_mode' => 'string',
            'business_type_id' => 'integer',
            'status' => 'string',
            'onboarding_completed_at' => 'datetime',
        ];
    }

    /**
     * Automatically normalize WhatsApp number on set
     */
    public function setWhatsappNumberAttribute(?string $value): void
    {
        $this->attributes['whatsapp_number'] = PhoneHelper::normalize($value);
    }

    /**
     * Get normalized WhatsApp number with country code prefix
     */
    public function getFormattedWhatsappNumber(): ?string
    {
        return PhoneHelper::format($this->whatsapp_number);
    }

    /**
     * Get WhatsApp URL for this tenant with an optional message
     */
    public function getWhatsAppUrl(string $message = ''): ?string
    {
        return PhoneHelper::getWhatsAppUrl($this->whatsapp_number, $message);
    }

    public function businessType(): BelongsTo
    {
        return $this->belongsTo(BusinessType::class, 'business_type_id');
    }

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_user_id');
    }

    public function tenantUsers(): HasMany
    {
        return $this->hasMany(TenantUser::class, 'tenant_id');
    }

    public function users(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'tenant_users', 'tenant_id', 'user_id')
            ->withPivot(['role', 'status'])
            ->withTimestamps();
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(Subscription::class, 'tenant_id');
    }

    public function latestSubscription(): HasOne
    {
        return $this->hasOne(Subscription::class, 'tenant_id')->latestOfMany('id');
    }

    public function categories(): HasMany
    {
        return $this->hasMany(Category::class, 'tenant_id');
    }

    public function items(): HasMany
    {
        return $this->hasMany(Item::class, 'tenant_id');
    }

    public function carts(): HasMany
    {
        return $this->hasMany(Cart::class, 'tenant_id');
    }

    public function conversations(): HasMany
    {
        return $this->hasMany(Conversation::class, 'tenant_id');
    }
}

