<?php

namespace App\Http\Requests\Admin;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;

class SetActiveItemPriceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null && $this->tenantId() !== null;
    }

    public function rules(): array
    {
        return [
            'currency_code' => ['required', 'string', 'size:3'],
            'base_price_amount' => ['required', 'string', 'regex:/^\d+(\.\d{1,2})?$/'],
            'compare_at_price_amount' => ['nullable', 'string', 'regex:/^\d+(\.\d{1,2})?$/'],
            'effective_from' => ['nullable', 'date'],
            'effective_to' => ['nullable', 'date', 'after_or_equal:effective_from'],
        ];
    }

    private function tenantId(): ?int
    {
        $tenant = $this->attributes->get('tenant');

        if (is_object($tenant) && method_exists($tenant, 'getKey')) {
            return (int) $tenant->getKey();
        }

        $tenantId = $this->attributes->get('tenant_id');

        return is_numeric($tenantId) ? (int) $tenantId : null;
    }

    protected function failedAuthorization(): void
    {
        throw new HttpResponseException(response()->json([
            'success' => false,
            'message' => 'You are not authorized to access this resource.',
        ], 403));
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
