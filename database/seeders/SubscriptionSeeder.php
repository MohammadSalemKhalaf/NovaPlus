<?php

namespace Database\Seeders;

use App\Models\Subscription;
use App\Models\Tenant;
use Carbon\Carbon;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class SubscriptionSeeder extends Seeder
{
    use WithoutModelEvents;

    public function run(): void
    {
        $tenants = Tenant::whereHas('owner')->inRandomOrder()->limit(10)->get();

        if ($tenants->count() < 3) {
            return;
        }

        // Create active subscriptions
        $activeTenants = $tenants->slice(0, 3);
        foreach ($activeTenants as $tenant) {
            Subscription::firstOrCreate(
                ['tenant_id' => $tenant->id],
                [
                    'status' => 'active',
                    'starts_at' => Carbon::now()->subDays(30),
                    'ends_at' => Carbon::now()->addDays(60),
                    'renewal_date' => Carbon::now()->addDays(60),
                ]
            );
        }

        // Create expiring soon subscriptions (5 days left)
        $expiringTenants = $tenants->slice(3, 3);
        foreach ($expiringTenants as $tenant) {
            Subscription::firstOrCreate(
                ['tenant_id' => $tenant->id],
                [
                    'status' => 'active',
                    'starts_at' => Carbon::now()->subDays(85),
                    'ends_at' => Carbon::now()->addDays(5),
                    'renewal_date' => Carbon::now()->addDays(5),
                ]
            );
        }

        // Create expired subscriptions
        $expiredTenants = $tenants->slice(6, 4);
        foreach ($expiredTenants as $tenant) {
            Subscription::firstOrCreate(
                ['tenant_id' => $tenant->id],
                [
                    'status' => 'expired',
                    'starts_at' => Carbon::now()->subDays(100),
                    'ends_at' => Carbon::now()->subDays(10),
                    'renewal_date' => Carbon::now()->subDays(10),
                ]
            );
        }
    }
}
