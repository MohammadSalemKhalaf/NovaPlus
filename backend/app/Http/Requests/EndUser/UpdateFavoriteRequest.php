<?php

namespace App\Http\Requests\EndUser;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;

class UpdateFavoriteRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'notifications_optin' => ['required', 'boolean'],
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
