<?php

namespace App\Http\Requests\Owner;

use Illuminate\Foundation\Http\FormRequest;

class SendOwnerMessageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user('sanctum') !== null;
    }

    public function rules(): array
    {
        return [
            'conversation_id' => ['required', 'integer', 'min:1', 'exists:conversations,id'],
            'body' => ['required', 'string', 'max:5000'],
            'reply_to_message_id' => ['nullable', 'integer', 'min:1', 'exists:conversation_messages,id'],
        ];
    }
}
