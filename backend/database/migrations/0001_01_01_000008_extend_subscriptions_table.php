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
        Schema::table('subscriptions', function (Blueprint $table) {
            // Add new columns for onboarding and activation tracking
            $table->string('code')->nullable()->unique()->after('plan_code');
            $table->string('activation_channel')->nullable()->after('code'); // email, internal, whatsapp
            $table->foreignId('created_by_admin_id')->nullable()->constrained('users')->nullOnDelete()->after('activation_channel');
            $table->foreignId('sold_by_user_id')->nullable()->constrained('users')->nullOnDelete()->after('created_by_admin_id');
            $table->timestamp('redeemed_at')->nullable()->after('sold_by_user_id');
            $table->foreignId('activated_by_user_id')->nullable()->constrained('users')->nullOnDelete()->after('redeemed_at');
            $table->string('activation_code')->nullable()->unique()->after('activated_by_user_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('subscriptions', function (Blueprint $table) {
            $table->dropUnique(['code']);
            $table->dropUnique(['activation_code']);
            $table->dropForeignKeyIfExists(['created_by_admin_id']);
            $table->dropForeignKeyIfExists(['sold_by_user_id']);
            $table->dropForeignKeyIfExists(['activated_by_user_id']);
            $table->dropColumn([
                'code',
                'activation_channel',
                'created_by_admin_id',
                'sold_by_user_id',
                'redeemed_at',
                'activated_by_user_id',
                'activation_code',
            ]);
        });
    }
};
