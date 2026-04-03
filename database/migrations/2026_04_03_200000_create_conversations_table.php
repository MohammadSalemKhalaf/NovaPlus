<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('conversations', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignId('end_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('status', 32)->default('active');
            $table->timestamp('last_message_at')->nullable();
            $table->string('last_message_preview', 255)->nullable();
            $table->timestamps();

            $table->unique(['tenant_id', 'end_user_id'], 'conversations_tenant_end_user_unique');
            $table->index(['tenant_id', 'last_message_at'], 'conversations_tenant_last_message_idx');
            $table->index(['end_user_id', 'last_message_at'], 'conversations_end_user_last_message_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('conversations');
    }
};
