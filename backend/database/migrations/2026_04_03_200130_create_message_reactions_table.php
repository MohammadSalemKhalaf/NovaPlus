<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('message_reactions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('message_id')->constrained('conversation_messages')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('reaction_type', 32);
            $table->timestamps();

            // Unique constraint: one reaction per user per message
            $table->unique(['message_id', 'user_id'], 'message_reactions_unique');

            // Indexes for lookups
            $table->index(['message_id', 'reaction_type'], 'message_reactions_message_reaction_idx');
            $table->index(['user_id', 'created_at'], 'message_reactions_user_created_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('message_reactions');
    }
};
