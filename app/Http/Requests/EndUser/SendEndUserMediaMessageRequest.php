<?php

namespace App\Http\Requests\EndUser;

use Illuminate\Foundation\Http\FormRequest;

class SendEndUserMediaMessageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user('sanctum') !== null;
    }

    public function rules(): array
    {
        return [
            'conversation_id' => ['required', 'integer', 'min:1', 'exists:conversations,id'],
            'media_url' => ['required', 'string', 'max:2048', 'url'],
            'media_type' => ['required', 'string', 'in:image,voice'],
            'reply_to_message_id' => ['nullable', 'integer', 'min:1', 'exists:conversation_messages,id'],
        ];
    }
}
