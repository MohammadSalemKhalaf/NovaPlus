<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tenants', function (Blueprint $table): void {
            $table->foreignId('business_type_id')->nullable()->after('business_mode')->constrained('business_types')->nullOnDelete();
            $table->string('whatsapp_number')->nullable()->after('timezone');

            $table->index(['business_type_id']);
        });
    }

    public function down(): void
    {
        Schema::table('tenants', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('business_type_id');
            $table->dropColumn('whatsapp_number');
        });
    }
};
