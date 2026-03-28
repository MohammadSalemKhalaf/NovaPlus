<?php

namespace App\Repositories\Admin;

use App\Models\User;
use Illuminate\Support\Facades\DB;

class SalesAgentAnalyticsRepository
{
    /**
     * Get performance metrics for a single sales agent.
     */
    public function getAgentMetrics(int $agentId): ?array
    {
        $agent = User::query()
            ->where('id', $agentId)
            ->whereHas('roles', fn ($q) => $q->where('slug', 'sales_agent'))
            ->first();

        if (! $agent) {
            return null;
        }

        $tenantsCount = $this->getTenantsCountForAgent($agentId);
        $activeSubscriptions = $this->getActiveSubscriptionsForAgent($agentId);
        $totalRevenue = $this->getTotalRevenueForAgent($agentId);
        $expiredSubscriptions = $this->getExpiredSubscriptionsForAgent($agentId);

        return [
            'user_id' => $agent->id,
            'name' => $agent->name,
            'email' => $agent->email,
            'tenants_count' => $tenantsCount,
            'active_subscriptions_count' => $activeSubscriptions,
            'total_revenue' => $totalRevenue,
            'active_revenue' => $activeSubscriptions * 29.99,
            'expired_subscriptions_count' => $expiredSubscriptions,
        ];
    }

    /**
     * Get top performing agents.
     */
    public function getTopAgents(int $limit = 10): array
    {
        return User::query()
            ->whereHas('roles', fn ($q) => $q->where('slug', 'sales_agent'))
            ->with('roles')
            ->get()
            ->map(function (User $agent) {
                $metrics = $this->getAgentMetrics($agent->id);
                return $metrics ? array_merge($metrics, [
                    'performance_score' => $this->calculatePerformanceScore($metrics),
                ]) : null;
            })
            ->filter()
            ->sortByDesc('performance_score')
            ->take($limit)
            ->values()
            ->toArray();
    }

    /**
     * Get tenants count for a sales agent.
     */
    private function getTenantsCountForAgent(int $agentId): int
    {
        return DB::table('subscriptions')
            ->where('created_by_admin_id', $agentId)
            ->distinct('tenant_id')
            ->count('tenant_id');
    }

    /**
     * Get active subscriptions count for a sales agent.
     */
    private function getActiveSubscriptionsForAgent(int $agentId): int
    {
        return DB::table('subscriptions')
            ->where('created_by_admin_id', $agentId)
            ->where('status', 'active')
            ->where('starts_at', '<=', now())
            ->where('ends_at', '>', now())
            ->count();
    }

    /**
     * Get total revenue for a sales agent.
     */
    private function getTotalRevenueForAgent(int $agentId): float
    {
        return (float) DB::table('subscriptions')
            ->where('created_by_admin_id', $agentId)
            ->where('status', 'active')
            ->count() * 29.99;
    }

    /**
     * Get expired subscriptions count for a sales agent.
     */
    private function getExpiredSubscriptionsForAgent(int $agentId): int
    {
        return DB::table('subscriptions')
            ->where('created_by_admin_id', $agentId)
            ->where('status', 'active')
            ->where('ends_at', '<=', now())
            ->count();
    }

    /**
     * Calculate performance score.
     */
    private function calculatePerformanceScore(array $metrics): float
    {
        $totalSubscriptions = $metrics['active_subscriptions_count'] + $metrics['expired_subscriptions_count'];

        if ($totalSubscriptions === 0) {
            return 0.0;
        }

        $subscriptionScore = min($metrics['active_subscriptions_count'] / 100 * 40, 40);
        $revenueScore = min($metrics['active_revenue'] / 10000 * 40, 40);
        $retentionRate = $metrics['active_subscriptions_count'] / $totalSubscriptions;
        $retentionScore = $retentionRate * 20;

        return round($subscriptionScore + $revenueScore + $retentionScore, 2);
    }
}
