<?php

namespace App\DTOs\Admin;

class SalesAgentAnalyticsDto
{
    public function __construct(
        private readonly int $userId,
        private readonly string $name,
        private readonly string $email,
        private readonly int $tenantsCount,
        private readonly int $activeSubscriptionsCount,
        private readonly float $totalRevenue,
        private readonly float $activeRevenue,
        private readonly int $expiredSubscriptionsCount,
    ) {}

    public function toArray(): array
    {
        return [
            'user_id' => $this->userId,
            'name' => $this->name,
            'email' => $this->email,
            'tenants_count' => $this->tenantsCount,
            'active_subscriptions_count' => $this->activeSubscriptionsCount,
            'total_revenue' => $this->totalRevenue,
            'active_revenue' => $this->activeRevenue,
            'expired_subscriptions_count' => $this->expiredSubscriptionsCount,
            'performance_score' => $this->calculatePerformanceScore(),
        ];
    }

    private function calculatePerformanceScore(): float
    {
        if ($this->activeSubscriptionsCount === 0) {
            return 0.0;
        }

        // Score based on: active subscriptions count (40%), revenue (40%), retention (20%)
        $subscriptionScore = min($this->activeSubscriptionsCount / 100 * 40, 40);
        $revenueScore = min($this->activeRevenue / 10000 * 40, 40);
        $retentionRate = $this->activeSubscriptionsCount / ($this->activeSubscriptionsCount + $this->expiredSubscriptionsCount);
        $retentionScore = $retentionRate * 20;

        return round($subscriptionScore + $revenueScore + $retentionScore, 2);
    }
}
