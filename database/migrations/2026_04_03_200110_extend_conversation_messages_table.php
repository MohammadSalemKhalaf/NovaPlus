<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('conversation_messages', function (Blueprint $table): void {
            // Support rich media in messages
            $table->string('media_url')->nullable()->after('body');
            $table->string('media_type')->nullable()->after('media_url');

            // Support product inquiries and structured metadata
            $table->json('metadata')->nullable()->after('media_type');

            // Support reply threads
            $table->foreignId('reply_to_message_id')->nullable()->constrained('conversation_messages')->cascadeOnDelete()->after('metadata');

            // Add index for reply_to lookups
            $table->index(['conversation_id', 'reply_to_message_id'], 'conversation_messages_reply_to_idx');
        });
    }

    public function down(): void
    {
        Schema::table('conversation_messages', function (Blueprint $table): void {
            $table->dropIndex('conversation_messages_reply_to_idx');
            $table->dropForeign(['reply_to_message_id']);
            $table->dropColumn(['media_url', 'media_type', 'metadata', 'reply_to_message_id']);
        });
    }
};
