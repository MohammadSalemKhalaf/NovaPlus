<?php

namespace App\Http\Requests\Owner;

use App\Helpers\PhoneHelper;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;

class UpdateProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['nullable', 'string', 'max:255'],
            'tenant_whatsapp_number' => [
                'nullable',
                'string',
                'max:30',
                function (string $attribute, mixed $value, \Closure $fail): void {
                    $normalized = PhoneHelper::normalize((string) $value);

                    if (! PhoneHelper::isValid($normalized)) {
                        $fail('The whatsapp number must be a valid Palestinian mobile number.');
                    }
                },
            ],
            'password' => ['nullable', 'string', 'min:8'],
        ];
    }

    protected function prepareForValidation(): void
    {
        if ($this->filled('tenant_whatsapp_number')) {
            $this->merge([
                'tenant_whatsapp_number' => PhoneHelper::normalize((string) $this->input('tenant_whatsapp_number')),
            ]);
        }
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
