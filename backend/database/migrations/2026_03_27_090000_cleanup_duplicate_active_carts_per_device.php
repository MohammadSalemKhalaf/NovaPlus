<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $latestActivePerDevice = DB::table('carts')
            ->selectRaw('MAX(id) as keep_id, device_id')
            ->where('status', 'active')
            ->whereNotNull('device_id')
            ->groupBy('device_id');

        $duplicateCartIds = DB::table('carts as carts')
            ->joinSub($latestActivePerDevice, 'latest', function ($join): void {
                $join->on('carts.device_id', '=', 'latest.device_id');
            })
            ->where('carts.status', 'active')
            ->whereColumn('carts.id', '<>', 'latest.keep_id')
            ->pluck('carts.id');

        if ($duplicateCartIds->isEmpty()) {
            return;
        }

        DB::table('carts')
            ->whereIn('id', $duplicateCartIds->all())
            ->delete();
    }

    public function down(): void
    {
    }
};
