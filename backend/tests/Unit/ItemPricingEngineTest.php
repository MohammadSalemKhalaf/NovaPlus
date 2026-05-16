<?php

use App\Models\Item;
use App\Models\ItemPrice;
use App\Models\Offer;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Tests\TestCase;

uses(TestCase::class);

test('item with no offer returns original price', function () {
    $item = buildPricedItem(100.00, collect());

    expect($item->has_offer)->toBeFalse();
    expect($item->active_offer)->toBeNull();
    expect($item->final_price)->toBe(100.0);
});

test('item with percentage offer returns discounted price', function () {
    $offer = (new Offer())->forceFill([
        'id' => 10,
        'tenant_id' => 1,
        'status' => 'active',
        'discount_type' => 'percentage',
        'discount_value' => 20,
        'starts_at' => Carbon::now()->subDay(),
        'ends_at' => Carbon::now()->addDay(),
        'title' => '20% Off',
    ]);

    $item = buildPricedItem(100.00, collect([$offer]));

    expect($item->has_offer)->toBeTrue();
    expect($item->final_price)->toBe(80.0);
});

test('item with fixed offer returns discounted price', function () {
    $offer = (new Offer())->forceFill([
        'id' => 11,
        'tenant_id' => 1,
        'status' => 'active',
        'discount_type' => 'fixed',
        'discount_value' => 15,
        'starts_at' => Carbon::now()->subDay(),
        'ends_at' => Carbon::now()->addDay(),
        'title' => '15 Off',
    ]);

    $item = buildPricedItem(100.00, collect([$offer]));

    expect($item->final_price)->toBe(85.0);
});

test('expired offer is ignored', function () {
    $offer = (new Offer())->forceFill([
        'id' => 12,
        'tenant_id' => 1,
        'status' => 'active',
        'discount_type' => 'percentage',
        'discount_value' => 30,
        'starts_at' => Carbon::now()->subDays(3),
        'ends_at' => Carbon::now()->subDay(),
        'title' => 'Expired',
    ]);

    $item = buildPricedItem(100.00, collect([$offer]));

    expect($item->has_offer)->toBeFalse();
    expect($item->final_price)->toBe(100.0);
});

test('future offer is ignored', function () {
    $offer = (new Offer())->forceFill([
        'id' => 13,
        'tenant_id' => 1,
        'status' => 'active',
        'discount_type' => 'percentage',
        'discount_value' => 25,
        'starts_at' => Carbon::now()->addDay(),
        'ends_at' => Carbon::now()->addDays(3),
        'title' => 'Future',
    ]);

    $item = buildPricedItem(100.00, collect([$offer]));

    expect($item->has_offer)->toBeFalse();
    expect($item->final_price)->toBe(100.0);
});

test('latest valid offer is used when multiple offers exist', function () {
    $olderValid = (new Offer())->forceFill([
        'id' => 20,
        'tenant_id' => 1,
        'status' => 'active',
        'discount_type' => 'percentage',
        'discount_value' => 10,
        'starts_at' => Carbon::now()->subDays(2),
        'ends_at' => Carbon::now()->addDay(),
        'title' => 'Older',
    ]);

    $newerValid = (new Offer())->forceFill([
        'id' => 21,
        'tenant_id' => 1,
        'status' => 'active',
        'discount_type' => 'percentage',
        'discount_value' => 30,
        'starts_at' => Carbon::now()->subDay(),
        'ends_at' => Carbon::now()->addDays(2),
        'title' => 'Newer',
    ]);

    $expired = (new Offer())->forceFill([
        'id' => 22,
        'tenant_id' => 1,
        'status' => 'active',
        'discount_type' => 'percentage',
        'discount_value' => 80,
        'starts_at' => Carbon::now()->subDays(5),
        'ends_at' => Carbon::now()->subDay(),
        'title' => 'Expired',
    ]);

    $item = buildPricedItem(100.00, collect([$olderValid, $expired, $newerValid]));

    expect($item->active_offer)->not->toBeNull();
    expect((int) $item->active_offer->id)->toBe(21);
    expect($item->final_price)->toBe(70.0);
});

test('fixed discount never goes below zero', function () {
    $offer = (new Offer())->forceFill([
        'id' => 31,
        'tenant_id' => 1,
        'status' => 'active',
        'discount_type' => 'fixed',
        'discount_value' => 250,
        'starts_at' => Carbon::now()->subDay(),
        'ends_at' => Carbon::now()->addDay(),
        'title' => 'Huge Discount',
    ]);

    $item = buildPricedItem(100.00, collect([$offer]));

    expect($item->final_price)->toBe(0.0);
});

function buildPricedItem(float $basePrice, Collection $offers): Item
{
    $item = new Item([
        'id' => 99,
        'tenant_id' => 1,
        'name' => 'Sample Item',
        'status' => 'active',
        'visibility' => 'public',
    ]);

    $item->setRelation('activePrice', new ItemPrice([
        'id' => 1,
        'tenant_id' => 1,
        'item_id' => 99,
        'currency_code' => 'USD',
        'base_price_amount' => $basePrice,
        'pricing_status' => 'active',
        'effective_from' => Carbon::now()->subDay(),
        'effective_to' => Carbon::now()->addDay(),
    ]));

    $item->setRelation('offers', $offers);

    return $item;
}
