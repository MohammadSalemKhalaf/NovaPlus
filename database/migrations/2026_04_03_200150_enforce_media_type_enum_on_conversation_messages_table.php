<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void
    {
        DB::statement("ALTER TABLE conversation_messages MODIFY media_type ENUM('image', 'voice') NULL AFTER media_url");
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE conversation_messages MODIFY media_type VARCHAR(16) NULL AFTER media_url');
    }
};
