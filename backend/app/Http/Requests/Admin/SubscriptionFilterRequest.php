<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;

class SubscriptionFilterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'status' => ['nullable', 'in:active,suspended,cancelled,expired'],
            'active_only' => ['nullable', 'boolean'],
            'expired_only' => ['nullable', 'boolean'],
            'expiring_days' => ['nullable', 'integer', 'min:1', 'max:365'],
            'created_by_agent_id' => ['nullable', 'integer', 'exists:users,id'],
            'tenant_id' => ['nullable', 'integer', 'exists:tenants,id'],
            'created_from' => ['nullable', 'date_format:Y-m-d'],
            'created_to' => ['nullable', 'date_format:Y-m-d'],
            'business_type_id' => ['nullable', 'integer'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ];
    }
}
