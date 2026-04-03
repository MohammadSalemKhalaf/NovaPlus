<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('conversation_order_drafts', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('conversation_id')->constrained('conversations')->cascadeOnDelete();
            $table->foreignId('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignId('end_user_id')->constrained('users')->cascadeOnDelete();
            $table->json('items');
            $table->string('status', 32)->default('draft');
            $table->timestamps();

            // Indexes for lookups
            $table->index(['tenant_id', 'created_at'], 'order_drafts_tenant_created_idx');
            $table->index(['conversation_id', 'status'], 'order_drafts_conversation_status_idx');
            $table->index(['end_user_id', 'status'], 'order_drafts_end_user_status_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('conversation_order_drafts');
    }
};
