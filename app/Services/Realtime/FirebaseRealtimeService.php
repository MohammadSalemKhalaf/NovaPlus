<?php

namespace App\Services\Realtime;

use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Contract\Database;

class FirebaseRealtimeService
{
    public function pushMessage(int $conversationId, int $messageId, array $payload): void
    {
        $this->write(
            path: sprintf('conversations/%d/messages/%d', $conversationId, $messageId),
            payload: $payload,
            eventType: 'message_pushed',
            context: [
                'tenant_id' => $payload['tenant_id'] ?? null,
                'conversation_id' => $conversationId,
                'message_id' => $messageId,
            ],
            successLog: '[REALTIME] message pushed'
        );
    }

    /**
     * @param array<string, mixed> $payload
     */
    public function pushReactionUpdate(int $conversationId, int $messageId, array $payload): void
    {
        $this->write(
            path: sprintf('conversations/%d/messages/%d/reactions', $conversationId, $messageId),
            payload: $payload,
            eventType: 'reaction_updated',
            context: [
                'tenant_id' => $payload['tenant_id'] ?? null,
                'conversation_id' => $conversationId,
                'message_id' => $messageId,
            ],
            successLog: '[REALTIME] reaction updated'
        );
    }

    /**
     * @param array<string, mixed> $payload
     */
    public function pushConversationRead(int $conversationId, array $payload): void
    {
        $this->write(
            path: sprintf('conversations/%d/meta/read', $conversationId),
            payload: $payload,
            eventType: 'conversation_read',
            context: [
                'tenant_id' => $payload['tenant_id'] ?? null,
                'conversation_id' => $conversationId,
            ],
            successLog: '[REALTIME] conversation read updated'
        );
    }

    /**
     * @param array<string, mixed> $payload
     */
    public function pushNotificationUpdate(int $userId, array $payload): void
    {
        $this->write(
            path: sprintf('users/%d/notifications/unread_count', $userId),
            payload: $payload,
            eventType: 'notification_updated',
            context: [
                'tenant_id' => $payload['tenant_id'] ?? null,
                'user_id' => $userId,
                'notification_id' => $payload['notification_id'] ?? null,
            ],
            successLog: '[REALTIME] notification pushed'
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @param array<string, mixed> $context
     */
    private function write(string $path, array $payload, string $eventType, array $context, string $successLog): void
    {
        if (!$this->isEnabled()) {
            return;
        }

        try {
            $database = $this->database();

            if ($database === null) {
                return;
            }

            $database->getReference($path)->set($payload);

            Log::info($successLog, array_merge($context, [
                'event_type' => $eventType,
                'firebase_path' => $path,
            ]));
        } catch (\Throwable $exception) {
            Log::error('[REALTIME ERROR]', array_merge($context, [
                'event_type' => $eventType,
                'firebase_path' => $path,
                'error' => $exception->getMessage(),
            ]));
        }
    }

    private function database(): ?Database
    {
        try {
            /** @var Database $database */
            $database = app(Database::class);

            return $database;
        } catch (\Throwable $exception) {
            Log::error('[REALTIME ERROR]', [
                'event_type' => 'firebase_database_bootstrap',
                'error' => $exception->getMessage(),
            ]);

            return null;
        }
    }

    private function isEnabled(): bool
    {
        if (!config('firebase.enabled', false)) {
            return false;
        }

        $credentials = (string) config('firebase.projects.app.credentials', '');
        $databaseUrl = (string) config('firebase.projects.app.database.url', '');

        if ($credentials === '' || $databaseUrl === '') {
            return false;
        }

        if (!str_starts_with($credentials, '/') && !str_starts_with($credentials, './')) {
            $credentials = base_path($credentials);
        }

        return is_file($credentials);
    }
}
