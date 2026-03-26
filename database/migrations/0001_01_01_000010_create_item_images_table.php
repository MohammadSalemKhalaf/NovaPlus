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
        Schema::create('item_images', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tenant_id')->constrained('tenants');
            $table->foreignId('item_id')->constrained('items');
            $table->string('storage_path');
            $table->string('alt_text')->nullable();
            $table->integer('sort_order')->default(0);
            $table->boolean('is_primary')->default(false);
            $table->timestamps();

            $table->index(['tenant_id', 'item_id']);
            $table->index(['tenant_id', 'is_primary']);
        });

        // Add FK after item_images exists to avoid circular dependency during creation.
        Schema::table('items', function (Blueprint $table) {
            $table->foreign('primary_image_id')
                ->references('id')
                ->on('item_images')
                ->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('items', function (Blueprint $table) {
            $table->dropForeign(['primary_image_id']);
        });

        Schema::dropIfExists('item_images');
    }
};

