# Air Dokan Professional Upgrade Roadmap

## Goal

Current project is a strong MVP/prototype.
To convert it into a real professional production-grade project, we need to upgrade:

- security
- database reliability
- admin workflows
- image/storage handling
- testing
- deployment
- monitoring
- business usability

This file is the working upgrade checklist for that conversion.

---

## Current Project Status

Already built:

- public catalog
- shoe listing and detail pages
- offline-first store visit flow
- admin login
- add shoe flow
- edit shoe flow
- stock update flow
- sales entry flow
- setup diagnostics page
- image upload API

Still MVP-level:

- simple password auth
- mock fallback data
- no full delete/archive/history system
- no full automated test suite
- no production monitoring/logging
- remote mock images still exist

---

## Launch Blockers

These should be completed before calling the project professional or production-ready.

### 1. Real Environment Setup

- Add real `.env.local` values
- Set real `NEXT_PUBLIC_SUPABASE_URL`
- Set real `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- Set real `SUPABASE_SERVICE_ROLE_KEY`
- Set real `ADMIN_PASSWORD`
- Set real store address
- Set real store phone
- Set real store hours

### 2. Secure Admin Auth

Current auth is too simple for a professional product.

Need upgrade:

- replace single shared password with real admin user accounts
- add role-based access
- add session expiry
- add failed-login protection / rate limit
- add password change/reset flow
- ensure secure cookie rules for local and production

### 3. Real Database-Only Mode

Current project uses mock fallback data for safety.
Professional version should not silently fall back in production.

Need:

- production mode should read real data only
- explicit seed/demo mode if needed
- clear error state when database is unavailable

### 4. Real Image System

Need:

- stop depending on remote mock Unsplash images
- use uploaded images from Supabase storage
- verify `shoe-images` bucket
- make sure images are public/readable if intended
- support replacing old images safely
- clean up unused images when shoes are updated or deleted

### 5. Final End-to-End Flow Testing

Must verify:

- admin login
- add shoe
- upload image
- edit shoe
- stock update
- sales entry
- public catalog update after admin changes
- detail page image rendering
- setup diagnostics page

---

## Professional Upgrade Phases

## Phase 1: Production Foundations

### Database and Schema

- finalize schema for `brands`, `categories`, `shoes`, `shoe_sizes`, `sales`
- add `updated_at` columns
- add `created_by` and `updated_by` if admin users are added
- add soft delete / archive fields
- create migration history cleanly
- generate Supabase TypeScript types

### Storage

- verify storage bucket exists
- verify public/private access policy
- confirm upload API works with production credentials
- support image replacement and cleanup
- ensure cover image ordering remains consistent

### Configuration

- real `.env.local`
- `.env.example` kept in sync
- production env values in deployment platform
- no default admin password in production

---

## Phase 2: Security Hardening

### Auth

- replace current admin password system with real admin auth
- optionally use Supabase Auth
- add admin roles
- protect all admin routes with user-based permissions

### API Security

- validate all request payloads with schema validation
- rate-limit sensitive endpoints
- audit all admin-only routes
- prevent unauthorized writes
- review upload endpoint permissions

### Session Safety

- secure cookies properly in production
- inactivity expiry
- forced logout support
- optional device/session list

---

## Phase 3: Admin Workflow Completion

### Catalog Management

- add delete shoe flow
- add archive/unarchive shoe flow
- add deactivate/activate listing flow
- add duplicate shoe flow
- add better manage page filters

### Stock Workflow

- stock change history
- bulk stock update
- low-stock alert dashboard improvements
- out-of-stock filtering

### Sales Workflow

- persistent sales history page
- date-wise sales reports
- daily / weekly / monthly totals
- sale edit/cancel flow
- stock rollback on canceled sale

### Dashboard

- replace placeholder metrics with real database-driven metrics
- total shoes
- total active shoes
- low stock count
- today sales
- week sales
- monthly totals

---

## Phase 4: Public Catalog Professionalization

### Customer Experience

- improve image fallback behavior
- loading skeletons
- empty state polish
- cleaner stock labels
- better typography consistency
- stronger mobile spacing and card layout

### Catalog Features

- better search relevance
- pagination or infinite loading
- featured sections from real data
- new arrivals section
- filter persistence
- sorting improvements

### Store Visit Experience

- real map embed
- real contact info everywhere
- click-to-call
- visit instruction section
- optional “reserve in store” later if business wants

---

## Phase 5: Engineering Quality

### Testing

Need proper automated testing:

- unit tests for helpers
- API route tests
- auth tests
- add/edit shoe tests
- stock update tests
- sales entry tests
- setup diagnostics tests
- end-to-end browser tests

Suggested E2E test coverage:

- login -> admin dashboard
- add shoe -> appears in manage list
- edit shoe -> updated in catalog
- stock update -> reflected on detail page
- sales add -> stock reduced

### CI/CD

- Git-based pipeline
- run lint on every push
- run build on every push
- run tests on every push
- block merge on failure

### Type Safety

- use generated Supabase types
- reduce hand-written DB response assumptions
- centralize validation schemas

---

## Phase 6: Observability and Reliability

### Logging

- add structured server logs
- log upload failures
- log admin action failures
- log auth issues

### Monitoring

- production error reporting
- API error tracking
- storage failure alerts
- uptime checks

### Operational Reliability

- backup strategy
- rollback strategy for bad deployments
- migration rollback plan
- test staging environment before production changes

---

## Phase 7: Business-Grade Polish

### Branding

- real logo
- favicon
- professional copy cleanup
- consistent Bangla text
- remove broken encoded text

### Content Quality

- confirm all labels in Bangla/English are intentional
- improve product naming consistency
- define category naming rules
- define brand naming rules

### Usability

- make admin faster for daily use
- fewer taps for stock updates
- recent activity panel
- smarter edit shortcuts

---

## Specific Technical Upgrades Needed in This Project

### Replace or Improve These Areas

#### Admin Auth

Current:

- single password cookie-based auth

Upgrade to:

- Supabase Auth or custom admin users table
- role checks
- safer session management

#### Store Data Layer

Current:

- mixed real/fallback behavior

Upgrade to:

- explicit production data mode
- explicit demo mode
- stricter DB error handling

#### Image Handling

Current:

- uploads supported
- mock remote images still present

Upgrade to:

- all production images from storage
- delete/reorder/replace support
- cleanup on update/delete

#### Dashboard Metrics

Current:

- partly placeholder metrics

Upgrade to:

- real DB queries for dashboard cards and charts

#### Manage Catalog

Current:

- add/edit/list exists

Upgrade to:

- archive/delete/history/bulk actions

---

## Recommended Immediate Next Tasks

If we want to move from current state toward professional production fast, do these first:

1. Set real environment values
2. Confirm Supabase bucket and policies
3. Remove production dependence on mock images
4. Replace shared admin password with real auth
5. Add delete/archive/history flows
6. Add automated tests
7. Add deployment and monitoring

---

## Pre-Launch Checklist

Before launch, confirm all of these:

- `.env.local` fully real
- no default admin password
- storage bucket works
- image upload works
- add shoe works
- edit shoe works
- stock update works
- sales entry works
- admin setup live check passes
- public catalog shows real data
- no broken image URLs
- no mock fallback used in production
- mobile test completed
- lint passes
- build passes
- test suite passes

---

## Nice-to-Have After Launch

- PWA support
- analytics
- printable reports
- CSV export
- barcode or QR stock helpers
- advanced sales reporting
- customer favorites or saved shortlist

---

## Conclusion

This project is already a good MVP.
To make it truly professional, focus on:

- real auth
- real data only in production
- reliable storage/image handling
- completed admin workflows
- automated tests
- deployment and monitoring

Once those are done, the project can move from “working prototype” to “professional production system”.
