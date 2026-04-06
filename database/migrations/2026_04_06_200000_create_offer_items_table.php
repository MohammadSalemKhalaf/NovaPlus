<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('offer_items')) {
            return;
        }

        Schema::create('offer_items', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('offer_id')->constrained('offers')->cascadeOnDelete();
            $table->foreignId('item_id')->constrained('items')->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['offer_id', 'item_id'], 'offer_items_offer_item_unique');
            $table->index(['item_id', 'offer_id'], 'offer_items_item_offer_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('offer_items');
    }
};
