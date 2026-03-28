<?php

namespace App\DTOs\Admin;

class RevenueMetricsDto
{
    public function __construct(
        private readonly float $totalRevenue,
        private readonly float $activeSubscriptionsRevenue,
        private readonly float $monthlyRevenue,
        private readonly int $activeSubscriptionsCount,
        private readonly int $expiredSubscriptionsCount,
        private readonly int $expiringIn7DaysCount,
        private readonly int $expiringIn30DaysCount,
    ) {}

    public function toArray(): array
    {
        return [
            'total_revenue' => $this->totalRevenue,
            'active_subscriptions_revenue' => $this->activeSubscriptionsRevenue,
            'monthly_revenue' => $this->monthlyRevenue,
            'active_subscriptions_count' => $this->activeSubscriptionsCount,
            'expired_subscriptions_count' => $this->expiredSubscriptionsCount,
            'expiring_in_7_days_count' => $this->expiringIn7DaysCount,
            'expiring_in_30_days_count' => $this->expiringIn30DaysCount,
        ];
    }
}
