<?php

namespace App\Http\Requests\Admin;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;

class OfferUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null && $this->tenantId() !== null;
    }

    public function rules(): array
    {
        return [
            'title' => ['sometimes', 'string', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string'],
            'image' => ['sometimes', 'nullable', 'string', 'max:1000'],
            'discount_type' => ['sometimes', 'nullable', 'string', 'in:percentage,fixed'],
            'discount_value' => ['sometimes', 'nullable', 'numeric', 'min:0'],
            'starts_at' => ['sometimes', 'nullable', 'date'],
            'ends_at' => ['sometimes', 'nullable', 'date', 'after_or_equal:starts_at'],
            'status' => ['sometimes', 'string', 'in:draft,active,archived'],
        ];
    }

    private function tenantId(): ?int
    {
        $tenant = request()->attributes->get('tenant');

        if (is_object($tenant) && method_exists($tenant, 'getKey')) {
            return (int) $tenant->getKey();
        }

        $tenantId = request()->attributes->get('tenant_id');

        return is_numeric($tenantId) ? (int) $tenantId : null;
    }

    protected function failedAuthorization(): void
    {
        throw new HttpResponseException(response()->json([
            'success' => false,
            'message' => 'You are not authorized to access this resource.',
            'data' => (object) [],
            'meta' => (object) [],
        ], 403));
    }

    protected function failedValidation(Validator $validator): void
    {
        throw new HttpResponseException(response()->json([
            'success' => false,
            'message' => 'Validation failed.',
            'errors' => $validator->errors()->toArray(),
            'data' => (object) [],
            'meta' => (object) [],
        ], 422));
    }
}
