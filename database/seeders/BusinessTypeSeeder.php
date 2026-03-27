<?php

namespace Database\Seeders;

use App\Models\BusinessType;
use Illuminate\Database\Seeder;

class BusinessTypeSeeder extends Seeder
{
    public function run(): void
    {
        $types = [
            ['name' => 'Restaurant Supplies', 'slug' => 'restaurant-supplies', 'sort_order' => 1],
            ['name' => 'Bakery Supplies', 'slug' => 'bakery-supplies', 'sort_order' => 2],
            ['name' => 'Sweets and Chocolate', 'slug' => 'sweets-and-chocolate', 'sort_order' => 3],
            ['name' => 'Coffee and Beverages', 'slug' => 'coffee-and-beverages', 'sort_order' => 4],
            ['name' => 'Clothing', 'slug' => 'clothing', 'sort_order' => 5],
            ['name' => 'Cosmetics', 'slug' => 'cosmetics', 'sort_order' => 6],
            ['name' => 'Supermarket', 'slug' => 'supermarket', 'sort_order' => 7],
            ['name' => 'Pharmacy', 'slug' => 'pharmacy', 'sort_order' => 8],
            ['name' => 'Electronics', 'slug' => 'electronics', 'sort_order' => 9],
            ['name' => 'General Trading', 'slug' => 'general-trading', 'sort_order' => 10],
        ];

        foreach ($types as $type) {
            BusinessType::query()->updateOrCreate(
                ['slug' => $type['slug']],
                [
                    'name' => $type['name'],
                    'sort_order' => $type['sort_order'],
                    'status' => 'active',
                ],
            );
        }
    }
}
