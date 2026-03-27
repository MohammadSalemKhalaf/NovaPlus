<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $this->addIndexIfMissing('items', 'items_tenant_id_index', ['tenant_id']);
        $this->addIndexIfMissing('items', 'items_category_id_index', ['category_id']);
        $this->addIndexIfMissing('items', 'items_status_index', ['status']);
        $this->addIndexIfMissing('items', 'items_visibility_index', ['visibility']);

        $this->addIndexIfMissing('item_prices', 'item_prices_item_id_index', ['item_id']);
        $this->addIndexIfMissing('item_prices', 'item_prices_pricing_status_index', ['pricing_status']);

        $this->addIndexIfMissing('categories', 'categories_tenant_id_index', ['tenant_id']);
    }

    public function down(): void
    {
        $this->dropIndexIfExists('items', 'items_tenant_id_index');
        $this->dropIndexIfExists('items', 'items_category_id_index');
        $this->dropIndexIfExists('items', 'items_status_index');
        $this->dropIndexIfExists('items', 'items_visibility_index');

        $this->dropIndexIfExists('item_prices', 'item_prices_item_id_index');
        $this->dropIndexIfExists('item_prices', 'item_prices_pricing_status_index');

        $this->dropIndexIfExists('categories', 'categories_tenant_id_index');
    }

    private function addIndexIfMissing(string $tableName, string $indexName, array $columns): void
    {
        $exists = DB::select('SHOW INDEX FROM `'.$tableName.'` WHERE Key_name = ?', [$indexName]);

        if ($exists !== []) {
            return;
        }

        Schema::table($tableName, function (Blueprint $table) use ($columns, $indexName): void {
            $table->index($columns, $indexName);
        });
    }

    private function dropIndexIfExists(string $tableName, string $indexName): void
    {
        $exists = DB::select('SHOW INDEX FROM `'.$tableName.'` WHERE Key_name = ?', [$indexName]);

        if ($exists === []) {
            return;
        }

        Schema::table($tableName, function (Blueprint $table) use ($indexName): void {
            $table->dropIndex($indexName);
        });
    }
};
