<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;

class SubscriptionActionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'action' => ['required', 'in:activate,suspend,cancel,renew'],
            'months' => ['nullable', 'integer', 'min:1', 'max:60'],
        ];
    }

    public function messages(): array
    {
        return [
            'action.required' => 'Action is required.',
            'action.in' => 'Action must be one of: activate, suspend, cancel, renew.',
            'months.min' => 'Months must be at least 1.',
            'months.max' => 'Months cannot exceed 60.',
        ];
    }
}
