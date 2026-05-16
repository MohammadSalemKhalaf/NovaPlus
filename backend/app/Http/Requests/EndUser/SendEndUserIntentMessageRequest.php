<?php

namespace App\Http\Requests\EndUser;

use Illuminate\Foundation\Http\FormRequest;

class SendEndUserIntentMessageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user('sanctum') !== null;
    }

    public function rules(): array
    {
        return [
            'tenant_id' => ['required', 'integer', 'min:1', 'exists:tenants,id'],
            'intent_type' => ['required', 'string', 'in:order_request'],
            'reply_to_message_id' => ['nullable', 'integer', 'min:1', 'exists:conversation_messages,id'],
        ];
    }
}
