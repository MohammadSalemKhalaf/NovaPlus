<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('conversations', function (Blueprint $table): void {
            $table->string('context_type', 32)->default('general')->after('status');
            $table->index(['tenant_id', 'context_type'], 'conversations_context_type_idx');
        });
    }

    public function down(): void
    {
        Schema::table('conversations', function (Blueprint $table): void {
            $table->dropIndex('conversations_context_type_idx');
            $table->dropColumn('context_type');
        });
    }
};
