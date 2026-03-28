<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notification_preferences', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->boolean('email_notifications_optin')->default(false);
            $table->boolean('email_verified')->default(false);
            $table->boolean('whatsapp_notifications_optin')->default(false);
            $table->string('preferred_city')->nullable();
            $table->string('preferred_timezone')->default('UTC');
            $table->json('notification_categories')->default('{}'); // future: order updates, promotions, etc.
            $table->timestamps();

            // Index for efficient lookups
            $table->index('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_preferences');
    }
};
