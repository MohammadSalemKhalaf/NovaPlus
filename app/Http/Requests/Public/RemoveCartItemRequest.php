<?php

namespace App\Http\Requests\Public;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;

class RemoveCartItemRequest extends FormRequest
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
            'item_id' => ['required', 'integer', 'exists:items,id'],
        ];
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'X-Device-ID' => (string) $this->header('X-Device-ID', ''),
            'item_id' => $this->route('item_id'),
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
