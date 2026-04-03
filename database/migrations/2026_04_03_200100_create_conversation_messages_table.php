<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('conversation_messages', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('conversation_id')->constrained('conversations')->cascadeOnDelete();
            $table->string('sender_type', 16);
            $table->foreignId('sender_id')->constrained('users')->cascadeOnDelete();
            $table->string('message_type', 16)->default('text');
            $table->text('body');
            $table->boolean('is_read')->default(false);
            $table->timestamp('read_at')->nullable();
            $table->timestamps();

            $table->index(['conversation_id', 'id'], 'conversation_messages_conversation_id_idx');
            $table->index(['conversation_id', 'is_read', 'sender_type'], 'conversation_messages_read_sender_idx');
            $table->index(['sender_id', 'created_at'], 'conversation_messages_sender_created_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('conversation_messages');
    }
};
