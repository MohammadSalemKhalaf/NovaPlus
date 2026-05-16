<?php

namespace App\Services\Admin;

use App\DTOs\Admin\RevenueMetricsDto;
use App\Repositories\Admin\RevenueRepository;

class RevenueService
{
    public function __construct(private readonly RevenueRepository $repository) {}

    /**
     * Get revenue dashboard metrics.
     */
    public function getDashboard(): array
    {
        $counts = $this->repository->getSubscriptionCountsByStatus();
        $totalRevenue = $this->repository->getTotalRevenue();
        $activeRevenue = $this->repository->getActiveSubscriptionsRevenue();
        $monthlyRevenue = $this->repository->getMonthlyRevenue();

        $dto = new RevenueMetricsDto(
            totalRevenue: $totalRevenue,
            activeSubscriptionsRevenue: $activeRevenue,
            monthlyRevenue: $monthlyRevenue,
            activeSubscriptionsCount: $counts['active'],
            expiredSubscriptionsCount: $counts['expired'],
            expiringIn7DaysCount: $counts['expiring_7_days'],
            expiringIn30DaysCount: $counts['expiring_30_days'],
        );

        return [
            'metrics' => $dto->toArray(),
            'meta' => [
                'generated_at' => now()->toIso8601String(),
            ],
        ];
    }

    /**
     * Get revenue by sales agent.
     */
    public function getByAgent(?int $salesAgentId = null, ?string $dateFrom = null, ?string $dateTo = null): array
    {
        return $this->repository->getRevenueByAgent($salesAgentId, $dateFrom, $dateTo);
    }

    /**
     * Get topperforming agents by revenue.
     */
    public function getTopAgentsByRevenue(int $limit = 10): array
    {
        $agentRevenue = $this->repository->getRevenueByAgent();

        return array_slice(
            array_values(array_sort_by_key($agentRevenue, 'total_revenue', SORT_DESC)),
            0,
            $limit
        );
    }
}

/**
 * Helper function to sort array by key.
 */
function array_sort_by_key($array, $key, $sort_flags = SORT_REGULAR)
{
    $result = [];
    foreach ($array as $item => $value) {
        $result[$value[$key] . '.' . $item] = $value;
    }
    ksort($result, $sort_flags);
    return array_values($result);
}
