# IMPLEMENTATION_BACKLOG_PHASE_1.md

## 1. Purpose

This document converts Phase 1 design into a **real execution plan**.

It defines:
- milestones
- modules
- tasks
- dependencies
- execution order

Goal:
👉 move from planning → production code with minimal confusion

---

## 2. Execution Strategy

### Guiding Principles
- Build **vertical slices**, not isolated pieces
- Always keep system runnable
- Deliver value early (catalog + public page + QR)
- Delay AI complexity until core stable

---

## 3. Milestones Overview

### 🔹 Milestone 0 — Project Setup
### 🔹 Milestone 1 — Auth + Tenant Core
### 🔹 Milestone 2 — Catalog Core
### 🔹 Milestone 3 — Public Pages
### 🔹 Milestone 4 — QR System
### 🔹 Milestone 5 — Service Module
### 🔹 Milestone 6 — WhatsApp + AI Foundation
### 🔹 Milestone 7 — Draft Orders
### 🔹 Milestone 8 — Hardening (Security + Performance)

---

## 4. Milestone 0 — Project Setup

### Tasks
- Initialize repo (backend + frontend)
- Setup Laravel project
- Setup Next.js project
- Setup PostgreSQL
- Setup Redis
- Setup storage (S3 or local for dev)
- Setup environment configs
- Setup base folder structure

### Output
✔ Project runs locally
✔ DB connection works
✔ Basic health endpoint works

---

## 5. Milestone 1 — Auth + Tenant Core

### Tasks
- Implement user model
- Implement auth (JWT or session)
- Implement tenant model
- Implement tenant_users
- Implement middleware for tenant resolution
- Implement role system (owner/admin)

### APIs
- auth/login
- auth/me
- tenants/create

### Output
✔ User can login
✔ User can create tenant
✔ Tenant context resolved per request

---

## 6. Milestone 2 — Catalog Core

### Tasks
- Create categories table + CRUD
- Create items table + CRUD
- Create item_prices
- Create item_images upload
- Implement validation rules

### APIs
- categories CRUD
- items CRUD
- item image upload

### Output
✔ Merchant can create products
✔ Products stored correctly
✔ Prices deterministic

---

## 7. Milestone 3 — Public Pages

### Tasks
- Public tenant endpoint
- Public catalog endpoint
- Public item details
- Build Next.js public pages
- Mobile-first layout

### Output
✔ Public catalog works
✔ Accessible via slug
✔ Clean UI

---

## 8. Milestone 4 — QR System

### Tasks
- Create qr_codes table
- Generate tokens
- Build QR generation logic
- Build QR resolve endpoint
- Add QR UI in admin

### Output
✔ QR generates
✔ QR opens catalog
✔ QR can be disabled

---

## 9. Milestone 5 — Service Module

### Tasks
- Create service_entries CRUD
- Create service_faqs CRUD
- Implement service_documents upload
- Build parsing pipeline (basic)
- Build knowledge review UI

### Output
✔ Service businesses supported
✔ PDF upload works
✔ Manual services work

---

## 10. Milestone 6 — WhatsApp + AI Foundation

### Tasks
- Setup WhatsApp webhook
- Store inbound messages
- Normalize messages
- Implement AI intent classification
- Implement RAG retrieval (basic)
- Generate replies

### Output
✔ System receives WhatsApp messages
✔ AI responds using catalog/service data

---

## 11. Milestone 7 — Draft Orders

### Tasks
- Extract items from messages
- Validate against catalog
- Create draft_orders
- Create draft_order_items
- Build admin review UI

### Output
✔ Draft orders created
✔ Merchant can review/approve

---

## 12. Milestone 8 — Hardening

### Tasks
- Add audit logs
- Add rate limiting
- Add validation edge cases
- Add retry logic for webhooks
- Optimize DB indexes
- Add caching
- Logging and monitoring

### Output
✔ Production-ready system
✔ Stable under load
✔ Secure

---

## 13. Dependencies Map

- Milestone 1 → required for everything
- Milestone 2 → required for public pages
- Milestone 3 → required for QR
- Milestone 4 → independent but depends on tenant
- Milestone 6 → depends on catalog/service data
- Milestone 7 → depends on AI + catalog

---

## 14. Fastest Path to Market

If speed is critical:

1. Milestone 0
2. Milestone 1
3. Milestone 2
4. Milestone 3
5. Milestone 4

👉 STOP → You already have sellable product

Then continue:
6. Milestone 6
7. Milestone 7

---

## 15. Recommended Tech Tasks Order (Exact)

### Backend First
1. Auth
2. Tenant
3. Catalog
4. Public API
5. QR

### Then Frontend
6. Admin UI
7. Public pages

### Then AI
8. WhatsApp
9. AI replies

---

## 16. Definition of Done (Execution)

Each task must include:
- code
- validation
- auth
- tenant isolation
- error handling
- logging

---

## 17. What is Still Missing After This File

After finishing backlog, you only need:

1. CI/CD setup
2. Deployment plan
3. Domain + SSL
4. Monitoring tools
5. Production DB setup

---

## 18. How to Start With AI Agent (IMPORTANT)

### Step 1 — Give Agent Context

Provide these files:
- AGENTS.md
- ARCHITECTURE.md
- MODULE_01_CATALOG_ADMIN_QR.md
- DATABASE_DESIGN_PHASE_1.md
- API_CONTRACTS_PHASE_1.md
- IMPLEMENTATION_BACKLOG_PHASE_1.md

---

### Step 2 — Prompt Template

Use this:

"""
You are a senior backend engineer.

Read the following project documents carefully:
- AGENTS.md
- ARCHITECTURE.md
- MODULE_01_CATALOG_ADMIN_QR.md
- DATABASE_DESIGN_PHASE_1.md
- API_CONTRACTS_PHASE_1.md
- IMPLEMENTATION_BACKLOG_PHASE_1.md

Your job:
- follow architecture strictly
- follow tenant isolation rules
- follow money safety rules
- implement only Phase 1 features

Start with:
Milestone 1 — Auth + Tenant Core

Deliver:
- migrations
- models
- controllers
- middleware
- validation
- API routes

Do NOT skip validation or security.
Do NOT simplify multi-tenant logic.
Do NOT invent data structures outside the schema.

Explain briefly what you implemented.
"""

---

## 19. Final Advice

Do not:
- jump randomly between modules
- build AI first
- overcomplicate early

Do:
- follow milestones strictly
- test each milestone
- keep system working at all times

---

## 20. Summary

You now have:
- full system design
- full DB design
- full API design
- full execution roadmap

👉 You are ready to build production system.

This backlog is the execution engine of the project.

