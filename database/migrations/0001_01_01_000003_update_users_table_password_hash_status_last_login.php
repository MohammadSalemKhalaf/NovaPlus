<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('status')->default('active');
            $table->timestamp('last_login_at')->nullable();
            // Transitional: we load existing hashes from the legacy `password` column first.
            $table->string('password_hash')->nullable();
        });

        // Move existing auth column to the schema-aligned column name.
        DB::table('users')
            ->whereNotNull('password')
            ->update([
                'password_hash' => DB::raw('password'),
            ]);

        // Align with Phase 1 schema: `password_hash` must be non-null in production.
        // For PostgreSQL we can enforce it safely without adding extra dependencies.
        if (DB::connection()->getDriverName() === 'pgsql') {
            DB::statement('ALTER TABLE users ALTER COLUMN password_hash SET NOT NULL');
        }

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('password');
        });

        // Phase 1 `users` schema does not include remember-token.
        if (Schema::hasColumn('users', 'remember_token')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('remember_token');
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('password')->nullable();
        });

        DB::table('users')
            ->whereNotNull('password_hash')
            ->update([
                'password' => DB::raw('password_hash'),
            ]);

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('password_hash');
            $table->dropColumn('status');
            $table->dropColumn('last_login_at');
        });

        // Restore Laravel remember-token column for reversibility.
        if (!Schema::hasColumn('users', 'remember_token')) {
            Schema::table('users', function (Blueprint $table) {
                $table->rememberToken();
            });
        }
    }
};

