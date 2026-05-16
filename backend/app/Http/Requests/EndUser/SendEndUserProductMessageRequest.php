<?php

namespace App\Http\Requests\EndUser;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SendEndUserProductMessageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user('sanctum') !== null;
    }

    public function rules(): array
    {
        $tenantId = (int) $this->input('tenant_id', 0);
        $productRule = Rule::exists('items', 'id');

        if ($tenantId > 0) {
            $productRule->where('tenant_id', $tenantId);
        }

        return [
            'tenant_id' => ['nullable', 'integer', 'min:1', 'required_without:conversation_id', 'exists:tenants,id'],
            'conversation_id' => ['nullable', 'integer', 'min:1', 'required_without:tenant_id', 'exists:conversations,id'],
            'product_id' => ['required', 'integer', 'min:1', $productRule],
            'reply_to_message_id' => ['nullable', 'integer', 'min:1', 'exists:conversation_messages,id'],
        ];
    }
}
