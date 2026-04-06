<?php

namespace App\Http\Requests\Admin;

use Illuminate\Database\Query\Builder;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Validation\Rule;

class TenantStoreRequest extends FormRequest
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
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['required', 'string', 'max:255', 'unique:tenants,slug'],
            'business_mode' => ['required', 'string', 'in:product,service'],
            'business_type_id' => [
                'required',
                'integer',
                Rule::exists('business_types', 'id')->where(fn (Builder $query) => $query->where('status', 'active')),
            ],
            'primary_language' => ['required', 'string', 'max:32'],
            'currency_code' => ['required', 'string', 'max:16'],
            'timezone' => ['required', 'string', 'max:64'],
            'whatsapp_number' => ['nullable', 'string', 'min:8', 'max:15'],
            'store_image' => ['nullable', 'string', 'max:2048'],
        ];
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

