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
            if (!Schema::hasColumn('carts', 'device_id')) {
                $table->string('device_id')->nullable()->after('tenant_id');
            }
        });

        if (Schema::hasColumn('carts', 'session_id')) {
            DB::table('carts')
                ->whereNull('device_id')
                ->update([
                    'device_id' => DB::raw('session_id'),
                ]);
        }

        if (Schema::hasColumn('carts', 'guest_token')) {
            DB::table('carts')
                ->whereNull('device_id')
                ->update([
                    'device_id' => DB::raw('guest_token'),
                ]);
        }

        $this->dropIndexIfExists('carts', 'carts_session_id_status_unique');
        $this->dropIndexIfExists('carts', 'carts_session_id_status_index');
        $this->dropIndexIfExists('carts', 'carts_guest_token_status_unique');
        $this->dropIndexIfExists('carts', 'carts_guest_token_status_index');

        Schema::table('carts', function (Blueprint $table): void {
            if (Schema::hasColumn('carts', 'session_id')) {
                $table->dropColumn('session_id');
            }

            if (Schema::hasColumn('carts', 'guest_token')) {
                $table->dropColumn('guest_token');
            }
        });

        $this->addUniqueIfMissing('carts', 'carts_device_id_status_unique', ['device_id', 'status']);
        $this->addIndexIfMissing('carts', 'carts_device_id_status_index', ['device_id', 'status']);

        Schema::table('cart_items', function (Blueprint $table): void {
            if (!Schema::hasColumn('cart_items', 'device_id')) {
                $table->string('device_id')->nullable()->after('cart_id');
            }
        });

        if (Schema::hasColumn('cart_items', 'session_id')) {
            DB::statement('UPDATE cart_items SET device_id = session_id WHERE device_id IS NULL');
        }

        if (Schema::hasColumn('cart_items', 'guest_token')) {
            DB::statement('UPDATE cart_items SET device_id = guest_token WHERE device_id IS NULL');
        }

        DB::statement('UPDATE cart_items ci JOIN carts c ON c.id = ci.cart_id SET ci.device_id = c.device_id WHERE ci.device_id IS NULL');

        $this->dropIndexIfExists('cart_items', 'cart_items_session_id_item_id_unique');
        $this->dropIndexIfExists('cart_items', 'cart_items_session_id_index');

        Schema::table('cart_items', function (Blueprint $table): void {
            if (Schema::hasColumn('cart_items', 'session_id')) {
                $table->dropColumn('session_id');
            }

            if (Schema::hasColumn('cart_items', 'guest_token')) {
                $table->dropColumn('guest_token');
            }
        });

        $this->addIndexIfMissing('cart_items', 'cart_items_device_id_index', ['device_id']);
        $this->addUniqueIfMissing('cart_items', 'cart_items_device_id_item_id_unique', ['device_id', 'item_id']);
    }

    public function down(): void
    {
        $this->dropIndexIfExists('cart_items', 'cart_items_device_id_item_id_unique');
        $this->dropIndexIfExists('cart_items', 'cart_items_device_id_index');

        Schema::table('cart_items', function (Blueprint $table): void {
            if (Schema::hasColumn('cart_items', 'device_id')) {
                $table->dropColumn('device_id');
            }

            if (!Schema::hasColumn('cart_items', 'session_id')) {
                $table->string('session_id')->nullable()->after('cart_id');
            }
        });

        $this->dropIndexIfExists('carts', 'carts_device_id_status_unique');
        $this->dropIndexIfExists('carts', 'carts_device_id_status_index');

        Schema::table('carts', function (Blueprint $table): void {
            if (Schema::hasColumn('carts', 'device_id')) {
                $table->dropColumn('device_id');
            }

            if (!Schema::hasColumn('carts', 'session_id')) {
                $table->string('session_id')->nullable()->after('tenant_id');
            }
        });

        $this->addUniqueIfMissing('carts', 'carts_session_id_status_unique', ['session_id', 'status']);
        $this->addIndexIfMissing('carts', 'carts_session_id_status_index', ['session_id', 'status']);
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
