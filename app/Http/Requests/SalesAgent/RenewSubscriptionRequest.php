<?php

namespace App\Http\Requests\SalesAgent;

use Illuminate\Foundation\Http\FormRequest;

class RenewSubscriptionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'tenant_id' => ['required', 'integer', 'exists:tenants,id'],
            'months' => ['nullable', 'integer', 'min:1', 'max:24'],
        ];
    }
}
