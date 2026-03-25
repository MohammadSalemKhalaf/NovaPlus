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
            $table->string('password_hash')->nullable();
        });

        // Move existing auth column to the schema-aligned column name.
        DB::table('users')
            ->whereNotNull('password')
            ->update([
                'password_hash' => DB::raw('password'),
            ]);

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('password');
        });
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
    }
};

