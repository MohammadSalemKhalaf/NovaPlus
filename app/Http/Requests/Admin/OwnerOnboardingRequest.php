<?php

namespace App\Http\Requests\Admin;

use Illuminate\Database\Query\Builder;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class OwnerOnboardingRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'owner_name' => ['required', 'string', 'max:255'],
            'owner_email' => ['required_if:activation_channel,email', 'email', 'unique:users,email'],
            'password' => ['required_if:activation_channel,email', 'min:8'],
            'tenant_name' => ['required', 'string', 'max:255'],
            'tenant_slug' => ['required', 'string', 'max:255', 'unique:tenants,slug', 'regex:/^[a-z0-9-]+$/'],
            'business_mode' => ['required', 'in:product,service'],
            'business_type_id' => [
                'required',
                'integer',
                Rule::exists('business_types', 'id')->where(fn (Builder $query) => $query->where('status', 'active')),
            ],
            'tenant_whatsapp_number' => ['nullable', 'string', 'max:32'],
            'activation_channel' => ['required', 'in:email,internal,whatsapp'],
        ];
    }

    public function messages(): array
    {
        return [
            'owner_email.required_if' => 'Email is required when activation channel is email.',
            'password.required_if' => 'Password is required when activation channel is email.',
            'tenant_slug.regex' => 'Tenant slug must contain only lowercase letters, numbers, and hyphens.',
        ];
    }
}
