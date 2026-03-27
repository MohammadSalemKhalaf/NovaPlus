<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;

class CreateSubscriptionCodeRequest extends FormRequest
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
            'duration_months' => ['required', 'integer', 'min:1', 'max:120'],
            'code' => ['required', 'string', 'unique:subscription_codes,code'],
            'note' => ['nullable', 'string', 'max:500'],
            'sold_by_user_id' => ['nullable', 'exists:users,id'],
        ];
    }
}
