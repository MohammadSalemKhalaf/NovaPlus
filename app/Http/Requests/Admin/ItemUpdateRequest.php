<?php

namespace App\Http\Requests\Admin;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Validation\Rule;

class ItemUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null && $this->tenantId() !== null;
    }

    public function rules(): array
    {
        $tenantId = $this->tenantId();
        $itemId = $this->currentItemId();

        return [
            'category_id' => [
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
                Rule::unique('items', 'slug')
                    ->where(function ($query) use ($tenantId): void {
                        $query->where('tenant_id', $tenantId);
                    })
                    ->ignore($itemId),
            ],
            'short_description' => ['sometimes', 'nullable', 'string'],
            'long_description' => ['sometimes', 'nullable', 'string'],
            'item_type' => ['sometimes', 'string', 'in:product,service'],
            'status' => ['sometimes', 'string', 'in:draft,active,archived'],
            'visibility' => ['sometimes', 'string', 'in:public,hidden'],
            'primary_image_id' => [
                'nullable',
                'integer',
                Rule::exists('item_images', 'id')->where(function ($query) use ($tenantId, $itemId): void {
                    $query->where('tenant_id', $tenantId);
                    if ($itemId !== null) {
                        $query->where('item_id', $itemId);
                    }
                }),
            ],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
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

    private function currentItemId(): mixed
    {
        $routeParam = $this->route('item')
            ?? $this->route('id')
            ?? $this->route('item_id');

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

