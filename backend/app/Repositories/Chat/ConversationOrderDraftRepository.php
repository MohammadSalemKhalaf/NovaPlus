<?php

namespace App\Repositories\Chat;

use App\Models\ConversationOrderDraft;

class ConversationOrderDraftRepository
{
    public function create(int $conversationId, int $tenantId, int $endUserId, array $items, string $status = 'draft'): ConversationOrderDraft
    {
        return ConversationOrderDraft::create([
            'conversation_id' => $conversationId,
            'tenant_id' => $tenantId,
            'end_user_id' => $endUserId,
            'items' => $items,
            'status' => $status,
        ]);
    }

    public function findByConversation(int $conversationId): ?ConversationOrderDraft
    {
        return ConversationOrderDraft::where('conversation_id', $conversationId)
            ->where('status', 'draft')
            ->latest()
            ->first();
    }

    public function updateStatus(int $draftId, string $status): ConversationOrderDraft
    {
        $draft = ConversationOrderDraft::findOrFail($draftId);
        $draft->update(['status' => $status]);
        return $draft;
    }
}
