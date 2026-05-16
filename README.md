# NovaPlus

NovaPlus is a multi-tenant SaaS platform built with Laravel and designed as a modular monolith. It serves both product-based and service-based businesses from one core system, while keeping tenant data, permissions, and public exposure strictly isolated.

This is not a simple CRUD application. It is a production-oriented commerce and customer-interaction platform that supports:

- 📦 Product catalogs and item management
- 🧾 Service knowledge and business information
- 🌍 Public landing and catalog pages
- 📱 QR routing and destination resolution
- 💬 Customer conversations and messaging
- 🔐 Subscriptions, roles, and access control

## 📌 Executive Summary

NovaPlus is built to help a merchant launch and operate a digital storefront or service presence without needing separate systems for catalog management, public pages, customer messaging, and tenant administration. The platform is designed to be:

- 🧩 modular enough to grow into additional business domains
- 🔒 strict about authorization and tenant isolation
- ⚙️ production-oriented instead of demo-focused
- 🚀 optimized for the first sellable Phase 1 release

## 📚 Contents

- [Project Snapshot](#-project-snapshot)
- [What Makes It Different](#-what-makes-it-different)
- [Architecture](#-architecture)
- [Core Features](#-core-features)
- [Main Roles](#-main-roles)
- [API Response Style](#-api-response-style)
- [API Structure](#-api-structure)
- [Local Setup](#-local-setup)
- [Testing](#-testing)
- [Postman](#-postman)
- [Key Project Documents](#-key-project-documents)
- [Reviewer Notes](#-reviewer-notes)
- [Current Delivery Focus](#-current-delivery-focus)

## 🔎 Project Snapshot

- Backend: Laravel 13
- Authentication: Laravel Sanctum
- Database: PostgreSQL
- Cache / Queue: Redis
- Frontend tooling: Vite + Tailwind CSS 4
- API format: unified JSON envelopes with `success`, `message`, `data`, and `meta`
- Architecture: tenant-aware modular monolith

## ✨ What Makes It Different

The platform is built from day one as a scalable SaaS foundation rather than a single-store app. That means:

- 🧭 clear separation between admin APIs, public APIs, end-user APIs, and internal flows
- 🛡 tenant resolution middleware to ensure every operation belongs to the correct workspace
- 🧱 DTO/resource-style output mapping instead of returning raw models
- ✅ Form Request validation for all write operations and complex input
- 🧠 service-layer business logic instead of heavy controllers
- ⚡ pagination, selective columns, and query discipline for performance

## 🏗 Architecture

NovaPlus follows a modular monolith structure with domain-oriented boundaries:

- 👤 Identity and access: authentication, roles, users
- 🏢 Tenant / workspace: workspace data, status, settings
- 🛍 Catalog: categories, items, prices, images
- 🌐 Public discovery: public store pages and catalog browsing
- 📲 QR: token-based routing and public entry points
- 💬 Messaging: conversations, messages, reactions, and inbox flows
- 👥 End-user features: favorites, cart persistence, notifications, recently viewed
- 🧾 Subscriptions and onboarding: activation codes and redeem flows
- 📊 Sales agents: agent management and reporting

### Execution Flow

The codebase generally follows this flow:

`Controller -> Service -> Repository -> Model`

Supporting layers include:

- 📥 Form Requests for validation
- 📤 Resources for consistent responses
- 🔒 Policies and middleware for authorization
- 🧩 Tenant context for request scoping

## 🗂 Repository Structure

The repository is organized to keep application concerns easy to navigate:

- `app/Http/Controllers`: admin, owner, public, and end-user controllers
- `app/Http/Requests`: Form Request validation objects
- `app/Http/Resources`: API response transformers
- `app/Models`: domain models and relationships
- `app/Services`: business logic and orchestration
- `app/Repositories`: query-focused persistence logic
- `database/migrations`: schema definitions
- `routes/api.php`: versioned API routes
- `project-docs/`: architecture, database, API, and rollout documentation
- `postman/`: API collections and environments

## 🧠 Product Intent

The platform is built around a few concrete business goals:

- reduce the time needed for a merchant to launch an online presence
- provide a single place to manage catalog, public visibility, and customer conversations
- keep money-sensitive and tenant-sensitive operations deterministic
- let AI assist with classification and drafting without becoming the source of truth

## 🧩 How the Platform Works

NovaPlus is designed around a few connected operational journeys rather than isolated screens.

### 🏪 Merchant Journey

1. A merchant signs in as a platform user.
2. The merchant creates or receives a tenant/workspace.
3. The merchant configures the business profile and public identity.
4. The merchant adds categories, items, prices, and images.
5. The merchant publishes the catalog or service entry point.
6. The merchant generates QR codes and shares them with customers.
7. The merchant receives conversations, messages, and draft intents from customers.
8. The merchant reviews and responds through the owner dashboard.

### 🌍 Public Customer Journey

1. A customer opens a store link, QR code, or public catalog page.
2. The system resolves the correct tenant and checks that the workspace is active.
3. The public page displays only tenant-approved public data.
4. The customer can browse items, discover services, or initiate a conversation.
5. The customer can save favorites, view recent stores, or continue with the cart flow.

### 💬 Conversation Journey

1. A customer or owner starts a conversation.
2. The message is stored before deeper processing.
3. The system can classify intent, fetch relevant catalog context, or prepare a draft.
4. The owner or customer continues the conversation through the correct inbox flow.
5. Read states, reactions, and message history remain available for traceability.

### 🛡 Admin Journey

1. Super admins access global management tools.
2. They create and manage tenants, users, sales agents, and subscriptions.
3. They can activate, suspend, or review operational state.
4. Revenue and performance tools remain separated from merchant-facing features.

## 🧱 Technical Foundations

### Core Stack

| Area | Technology |
| --- | --- |
| Backend | Laravel 13 |
| Authentication | Laravel Sanctum |
| Database | PostgreSQL |
| Cache | Redis |
| Queue | Redis |
| Frontend tooling | Vite |
| Styling | Tailwind CSS 4 |
| Media storage | S3-compatible storage |

### Design Principles

- deterministic data first, AI second
- tenant scoping at query level, not only in the UI
- explicit authorization for every privileged action
- thin controllers and reusable services
- response contracts that stay stable over time
- public data should never leak admin-only state

## 🚀 Core Features

### 🔐 Authentication and Access

- Admin login with Sanctum tokens
- `me` endpoint for the authenticated user profile
- logout for token invalidation
- role-aware access for super admin, sales agent, store owner, and end user
- route protection by middleware and authorization rules

### 🏢 Tenant Onboarding and Subscription Flow

- create a new tenant/workspace
- automatically link the owner to the tenant
- manage subscription codes
- redeem subscription codes
- activate or suspend tenants through admin controls
- dedicated super admin tools for tenants, users, sales agents, revenue, and subscriptions

### 📦 Catalog Management

- categories CRUD
- items CRUD
- deterministic item pricing
- item image upload and primary image selection
- filtering, search, and pagination
- public catalog pages driven by tenant slug

### 🌍 Public Store Discovery

- public business types listing
- store discovery pages
- store detail pages with catalog summary
- public catalog browsing endpoints
- cache-backed reads for better performance

### 📲 QR Routing

- tenant-scoped QR tokens
- safe resolution to catalog, landing page, or WhatsApp deep link destinations
- support for future QR activation/deactivation management

### 💬 Messaging and Conversations

- end-user authentication
- start a conversation with a store
- send text, media, product, and intent messages
- owner inbox and conversation review
- owner replies
- mark messages and conversations as read
- message reactions

### 👥 End-User Features

- favorite stores
- user preferences
- recently viewed stores
- cart persistence
- guest cart merge
- notifications inbox

### 🧾 Operational Extras

- offers management in the owner area
- broadcast notifications
- owner dashboard metrics

## 👥 Main Roles

- 🛡 Super Admin: full platform administration, including tenants, users, subscriptions, revenue, and sales agents
- 🏪 Store Owner: manage catalog, public presence, conversations, offers, and profile settings
- 👨‍💼 Merchant Admin / staff: role-based workspace access depending on tenant policy
- 🛒 End User: browse, favorite, shop, and communicate
- 📈 Sales Agent: create and manage owners and store records, with reporting visibility

## 🧾 API Response Style

The platform uses a consistent JSON envelope.

Success response:

```json
{
  "success": true,
  "message": "Operation completed successfully.",
  "data": {},
  "meta": {}
}
```

Error response:

```json
{
  "success": false,
  "message": "Validation failed.",
  "errors": {
    "field": ["The field is required."]
  }
}
```

## 🧭 API Structure

The API is organized under a versioned namespace:

- `/api/v1/admin/...`
- `/api/v1/owner/...`
- `/api/v1/public/...`
- `/api/v1/enduser/...`
- `/api/v1/conversations/...`
- `/api/v1/messages/...`
- `/api/v1/sales-agent/...`

This separation keeps admin, public, and customer-facing concerns cleanly isolated.

## 🛠 Local Setup

### Requirements

- PHP 8.3+
- Composer
- Node.js 20+ or newer
- PostgreSQL
- Redis

### Installation Steps

1. Install PHP dependencies:

```bash
composer install
```

2. Create the environment file and generate the app key:

```bash
cp .env.example .env
php artisan key:generate
```

3. Configure your database and Redis connection inside `.env`.

4. Run database migrations:

```bash
php artisan migrate
```

5. Install frontend dependencies:

```bash
npm install
```

6. Start the frontend build watcher:

```bash
npm run dev
```

7. Start the Laravel server:

```bash
php artisan serve
```

8. Open the application in your browser and verify the API and UI entry points.

### Recommended Local Order

For the cleanest setup, use this order:

1. database
2. environment file
3. backend dependencies
4. migrations
5. frontend dependencies
6. backend server
7. frontend watcher

This keeps failures easy to trace when something is misconfigured.

### Full Development Run

If you want the full local development stack running together:

```bash
composer run dev
```

That script runs:

- Laravel server
- queue listener
- logs via Pail
- Vite development server

## 🧪 Testing

Run the test suite with:

```bash
php artisan test
```

Or via Composer:

```bash
composer test
```

### What Testing Should Cover

- authentication and token-based access
- tenant resolution and tenant access rules
- catalog CRUD and public read paths
- image upload and pricing workflows
- subscription activation and redeem flows
- end-user conversation and cart flows
- permission boundaries for admin and owner actions

## 📮 Postman

Postman is part of the delivery workflow for the API surface.

- Base URL: `http://localhost:8000/api/v1`
- Use Bearer tokens for protected routes
- Review the `postman/` directory for collections and environments
- Keep request examples and response examples aligned with the current API contract

### Postman Expectations

- keep endpoint examples current
- preserve existing requests when adding new ones
- include success and error examples
- use realistic tenant and user context in samples
- document protected endpoints with the required auth header

## ⚙️ Environment Notes

For a clean local setup, make sure these values are configured in `.env`:

- `APP_NAME`
- `APP_URL`
- `DB_CONNECTION`
- `DB_HOST`
- `DB_PORT`
- `DB_DATABASE`
- `DB_USERNAME`
- `DB_PASSWORD`
- `CACHE_STORE`
- `QUEUE_CONNECTION`
- `REDIS_HOST`
- `REDIS_PASSWORD`
- `REDIS_PORT`

If you are using local storage during development, verify that the filesystem and public storage links are also configured correctly.

## 🔒 Security and Data Rules

NovaPlus follows a strict production rule set:

- every tenant-facing query must remain tenant-scoped
- client input must never be trusted without validation
- public endpoints must expose only public data
- AI may assist with suggestions, but it must not decide money-sensitive outcomes
- prices, totals, and subscription states must always come from system records
- logs must not leak secrets, passwords, or hidden administrative state
- authorization checks must remain in place even when a route is already protected by middleware

## 🧭 API Conventions

The platform follows a predictable API style so responses stay easy to consume:

- JSON response envelopes for both success and error paths
- pagination on list endpoints
- explicit request validation before data mutation
- clear route separation by audience and purpose
- stable field names in response payloads
- no raw model dumping from controllers

### Typical Protected Request Shape

```http
Authorization: Bearer <token>
Accept: application/json
Content-Type: application/json
```

### Typical Response Shape

```json
{
  "success": true,
  "message": "Resource fetched successfully.",
  "data": {},
  "meta": {}
}
```

## 🧪 Feature Coverage Overview

The current Phase 1 scope centers on the most commercially important paths:

### 📦 Catalog

- build categories and items quickly
- manage deterministic pricing
- upload and select item images
- publish public catalog content safely

### 🧭 Admin Dashboard

- manage tenants and global platform state
- manage subscriptions, users, and sales agents
- review revenue and operational metrics

### 📲 QR

- generate tenant-aware QR entry points
- route to catalog, landing page, or external destinations
- support safe public resolution

### 🌍 Public Entry Points

- public store discovery
- public catalog and item browsing
- public business type listing

### 💬 WhatsApp / AI Foundation

- conversation capture
- intent-aware messaging support
- AI-assisted classification and drafting
- storage before downstream processing

### 🧾 Draft Capture

- customer intent can be converted into drafts
- merchants can review the draft state
- ambiguous cases remain reviewable instead of finalizing automatically

## 📚 Key Project Documents

- [Architecture](project-docs/architecture.md)
- [Database Design Phase 1](project-docs/database_design_phase_1.md)
- [API Contracts Phase 1](project-docs/api_contracts_phase_1.md)
- [Module 01: Catalog, Admin, QR](project-docs/module_01_catalog_admin_qr.md)
- [Phase 1 Backlog](project-docs/implementation_backlog_phase_1.md)

## 📝 Reviewer Notes

- This is a multi-tenant platform, not a single-store app.
- Every read and write must remain tenant-scoped.
- Financial data must come from deterministic system records, not AI.
- Public responses must not expose internal admin data.
- The current Phase 1 focus is catalog, admin dashboard, QR, public entry points, WhatsApp/AI foundation, and draft capture.

## 📍 Current Delivery Focus

1. 📦 Catalog
2. 🧭 Admin dashboard
3. 📲 QR
4. 🌍 Public customer entry points
5. 💬 WhatsApp / AI foundation
6. 🧾 Draft order and draft request capture

---

If you are reviewing the codebase for the first time, start with the architecture and database design docs, then inspect `routes/api.php` and the controllers under `app/Http/Controllers`.
