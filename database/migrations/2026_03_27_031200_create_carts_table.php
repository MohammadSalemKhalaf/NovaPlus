<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('carts', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->string('guest_token');
            $table->string('status')->default('active');
            $table->timestamps();

            $table->unique(['guest_token', 'status']);
            $table->index(['guest_token', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('carts');
    }
};
