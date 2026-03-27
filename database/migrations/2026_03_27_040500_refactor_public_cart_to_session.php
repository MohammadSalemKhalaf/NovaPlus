<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('carts', function (Blueprint $table): void {
            if (!Schema::hasColumn('carts', 'session_id')) {
                $table->string('session_id')->nullable()->after('tenant_id');
            }
        });

        if (Schema::hasColumn('carts', 'guest_token')) {
            DB::table('carts')
                ->whereNull('session_id')
                ->update([
                    'session_id' => DB::raw('guest_token'),
                ]);
        }

        $this->dropIndexIfExists('carts', 'carts_guest_token_status_unique');
        $this->dropIndexIfExists('carts', 'carts_guest_token_status_index');

        Schema::table('carts', function (Blueprint $table): void {
            if (Schema::hasColumn('carts', 'guest_token')) {
                $table->dropColumn('guest_token');
            }
        });

        $this->addUniqueIfMissing('carts', 'carts_session_id_status_unique', ['session_id', 'status']);
        $this->addIndexIfMissing('carts', 'carts_session_id_status_index', ['session_id', 'status']);

        Schema::table('cart_items', function (Blueprint $table): void {
            if (!Schema::hasColumn('cart_items', 'session_id')) {
                $table->string('session_id')->nullable()->after('cart_id');
            }
        });

        DB::statement('UPDATE cart_items ci JOIN carts c ON c.id = ci.cart_id SET ci.session_id = c.session_id WHERE ci.session_id IS NULL');

        $this->addIndexIfMissing('cart_items', 'cart_items_session_id_index', ['session_id']);
        $this->addUniqueIfMissing('cart_items', 'cart_items_session_id_item_id_unique', ['session_id', 'item_id']);
        $this->addIndexIfMissing('cart_items', 'cart_items_cart_id_item_id_index', ['cart_id', 'item_id']);
    }

    public function down(): void
    {
        $this->dropIndexIfExists('cart_items', 'cart_items_session_id_item_id_unique');
        $this->dropIndexIfExists('cart_items', 'cart_items_session_id_index');
        $this->dropIndexIfExists('cart_items', 'cart_items_cart_id_item_id_index');

        Schema::table('cart_items', function (Blueprint $table): void {
            if (Schema::hasColumn('cart_items', 'session_id')) {
                $table->dropColumn('session_id');
            }
        });

        $this->dropIndexIfExists('carts', 'carts_session_id_status_unique');
        $this->dropIndexIfExists('carts', 'carts_session_id_status_index');

        Schema::table('carts', function (Blueprint $table): void {
            if (!Schema::hasColumn('carts', 'guest_token')) {
                $table->string('guest_token')->nullable()->after('tenant_id');
            }
        });

        DB::table('carts')
            ->whereNull('guest_token')
            ->update([
                'guest_token' => DB::raw('session_id'),
            ]);

        Schema::table('carts', function (Blueprint $table): void {
            if (Schema::hasColumn('carts', 'session_id')) {
                $table->dropColumn('session_id');
            }

            $table->unique(['guest_token', 'status'], 'carts_guest_token_status_unique');
            $table->index(['guest_token', 'status'], 'carts_guest_token_status_index');
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

    private function addUniqueIfMissing(string $tableName, string $indexName, array $columns): void
    {
        $exists = DB::select('SHOW INDEX FROM `'.$tableName.'` WHERE Key_name = ?', [$indexName]);

        if ($exists !== []) {
            return;
        }

        Schema::table($tableName, function (Blueprint $table) use ($columns, $indexName): void {
            $table->unique($columns, $indexName);
        });
    }
};
