<?php

namespace App\Http\Requests\EndUser;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Contracts\Validation\Validator;

class FavoritesRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'tenant_id' => ['required', 'integer', 'exists:tenants,id'],
            'notifications_optin' => ['sometimes', 'boolean'],
        ];
    }

    public function messages(): array
    {
        return [
            'tenant_id.exists' => 'The selected store does not exist.',
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
