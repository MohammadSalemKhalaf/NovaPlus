<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;

class TenantControlRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'action' => ['required', 'in:activate,suspend,delete,delete_with_owner,deactivate_owner,activate_owner'],
        ];
    }

    public function messages(): array
    {
        return [
            'action.required' => 'Action is required.',
            'action.in' => 'Action must be one of: activate, suspend, delete, delete_with_owner, deactivate_owner, activate_owner.',
        ];
    }
}
