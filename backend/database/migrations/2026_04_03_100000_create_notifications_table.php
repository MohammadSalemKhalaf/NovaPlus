<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notifications', function (Blueprint $table): void {
            $table->id();
            $table->string('type', 100);
            $table->string('title', 255);
            $table->text('body');
            $table->string('notifiable_type', 100);
            $table->unsignedBigInteger('notifiable_id');
            $table->string('related_type', 100)->nullable();
            $table->unsignedBigInteger('related_id')->nullable();
            $table->string('channel', 50)->default('database');
            $table->string('priority', 20)->default('normal');
            $table->string('status', 20)->default('queued');
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['notifiable_type', 'notifiable_id'], 'notifications_notifiable_idx');
            $table->index(['related_type', 'related_id'], 'notifications_related_idx');
            $table->index(['type', 'status'], 'notifications_type_status_idx');
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notifications');
    }
};
