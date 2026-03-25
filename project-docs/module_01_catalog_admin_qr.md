# MODULE_01_CATALOG_ADMIN_QR.md

## 1. Module Purpose

This module defines the first business-critical production release for the AI Commerce Platform.

It focuses on the fastest sellable and operationally safe slice of the product:
- merchant admin foundation
- business profile setup
- catalog setup
- service knowledge setup
- public customer-facing entry points
- QR generation and routing

The module must be designed cleanly from the beginning, but it must avoid unnecessary operational complexity in Phase 1.

---

## 2. Module Philosophy

### Build for today, prepare for tomorrow
The implementation must:
- include what is required for a strong production launch
- avoid premature complexity that does not serve the first release
- leave clear extension points for future features

### Practical rule
If a feature is not needed for the first sellable release, do not force it into the active flow.
However, where the future need is likely, the data model and architecture should leave room for it without creating dead weight in the user experience.

---

## 3. What This Module Includes

### 3.1 Merchant Admin Foundation
- merchant login
- merchant workspace access
- merchant dashboard shell
- business profile settings
- business mode selection
- branding basics
- public page settings

### 3.2 Catalog Foundation
For product-based businesses:
- categories
- products/items
- base price
- optional sale/display price logic later
- images
- description
- active/inactive state
- sort order / visibility

### 3.3 Service Knowledge Foundation
For service-based businesses:
- PDF upload
- manual FAQ entry
- manual service entry
- pricing text or structured service price entry
- approval/review status for extracted knowledge

### 3.4 Public Customer Experience
- public business landing page
- public catalog page
- public service page
- mobile-first rendering

### 3.5 QR Foundation
- generate tenant-scoped QR codes
- assign QR destination type
- redirect customer safely
- allow QR deactivation/regeneration

---

## 4. What This Module Explicitly Does NOT Require Yet

These items should be architecturally possible later, but should not complicate the first release flow unless a direct requirement appears:
- inventory/stock management in active UI
- warehouse logic
- purchase orders
- supplier management
- advanced discount engine
- taxation engine
- barcode scanning workflows
- bundle/combo product logic
- loyalty systems
- advanced delivery workflows
- multi-branch operational complexity
- advanced product option matrices unless a minimal version becomes necessary

### Important design rule
Do not surface unnecessary fields in the first admin UX just because they may be needed one day.
Keep the UI clean, but keep the schema extensible.

---

## 5. Recommended Product Model for Phase 1

### 5.1 Minimal Active Product Fields
Every product/item should support at minimum:
- id
- tenant_id
- category_id (nullable if uncategorized)
- name
- slug
- short_description
- long_description (optional)
- base_price
- currency
- status (draft / active / archived)
- visibility (public / hidden)
- primary_image
- sort_order
- created_at
- updated_at

### 5.2 Future-Ready but Inactive Fields
The system may keep room later for:
- sku
- compare_at_price
- stock_tracking_enabled
- stock_quantity
- variant_enabled
- metadata

These should not dominate the first release user flow.

### 5.3 Product Principle
The platform should make it extremely easy for a merchant to create and publish products quickly.
No unnecessary friction.

---

## 6. Recommended Service Model for Phase 1

### 6.1 Service Business Content Sources
A service tenant may build its knowledge base from:
- uploaded PDF documents
- manual service records
- FAQ entries
- business policy records

### 6.2 Minimal Active Service Fields
For manual service entries:
- id
- tenant_id
- name
- description
- price_label or starting_price
- status
- visibility
- sort_order
- created_at
- updated_at

### 6.3 Document Knowledge Pipeline
1. tenant uploads PDF
2. system stores document
3. system parses text
4. system chunks content
5. system stores candidate chunks
6. merchant reviews and approves relevant knowledge
7. approved knowledge becomes AI-usable context

### 6.4 Safety Rule
Unapproved extracted content must not be treated as final public business truth.

---

## 7. Admin UX Requirements

## 7.1 Admin Goal
The merchant should be able to get from signup to a usable public business page with QR in the fewest clean steps possible.

### 7.2 Merchant First-Time Setup Flow
1. create account / sign in
2. create tenant/workspace
3. enter business name
4. choose business mode:
   - product business
   - service business
5. upload logo (optional)
6. set phone / WhatsApp / address basics
7. continue to content setup

### 7.3 Product Business Setup Flow
1. create categories
2. create first products
3. upload images
4. review public preview
5. publish page
6. generate QR

### 7.4 Service Business Setup Flow
1. upload PDF or add service details manually
2. review extracted knowledge
3. create/edit FAQs
4. review public preview
5. publish page
6. generate QR

### 7.5 Dashboard Sections
The merchant dashboard should include these core sections:
- Overview
- Business Profile
- Catalog or Services
- QR Codes
- Public Page Preview
- AI / Channel Setup (placeholder-ready for Phase 1.5)

### 7.6 UX Standard
The admin interface should look polished from the beginning, but avoid feature clutter.
It should feel production-grade, not like an internal tool.

---

## 8. Public Experience Requirements

### 8.1 Public Entry Page
Each tenant should have a public entry page that can act as:
- a mini storefront for product businesses
- a service information page for service businesses
- a bridge page for QR traffic

### 8.2 Public Product Experience
The public catalog should support:
- business identity header
- category browsing
- product cards
- product details
- image display
- clear price display
- WhatsApp CTA

### 8.3 Public Service Experience
The public service page should support:
- business intro
- service cards or sections
- FAQs
- WhatsApp CTA
- request/ask flow later

### 8.4 Mobile First
Because QR and WhatsApp usage are mobile-heavy, public pages must be designed mobile-first.

---

## 9. QR Requirements

### 9.1 QR Use Cases
QR is a core entry point in Phase 1.
Supported QR use cases:
- open public catalog
- open public service page
- open smart landing page
- open WhatsApp deep link

### 9.2 QR Entity Fields
Each QR should include:
- id
- tenant_id
- token
- destination_type
- destination_payload
- label
- is_active
- created_at
- updated_at

### 9.3 QR Admin Actions
The merchant must be able to:
- create QR
- select destination type
- rename QR label
- download QR image
- deactivate QR
- regenerate QR if necessary

### 9.4 QR Safety Rule
QR resolution must validate:
- token exists
- token is active
- token belongs to valid tenant
- destination is allowed for public access

---

## 10. Business Profile Requirements

### 10.1 Minimal Business Profile Fields
- tenant_id
- business_name
- slug
- logo
- cover_image (optional)
- phone_number
- whatsapp_number
- short_about
- address_text
- business_mode
- primary_language
- currency
- timezone
- public_visibility

### 10.2 Future-Ready Fields
May be added later without complicating Phase 1 UI:
- support_email
- social links
- opening hours
- multiple branches
- map coordinates
- region settings

---

## 11. Roles and Permissions for This Module

### Phase 1 Active Roles
- Merchant Owner
- Merchant Admin
- Merchant Staff

### Minimum Permission Rules
- Owner: full access
- Admin: manage catalog/services, QR, public profile
- Staff: limited content operations if enabled later

For the first implementation, Owner and Admin are enough for active flows, but structure should remain extensible.

---

## 12. Data and Publishing Rules

### 12.1 Draft vs Published
Content should distinguish between internal edit state and public visibility.

For example:
- draft product not visible publicly
- active product visible publicly if page is published
- archived product hidden

### 12.2 Media Rules
- images stored in object storage
- optimized public delivery
- safe validation on upload

### 12.3 Slug Rules
- tenant slug unique platform-wide
- product/service slugs unique per tenant where relevant

---

## 13. API Surface Direction

This module will eventually require separate API groups:

### Admin APIs
- tenant profile management
- category management
- product management
- service content management
- FAQ management
- QR management
- public settings preview/publish controls

### Public APIs
- public business profile
- public catalog list
- public product detail
- public service content
- QR resolution

### Internal/Async APIs
- document parsing callbacks/jobs
- image processing jobs
- preview/publish jobs if needed

---

## 14. Validation Rules

### Product Validation
At minimum:
- name required
- base_price required and numeric
- currency required
- status valid
- image optional but validated if uploaded

### Category Validation
- name required
- tenant-scoped uniqueness rules where relevant

### Service Validation
- name required for manual services
- description required if meant for public display
- price optional but normalized if provided

### Business Profile Validation
- business_name required
- slug required and unique
- business_mode required
- whatsapp_number optional at first setup but recommended

---

## 15. Acceptance Criteria

### 15.1 Merchant Setup
- merchant can create tenant and business profile
- merchant can select product or service mode
- merchant can reach relevant setup flow based on selected mode

### 15.2 Product Catalog
- merchant can create categories
- merchant can create products with price and image
- merchant can publish visible products to public page
- public catalog renders correctly on mobile

### 15.3 Service Setup
- merchant can upload PDF
- system stores document safely
- system produces reviewable extracted knowledge
- merchant can approve knowledge for future AI grounding
- public service page renders correctly on mobile

### 15.4 QR
- merchant can generate QR code
- QR resolves correctly to intended destination
- inactive QR cannot be resolved publicly

### 15.5 Public Page
- public page loads without auth
- tenant data is scoped correctly
- hidden/internal data is never exposed publicly

---

## 16. Edge Cases

### Product Side
- tenant has no categories yet
- tenant has no products yet
- product image upload fails
- duplicate product names exist
- catalog exists but nothing is published

### Service Side
- PDF parse partially fails
- uploaded PDF contains noisy/unstructured content
- extracted chunks are low quality
- merchant wants manual edit before approval

### QR Side
- QR token invalid
- QR token disabled
- QR token points to unpublished page

### Public Side
- tenant slug not found
- tenant exists but public visibility off
- tenant has incomplete setup

---

## 17. Non-Functional Requirements

### Security
- tenant-scoped authorization
- file upload validation
- protected storage strategy
- no public leakage of internal records

### Performance
- fast public page rendering
- cached catalog reads where safe
- optimized image delivery
- paginated admin listings

### Auditability
At minimum log:
- business profile changes
- product create/update/archive
- service knowledge approval actions
- QR create/deactivate/regenerate

---

## 18. UI/UX Direction

### Admin UI Tone
- clean
- modern
- business-ready
- not overloaded

### Public UI Tone
- simple
- trustworthy
- mobile-first
- conversion-friendly

### Design Rule
The system should look strong from day one, but not bloated.
Merchants should feel they are using a serious platform, not a prototype.

---

## 19. Future Extension Readiness

This module should make future additions possible without major rewrite, including:
- stock tracking
- variants
- compare prices
- coupons
- ordering cart
- branch logic
- service appointments
- analytics expansion
- AI auto-reply enhancement

But those should remain dormant until needed.

---

## 20. Recommended Build Order for This Module

### Milestone 1
- tenant/business profile foundation
- role/access foundation
- public slug foundation

### Milestone 2
- category and product CRUD
- image upload
- public catalog page

### Milestone 3
- service entry CRUD
- PDF upload and parsing pipeline shell
- public service page

### Milestone 4
- QR entity + generation + public resolution
- QR admin management

### Milestone 5
- preview/publish flow polishing
- audit logging coverage
- UX refinement

---

## 21. Final Decision Summary

For Phase 1, build a polished and extensible admin/catalog/QR foundation, but do not overload the first release with inventory and operational features that do not create immediate launch value.

The active first-release experience should be:
- simple for merchants
- polished for customers
- safe for production
- extensible for later growth

This module is the first real product surface of the platform and should be treated as the foundation for everything that follows.

