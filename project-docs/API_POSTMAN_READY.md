# API Postman Ready

## Source of Truth
This Postman suite is synchronized with Laravel route inventory generated via:

- php artisan route:list --json

Total routes covered: 89

## Endpoint Groups
The collection is organized in a flat, readable structure:

- Auth
- Admin / Core
- Admin / Sales Agents
- Admin / Revenue
- Admin / Subscriptions
- Admin / Tenants
- Owner Catalog
- Public Stores
- Public Catalog
- Public Cart
- End User Auth
- End User Favorites
- End User Preferences
- End User Recently Viewed
- End User Cart
- QA / Test Flows

## Authentication Rules
- Admin and Owner secured routes require Bearer token:
  - Authorization: Bearer {{token}}
- End User secured routes also use Bearer token returned from end user auth endpoints.
- Public cart and merge-related testing uses device identity header:
  - X-Device-ID: {{device_id}}

## Headers Usage
Default headers used across requests:

- Accept: application/json
- Content-Type: application/json (for POST, PUT, PATCH)
- Authorization: Bearer {{token}} (when route is protected)
- X-Device-ID: {{device_id}} (public cart and merge routes)

## Request and Response Examples
Each request includes:

- Example request payload for body-based methods
- Example success response body:

```json
{
  "success": true,
  "message": "",
  "data": {},
  "meta": {}
}
```

## QA Flows
QA / Test Flows folder includes ready-to-run sequences:

- Full Guest Flow (Browse -> Add -> Checkout)
- End User Flow (Register -> Login -> Favorite -> Cart -> Merge)
- Sales Agent Flow (Create Owner -> Activate -> Tenant Ready)
- Category Delete Flow (Delete -> Verify Items Removed)
- System / Infra checks (root, up, storage, boost, csrf)

## Test Scripts Included
Automated Postman tests are embedded:

- Auth scripts: save token to environment when returned
- Cart scripts: validate cart items exist and quantity is at least 1
- Merge scripts: validate merge payload and multi-store group shape
- Favorites scripts: validate add/remove success semantics
- Generic scripts: status and success key checks for all remaining endpoints

## Frontend Consumption Guide
Frontend teams can use this collection as API reference by following:

- Use {{base_url}} as backend origin only (no hardcoded /api/v1 in env value)
- Read route paths from each request URI in the collection
- Use collection examples to bootstrap request DTOs
- Reuse collection test assertions as acceptance criteria
- Run QA flow folders as regression checks after frontend integration

## Environment Variables
Core environment variables used:

- base_url
- token
- device_id
- tenant_slug
- item_id
- category_id

Additional helper variables:

- tenant_id
- price_id
- image_id
- subscription_id
- subscription_code
- sales_agent_id
- business_type_id
- storage_path
