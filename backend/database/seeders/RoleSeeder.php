<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class RoleSeeder extends Seeder
{
    public function run(): void
    {
        $now = now();

        DB::table('roles')->upsert([
            ['name' => 'Super Admin', 'slug' => 'super_admin', 'created_at' => $now, 'updated_at' => $now],
            ['name' => 'Sales Agent', 'slug' => 'sales_agent', 'created_at' => $now, 'updated_at' => $now],
            ['name' => 'Store Owner', 'slug' => 'store_owner', 'created_at' => $now, 'updated_at' => $now],
            ['name' => 'End User', 'slug' => 'end_user', 'created_at' => $now, 'updated_at' => $now],
        ], ['slug'], ['name', 'updated_at']);
    }
}
