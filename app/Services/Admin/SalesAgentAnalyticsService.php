<?php

namespace App\Services\Admin;

use App\DTOs\Admin\SalesAgentAnalyticsDto;
use App\Repositories\Admin\SalesAgentAnalyticsRepository;

class SalesAgentAnalyticsService
{
    public function __construct(private readonly SalesAgentAnalyticsRepository $repository) {}

    /**
     * Get performance metrics for a single agent.
     */
    public function getAgentMetrics(int $agentId): ?array
    {
        $metrics = $this->repository->getAgentMetrics($agentId);

        if (! $metrics) {
            return null;
        }

        $dto = new SalesAgentAnalyticsDto(
            userId: $metrics['user_id'],
            name: $metrics['name'],
            email: $metrics['email'],
            tenantsCount: $metrics['tenants_count'],
            activeSubscriptionsCount: $metrics['active_subscriptions_count'],
            totalRevenue: $metrics['total_revenue'],
            activeRevenue: $metrics['active_revenue'],
            expiredSubscriptionsCount: $metrics['expired_subscriptions_count'],
        );

        return $dto->toArray();
    }

    /**
     * Get top performing agents.
     */
    public function getTopPerformers(int $limit = 10): array
    {
        $agents = $this->repository->getTopAgents($limit);

        return array_map(function (array $agent) {
            $dto = new SalesAgentAnalyticsDto(
                userId: $agent['user_id'],
                name: $agent['name'],
                email: $agent['email'],
                tenantsCount: $agent['tenants_count'],
                activeSubscriptionsCount: $agent['active_subscriptions_count'],
                totalRevenue: $agent['total_revenue'],
                activeRevenue: $agent['active_revenue'],
                expiredSubscriptionsCount: $agent['expired_subscriptions_count'],
            );

            return $dto->toArray();
        }, $agents);
    }
}
