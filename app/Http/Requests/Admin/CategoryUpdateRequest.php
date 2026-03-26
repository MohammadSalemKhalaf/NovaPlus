<?php

namespace App\Http\Requests\Admin;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Validation\Rule;

class CategoryUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null && $this->tenantId() !== null;
    }

    public function rules(): array
    {
        $tenantId = $this->tenantId();
        $categoryId = $this->currentCategoryId();

        return [
            'parent_id' => [
                'nullable',
                'integer',
                Rule::exists('categories', 'id')->where(function ($query) use ($tenantId): void {
                    $query->where('tenant_id', $tenantId);
                }),
            ],
            'name' => ['sometimes', 'string', 'max:255'],
            'slug' => [
                'sometimes',
                'string',
                'max:255',
                Rule::unique('categories', 'slug')
                    ->where(function ($query) use ($tenantId): void {
                        $query->where('tenant_id', $tenantId);
                    })
                    ->ignore($categoryId),
            ],
            'description' => ['sometimes', 'nullable', 'string'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
            'status' => ['sometimes', 'string', 'in:active,archived'],
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

    private function currentCategoryId(): mixed
    {
        $routeParam = $this->route('category')
            ?? $this->route('id')
            ?? $this->route('category_id');

        if (is_object($routeParam) && method_exists($routeParam, 'getKey')) {
            return $routeParam->getKey();
        }

        return is_numeric($routeParam) ? (int) $routeParam : null;
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

