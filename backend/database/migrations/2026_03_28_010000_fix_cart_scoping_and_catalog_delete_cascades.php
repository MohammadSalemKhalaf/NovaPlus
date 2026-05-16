<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $this->dropIndexIfExists('carts', 'carts_device_id_status_unique', true);
        $this->dropIndexIfExists('carts', 'carts_device_id_status_index', false);
        $this->dropIndexIfExists('cart_items', 'cart_items_device_id_item_id_unique', true);

        $this->addUniqueIfMissing('carts', 'carts_device_tenant_status_unique', ['device_id', 'tenant_id', 'status']);
        $this->addIndexIfMissing('carts', 'carts_device_tenant_status_index', ['device_id', 'tenant_id', 'status']);
        $this->addUniqueIfMissing('cart_items', 'cart_items_cart_id_item_id_unique', ['cart_id', 'item_id']);

        $this->dropForeignIfExists('items', 'items_category_id_foreign');
        Schema::table('items', function (Blueprint $table): void {
            $table->foreign('category_id')
                ->references('id')
                ->on('categories')
                ->cascadeOnDelete();
        });

        $this->dropForeignIfExists('item_prices', 'item_prices_item_id_foreign');
        Schema::table('item_prices', function (Blueprint $table): void {
            $table->foreign('item_id')
                ->references('id')
                ->on('items')
                ->cascadeOnDelete();
        });

        $this->dropForeignIfExists('item_images', 'item_images_item_id_foreign');
        Schema::table('item_images', function (Blueprint $table): void {
            $table->foreign('item_id')
                ->references('id')
                ->on('items')
                ->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        $this->dropIndexIfExists('carts', 'carts_device_tenant_status_unique', true);
        $this->dropIndexIfExists('carts', 'carts_device_tenant_status_index', false);
        $this->dropIndexIfExists('cart_items', 'cart_items_cart_id_item_id_unique', true);

        $this->addUniqueIfMissing('carts', 'carts_device_id_status_unique', ['device_id', 'status']);
        $this->addIndexIfMissing('carts', 'carts_device_id_status_index', ['device_id', 'status']);
        $this->addUniqueIfMissing('cart_items', 'cart_items_device_id_item_id_unique', ['device_id', 'item_id']);

        $this->dropForeignIfExists('items', 'items_category_id_foreign');
        Schema::table('items', function (Blueprint $table): void {
            $table->foreign('category_id')
                ->references('id')
                ->on('categories')
                ->nullOnDelete();
        });

        $this->dropForeignIfExists('item_prices', 'item_prices_item_id_foreign');
        Schema::table('item_prices', function (Blueprint $table): void {
            $table->foreign('item_id')
                ->references('id')
                ->on('items');
        });

        $this->dropForeignIfExists('item_images', 'item_images_item_id_foreign');
        Schema::table('item_images', function (Blueprint $table): void {
            $table->foreign('item_id')
                ->references('id')
                ->on('items');
        });
    }

    private function dropIndexIfExists(string $table, string $indexName, bool $isUnique): void
    {
        if (!$this->indexExists($table, $indexName)) {
            return;
        }

        Schema::table($table, function (Blueprint $blueprint) use ($indexName, $isUnique): void {
            if ($isUnique) {
                $blueprint->dropUnique($indexName);
                return;
            }

            $blueprint->dropIndex($indexName);
        });
    }

    private function addIndexIfMissing(string $table, string $indexName, array $columns): void
    {
        if ($this->indexExists($table, $indexName)) {
            return;
        }

        Schema::table($table, function (Blueprint $blueprint) use ($columns, $indexName): void {
            $blueprint->index($columns, $indexName);
        });
    }

    private function addUniqueIfMissing(string $table, string $indexName, array $columns): void
    {
        if ($this->indexExists($table, $indexName)) {
            return;
        }

        Schema::table($table, function (Blueprint $blueprint) use ($columns, $indexName): void {
            $blueprint->unique($columns, $indexName);
        });
    }

    private function dropForeignIfExists(string $table, string $constraintName): void
    {
        if (!$this->foreignExists($table, $constraintName)) {
            return;
        }

        Schema::table($table, function (Blueprint $blueprint) use ($constraintName): void {
            $blueprint->dropForeign($constraintName);
        });
    }

    private function indexExists(string $table, string $indexName): bool
    {
        return DB::table('information_schema.statistics')
            ->where('table_schema', DB::getDatabaseName())
            ->where('table_name', $table)
            ->where('index_name', $indexName)
            ->exists();
    }

    private function foreignExists(string $table, string $constraintName): bool
    {
        return DB::table('information_schema.table_constraints')
            ->where('table_schema', DB::getDatabaseName())
            ->where('table_name', $table)
            ->where('constraint_name', $constraintName)
            ->where('constraint_type', 'FOREIGN KEY')
            ->exists();
    }
};
