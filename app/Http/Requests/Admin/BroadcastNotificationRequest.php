<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class BroadcastNotificationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:255'],
            'body' => ['required', 'string', 'max:5000'],
            'target' => ['required', Rule::in(['all_users', 'role', 'tenant', 'direct_users'])],
            'role' => ['nullable', 'string', 'max:100', 'required_if:target,role', 'exists:roles,slug'],
            'tenant_id' => ['nullable', 'integer', 'min:1', 'exists:tenants,id', 'required_if:target,tenant'],
            'user_ids' => ['nullable', 'array', 'required_if:target,direct_users', 'min:1'],
            'user_ids.*' => ['integer', 'min:1', 'distinct', 'exists:users,id'],
        ];
    }
}
