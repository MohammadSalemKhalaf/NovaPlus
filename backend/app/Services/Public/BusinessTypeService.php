<?php

namespace App\Services\Public;

use App\Models\BusinessType;
use Illuminate\Database\Eloquent\Collection;

class BusinessTypeService
{
    /**
     * @return Collection<int, BusinessType>
     */
    public function listActiveBusinessTypes(): Collection
    {
        return BusinessType::query()
            ->where('business_types.status', 'active')
            ->select([
                'business_types.id',
                'business_types.name',
                'business_types.slug',
                'business_types.sort_order',
            ])
            ->orderBy('business_types.sort_order')
            ->orderBy('business_types.id')
            ->get();
    }
}
