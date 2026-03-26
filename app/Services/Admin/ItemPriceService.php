<?php

namespace App\Services\Admin;

use App\Models\Item;
use App\Models\ItemPrice;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ItemPriceService
{
    /**
     * @param array<string, mixed> $validatedData
     */
    public function setActivePrice(int $tenantId, int $itemId, array $validatedData): ItemPrice
    {
        $this->resolveItem($tenantId, $itemId);

        return DB::transaction(function () use ($tenantId, $itemId, $validatedData): ItemPrice {
            $activePrice = ItemPrice::query()
                ->where('tenant_id', $tenantId)
                ->where('item_id', $itemId)
                ->where('pricing_status', 'active')
                ->lockForUpdate()
                ->first();

            $payload = [
                'tenant_id' => $tenantId,
                'item_id' => $itemId,
                'currency_code' => (string) $validatedData['currency_code'],
                'base_price_amount' => $this->normalizeDecimal($validatedData['base_price_amount'], 'base_price_amount'),
                'compare_at_price_amount' => array_key_exists('compare_at_price_amount', $validatedData)
                    ? $this->normalizeNullableDecimal($validatedData['compare_at_price_amount'], 'compare_at_price_amount')
                    : null,
                'pricing_status' => 'active',
                'effective_from' => $validatedData['effective_from'] ?? null,
                'effective_to' => $validatedData['effective_to'] ?? null,
            ];

            if ($activePrice !== null) {
                $activePrice->fill($payload);
                $activePrice->save();

                return $activePrice;
            }

            return ItemPrice::query()->create($payload);
        });
    }

    /**
     * @param array<string, mixed> $validatedData
     */
    public function createDraftPrice(int $tenantId, int $itemId, array $validatedData): ItemPrice
    {
        $this->resolveItem($tenantId, $itemId);

        return DB::transaction(function () use ($tenantId, $itemId, $validatedData): ItemPrice {
            $draftPrice = ItemPrice::query()
                ->where('tenant_id', $tenantId)
                ->where('item_id', $itemId)
                ->where('pricing_status', 'draft')
                ->lockForUpdate()
                ->first();

            $payload = [
                'tenant_id' => $tenantId,
                'item_id' => $itemId,
                'currency_code' => (string) $validatedData['currency_code'],
                'base_price_amount' => $this->normalizeDecimal($validatedData['base_price_amount'], 'base_price_amount'),
                'compare_at_price_amount' => array_key_exists('compare_at_price_amount', $validatedData)
                    ? $this->normalizeNullableDecimal($validatedData['compare_at_price_amount'], 'compare_at_price_amount')
                    : null,
                'pricing_status' => 'draft',
                'effective_from' => $validatedData['effective_from'] ?? null,
                'effective_to' => $validatedData['effective_to'] ?? null,
            ];

            if ($draftPrice !== null) {
                $draftPrice->fill($payload);
                $draftPrice->save();

                return $draftPrice;
            }

            return ItemPrice::query()->create($payload);
        });
    }

    /**
     * @param array<string, mixed> $validatedData
     */
    public function updatePrice(int $tenantId, int $itemId, int $priceId, array $validatedData): ItemPrice
    {
        $this->resolveItem($tenantId, $itemId);

        return DB::transaction(function () use ($tenantId, $itemId, $priceId, $validatedData): ItemPrice {
            $price = ItemPrice::query()
                ->where('tenant_id', $tenantId)
                ->where('item_id', $itemId)
                ->whereKey($priceId)
                ->lockForUpdate()
                ->first();

            if ($price === null) {
                throw (new ModelNotFoundException())->setModel(ItemPrice::class, [(string) $priceId]);
            }

            $nextStatus = isset($validatedData['pricing_status']) ? (string) $validatedData['pricing_status'] : $price->pricing_status;

            if (!in_array($nextStatus, ['active', 'draft'], true)) {
                throw ValidationException::withMessages([
                    'pricing_status' => ['The pricing status must be either active or draft.'],
                ]);
            }

            $conflict = ItemPrice::query()
                ->where('tenant_id', $tenantId)
                ->where('item_id', $itemId)
                ->where('pricing_status', $nextStatus)
                ->where('id', '!=', $price->id)
                ->lockForUpdate()
                ->exists();

            if ($conflict) {
                throw ValidationException::withMessages([
                    'pricing_status' => ['Only one '.$nextStatus.' price is allowed per item.'],
                ]);
            }

            $payload = [];

            if (array_key_exists('currency_code', $validatedData)) {
                $payload['currency_code'] = (string) $validatedData['currency_code'];
            }

            if (array_key_exists('base_price_amount', $validatedData)) {
                $payload['base_price_amount'] = $this->normalizeDecimal($validatedData['base_price_amount'], 'base_price_amount');
            }

            if (array_key_exists('compare_at_price_amount', $validatedData)) {
                $payload['compare_at_price_amount'] = $this->normalizeNullableDecimal($validatedData['compare_at_price_amount'], 'compare_at_price_amount');
            }

            if (array_key_exists('effective_from', $validatedData)) {
                $payload['effective_from'] = $validatedData['effective_from'];
            }

            if (array_key_exists('effective_to', $validatedData)) {
                $payload['effective_to'] = $validatedData['effective_to'];
            }

            if (array_key_exists('pricing_status', $validatedData)) {
                $payload['pricing_status'] = $nextStatus;
            }

            if ($payload !== []) {
                $price->fill($payload);
                $price->save();
            }

            return $price;
        });
    }

    private function resolveItem(int $tenantId, int $itemId): Item
    {
        $item = Item::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($itemId)
            ->first();

        if ($item === null) {
            throw (new ModelNotFoundException())->setModel(Item::class, [(string) $itemId]);
        }

        return $item;
    }

    private function normalizeNullableDecimal(mixed $value, string $field): ?string
    {
        if ($value === null) {
            return null;
        }

        return $this->normalizeDecimal($value, $field);
    }

    private function normalizeDecimal(mixed $value, string $field): string
    {
        if (is_float($value)) {
            throw ValidationException::withMessages([
                $field => ['Monetary values must not be provided as float.'],
            ]);
        }

        if (is_int($value)) {
            return (string) $value.'.00';
        }

        if (!is_string($value)) {
            throw ValidationException::withMessages([
                $field => ['Monetary value must be a decimal string.'],
            ]);
        }

        $normalized = trim($value);

        if (!preg_match('/^\d+(\.\d{1,2})?$/', $normalized)) {
            throw ValidationException::withMessages([
                $field => ['Monetary value must have up to 2 decimal places.'],
            ]);
        }

        $parts = explode('.', $normalized, 2);
        $integerPart = ltrim($parts[0], '0');
        $integerPart = $integerPart === '' ? '0' : $integerPart;

        $decimalPart = $parts[1] ?? '00';

        if (strlen($decimalPart) === 1) {
            $decimalPart .= '0';
        }

        return $integerPart.'.'.$decimalPart;
    }
}
