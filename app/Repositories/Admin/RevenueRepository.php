<?php

namespace App\Repositories\Admin;

use App\Models\Subscription;
use Illuminate\Support\Facades\DB;

class RevenueRepository
{
    /**
     * Get total revenue across all subscriptions.
     */
    public function getTotalRevenue(): float
    {
        return (float) Subscription::query()
            ->where('status', 'active')
            ->count() * 29.99; // Assuming standard plan pricing
    }

    /**
     * Get revenue from currently active subscriptions.
     */
    public function getActiveSubscriptionsRevenue(): float
    {
        return (float) Subscription::query()
            ->where('status', 'active')
            ->where('starts_at', '<=', now())
            ->where('ends_at', '>', now())
            ->count() * 29.99;
    }

    /**
     * Get revenue for the current month.
     */
    public function getMonthlyRevenue(): float
    {
        return (float) Subscription::query()
            ->where('status', 'active')
            ->whereMonth('starts_at', now()->month)
            ->whereYear('starts_at', now()->year)
            ->count() * 29.99;
    }

    /**
     * Get revenue by sales agent.
     */
    public function getRevenueByAgent(?int $salesAgentId = null, ?string $dateFrom = null, ?string $dateTo = null): array
    {
        $query = Subscription::query()
            ->join('users', 'subscriptions.created_by_admin_id', '=', 'users.id')
            ->whereHas('createdByAdmin', fn ($q) => $q->whereHas('roles', fn ($r) => $r->where('slug', 'sales_agent')))
            ->where('subscriptions.status', 'active');

        if ($salesAgentId !== null) {
            $query->where('subscriptions.created_by_admin_id', $salesAgentId);
        }

        if ($dateFrom !== null) {
            $query->where('subscriptions.created_at', '>=', $dateFrom);
        }

        if ($dateTo !== null) {
            $query->where('subscriptions.created_at', '<=', $dateTo);
        }

        return $query->groupBy('created_by_admin_id', 'users.id', 'users.name', 'users.email')
            ->select(
                'created_by_admin_id',
                'users.id',
                'users.name',
                'users.email',
                DB::raw('COUNT(*) as total_subscriptions'),
                DB::raw('COUNT(*) * 29.99 as total_revenue')
            )
            ->orderByDesc(DB::raw('COUNT(*) * 29.99'))
            ->get()
            ->map(fn ($row) => [
                'user_id' => (int) $row->id,
                'name' => $row->name,
                'email' => $row->email,
                'total_subscriptions' => (int) $row->total_subscriptions,
                'total_revenue' => (float) $row->total_revenue,
            ])
            ->toArray();
    }

    /**
     * Get subscription counts by status.
     */
    public function getSubscriptionCountsByStatus(): array
    {
        return [
            'active' => Subscription::where('status', 'active')->where('starts_at', '<=', now())->where('ends_at', '>', now())->count(),
            'expired' => Subscription::where('status', 'active')->where('ends_at', '<=', now())->count(),
            'expiring_7_days' => Subscription::where('status', 'active')
                ->whereBetween('ends_at', [now(), now()->addDays(7)])
                ->count(),
            'expiring_30_days' => Subscription::where('status', 'active')
                ->whereBetween('ends_at', [now(), now()->addDays(30)])
                ->count(),
        ];
    }
}
