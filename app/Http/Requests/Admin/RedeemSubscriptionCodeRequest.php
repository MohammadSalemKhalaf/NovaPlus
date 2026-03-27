<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;

class RedeemSubscriptionCodeRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return auth()->check();
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'code' => ['required', 'string', 'exists:subscription_codes,code'],
            'tenant_id' => ['required', 'exists:tenants,id'],
        ];
    }

    public function messages(): array
    {
        return [
            'code.exists' => 'The subscription code is invalid or has already been used.',
        ];
    }
}
