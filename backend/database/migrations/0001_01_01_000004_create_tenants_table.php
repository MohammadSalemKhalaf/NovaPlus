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
        Schema::create('tenants', function (Blueprint $table) {
            $table->id();
            $table->foreignId('owner_user_id')->constrained('users');
            $table->string('name');
            $table->string('slug')->unique();
            $table->string('business_mode'); // product, service (hybrid reserved later)
            $table->string('status'); // draft, active, suspended, archived
            $table->string('primary_language');
            $table->string('currency_code');
            $table->string('timezone');
            $table->timestamp('onboarding_completed_at')->nullable();
            $table->timestamps();

            $table->index(['owner_user_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('tenants');
    }
};

