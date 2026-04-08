<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('end_user_orders', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('tenant_id')->constrained('tenants')->cascadeOnDelete();
            $table->foreignId('cart_id')->nullable()->constrained('carts')->nullOnDelete();
            $table->string('channel', 32)->default('whatsapp');
            $table->string('status', 32)->default('submitted_whatsapp');
            $table->string('currency_code', 8)->default('USD');
            $table->decimal('subtotal', 12, 2)->default(0);
            $table->string('device_id', 255)->nullable();
            $table->text('whatsapp_url')->nullable();
            $table->text('message_preview')->nullable();
            $table->timestamp('submitted_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'created_at'], 'euo_user_created_idx');
            $table->index(['tenant_id', 'created_at'], 'euo_tenant_created_idx');
            $table->index(['status', 'created_at'], 'euo_status_created_idx');
        });

        Schema::create('end_user_order_items', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('order_id')->constrained('end_user_orders')->cascadeOnDelete();
            $table->foreignId('item_id')->nullable()->constrained('items')->nullOnDelete();
            $table->string('item_name_snapshot', 255);
            $table->unsignedInteger('quantity')->default(1);
            $table->decimal('unit_price_snapshot', 12, 2)->default(0);
            $table->decimal('line_total', 12, 2)->default(0);
            $table->timestamps();

            $table->index(['order_id', 'created_at'], 'euoi_order_created_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('end_user_order_items');
        Schema::dropIfExists('end_user_orders');
    }
};
