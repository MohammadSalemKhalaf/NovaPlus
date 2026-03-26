<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ItemResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'category_id' => $this->category_id,
            'name' => $this->name,
            'slug' => $this->slug,
            'short_description' => $this->short_description,
            'long_description' => $this->long_description,
            'item_type' => $this->item_type,
            'status' => $this->status,
            'visibility' => $this->visibility,
            'primary_image_id' => $this->primary_image_id,
            'sort_order' => $this->sort_order,
            'created_by_user_id' => $this->created_by_user_id,
            'updated_by_user_id' => $this->updated_by_user_id,
            'category' => $this->whenLoaded('category', function () {
                return [
                    'id' => $this->category->id,
                    'parent_id' => $this->category->parent_id,
                    'name' => $this->category->name,
                    'slug' => $this->category->slug,
                    'description' => $this->category->description,
                    'sort_order' => $this->category->sort_order,
                    'status' => $this->category->status,
                ];
            }),
            'primary_image' => $this->whenLoaded('primaryImage', function () {
                return [
                    'id' => $this->primaryImage->id,
                    'item_id' => $this->primaryImage->item_id,
                    'storage_path' => $this->primaryImage->storage_path,
                    'alt_text' => $this->primaryImage->alt_text,
                    'sort_order' => $this->primaryImage->sort_order,
                    'is_primary' => $this->primaryImage->is_primary,
                    'created_at' => $this->primaryImage->created_at,
                    'updated_at' => $this->primaryImage->updated_at,
                ];
            }),
        ];
    }
}
