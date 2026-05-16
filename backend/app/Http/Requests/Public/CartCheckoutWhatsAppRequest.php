<?php

namespace App\Http\Requests\Public;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;

class CartCheckoutWhatsAppRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, array<int, string>>
     */
    public function rules(): array
    {
        return [
            'X-Device-ID' => ['required', 'string', 'max:255'],
            'X-Tenant-ID' => ['required', 'integer', 'exists:tenants,id'],
        ];
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'X-Device-ID' => (string) $this->header('X-Device-ID', ''),
            'X-Tenant-ID' => $this->header('X-Tenant-ID'),
        ]);
    }

    protected function failedValidation(Validator $validator): void
    {
        throw new HttpResponseException(response()->json([
            'success' => false,
            'message' => 'Validation failed.',
            'errors' => $validator->errors()->toArray(),
        ], 422));
    }
}
