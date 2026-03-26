<?php

namespace App\Http\Requests\Admin;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Validation\Rule;

class CategoryStoreRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null && $this->tenantId() !== null;
    }

    public function rules(): array
    {
        $tenantId = $this->tenantId();

        return [
            'parent_id' => [
                'nullable',
                'integer',
                Rule::exists('categories', 'id')->where(function ($query) use ($tenantId): void {
                    $query->where('tenant_id', $tenantId);
                }),
            ],
            'name' => ['required', 'string', 'max:255'],
            'slug' => [
                'required',
                'string',
                'max:255',
                Rule::unique('categories', 'slug')->where(function ($query) use ($tenantId): void {
                    $query->where('tenant_id', $tenantId);
                }),
            ],
            'description' => ['nullable', 'string'],
            'sort_order' => ['required', 'integer', 'min:0'],
            'status' => ['required', 'string', 'in:active,archived'],
        ];
    }

    private function tenantId(): ?int
    {
        $tenant = $this->request->attributes->get('tenant');

        if (is_object($tenant) && method_exists($tenant, 'getKey')) {
            return (int) $tenant->getKey();
        }

        $tenantId = $this->request->attributes->get('tenant_id');

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

