<?php

namespace App\Http\Requests\EndUser;

use Illuminate\Foundation\Http\FormRequest;

class SendEndUserProductMessageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user('sanctum') !== null;
    }

    public function rules(): array
    {
        return [
            'conversation_id' => ['required', 'integer', 'min:1', 'exists:conversations,id'],
            'product_id' => ['required', 'integer', 'min:1'],
            'product_name' => ['required', 'string', 'max:255'],
            'product_price' => ['required', 'numeric', 'min:0'],
            'product_image' => ['required', 'string', 'max:2048', 'url'],
            'reply_to_message_id' => ['nullable', 'integer', 'min:1', 'exists:conversation_messages,id'],
        ];
    }
}
