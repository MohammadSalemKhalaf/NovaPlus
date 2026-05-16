<?php

namespace App\Http\Requests\EndUser;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Contracts\Validation\Validator;

class PreferencesRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'email_notifications_optin' => ['sometimes', 'boolean'],
            'whatsapp_notifications_optin' => ['sometimes', 'boolean'],
            'preferred_city' => ['sometimes', 'string', 'max:255'],
            'preferred_timezone' => ['sometimes', 'string', 'timezone'],
            'notification_categories' => ['sometimes', 'array'],
            'notification_categories.*' => ['string', 'max:255'],
        ];
    }

    protected function failedValidation(Validator $validator)
    {
        $response = response()->json([
            'success' => false,
            'message' => 'Validation failed',
            'data' => null,
            'meta' => ['errors' => $validator->errors()],
        ], 422);

        throw new \Illuminate\Validation\ValidationException($validator, $response);
    }
}
