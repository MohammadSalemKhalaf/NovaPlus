<?php

namespace App\Repositories\Chat;

use App\Models\Conversation;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

class ConversationRepository
{
    public function startOrCreate(int $tenantId, int $endUserId, string $contextType = 'general'): Conversation
    {
        $conversation = Conversation::query()->firstOrCreate(
            [
                'tenant_id' => $tenantId,
                'end_user_id' => $endUserId,
            ],
            [
                'status' => 'active',
                'context_type' => $contextType,
            ]
        );

        if ($contextType === 'product' && $conversation->context_type !== 'product') {
            $conversation->forceFill(['context_type' => $contextType])->save();
        }

        return $conversation;
    }

    public function findForEndUser(int $conversationId, int $endUserId): ?Conversation
    {
        return Conversation::query()
            ->whereKey($conversationId)
            ->where('end_user_id', $endUserId)
            ->select([
                'id',
                'tenant_id',
                'end_user_id',
                'status',
                'context_type',
                'last_message_at',
                'last_message_preview',
                'created_at',
                'updated_at',
            ])
            ->first();
    }

    public function findForOwner(int $conversationId, int $ownerUserId): ?Conversation
    {
        return Conversation::query()
            ->where('conversations.id', $conversationId)
            ->where(function ($query) use ($ownerUserId): void {
                $query
                    ->whereHas('tenant', function ($tenantQuery) use ($ownerUserId): void {
                        $tenantQuery->where('owner_user_id', $ownerUserId);
                    })
                    ->orWhereHas('tenant.tenantUsers', function ($tenantUsersQuery) use ($ownerUserId): void {
                        $tenantUsersQuery
                            ->where('user_id', $ownerUserId)
                            ->where('role', 'owner')
                            ->where('status', 'active');
                    });
            })
            ->select([
                'conversations.id',
                'conversations.tenant_id',
                'conversations.end_user_id',
                'conversations.status',
                'conversations.context_type',
                'conversations.last_message_at',
                'conversations.last_message_preview',
                'conversations.created_at',
                'conversations.updated_at',
            ])
            ->first();
    }

    public function findForOwnerAndTenant(int $conversationId, int $ownerUserId, int $tenantId): ?Conversation
    {
        return Conversation::query()
            ->whereKey($conversationId)
            ->where('tenant_id', $tenantId)
            ->where(function ($query) use ($ownerUserId): void {
                $query
                    ->whereHas('tenant', function ($tenantQuery) use ($ownerUserId): void {
                        $tenantQuery->where('owner_user_id', $ownerUserId);
                    })
                    ->orWhereHas('tenant.tenantUsers', function ($tenantUsersQuery) use ($ownerUserId): void {
                        $tenantUsersQuery
                            ->where('user_id', $ownerUserId)
                            ->where('role', 'owner')
                            ->where('status', 'active');
                    });
            })
            ->select([
                'id',
                'tenant_id',
                'end_user_id',
                'status',
                'context_type',
                'last_message_at',
                'last_message_preview',
                'created_at',
                'updated_at',
            ])
            ->first();
    }

    public function paginateForOwnerTenant(int $tenantId, int $perPage = 15): LengthAwarePaginator
    {
        return Conversation::query()
            ->where('tenant_id', $tenantId)
            ->select([
                'id',
                'tenant_id',
                'end_user_id',
                'status',
                'context_type',
                'last_message_at',
                'last_message_preview',
                'created_at',
                'updated_at',
            ])
            ->with([
                'endUser' => static function ($query): void {
                    $query->select([
                        'id',
                        'name',
                        'email',
                    ]);
                },
            ])
            ->withCount([
                'messages as unread_count' => static function ($query): void {
                    $query
                        ->where('sender_type', 'end_user')
                        ->where('is_read', false);
                },
            ])
            ->orderByDesc('last_message_at')
            ->orderByDesc('id')
            ->paginate($perPage);
    }

    public function touchLastMessage(int $conversationId, string $preview): void
    {
        Conversation::query()
            ->whereKey($conversationId)
            ->update([
                'last_message_at' => now(),
                'last_message_preview' => $preview,
                'updated_at' => now(),
            ]);
    }
}
