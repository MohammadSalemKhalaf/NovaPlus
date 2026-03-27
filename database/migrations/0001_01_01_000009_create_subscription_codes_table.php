<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('subscription_codes', function (Blueprint $table) {
            $table->id();
            $table->string('code')->unique();
            $table->integer('duration_months');
            $table->string('note')->nullable();
            $table->foreignId('created_by_admin_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('sold_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('redeemed_at')->nullable();
            $table->foreignId('redeemed_by_subscription_id')->nullable()->constrained('subscriptions')->nullOnDelete();
            $table->string('status')->default('active'); // active, used, expired, canceled
            $table->timestamps();

            $table->index(['code']);
            $table->index(['status']);
            $table->index(['created_by_admin_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('subscription_codes');
    }
};
