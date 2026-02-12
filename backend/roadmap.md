# Billington Backend Development Roadmap

## Project Overview
Transform Billington from a local Flutter app into a Splitwise competitor with group trip features, image uploads, and collaborative bill splitting - all while maintaining privacy-first principles.

## Goals
- **Primary**: Build a working Splitwise competitor for group trips
- **Secondary**: Impressive distributed systems experience for resume
- **Learning**: Ship features fast, optimize later

---

## Phase 1: Foundation ✅ COMPLETE
*Goal: Get basic infrastructure running locally*

### Week 1-2: Basic Setup ✅
- [X] Environment setup (Go, Docker, PostgreSQL)
- [X] Project structure
- [X] First service running with health checks
- [X] Database integration with GORM
- [X] Bill CRUD operations
- [X] Access token system
- [X] Token validation middleware

---

## Phase 2: Bill Sharing & Web Viewer ✅ MOSTLY COMPLETE
*Goal: Working bill sharing with beautiful web interface*

### Week 3: Core Sharing ✅
- [X] Secure token generation (`pkg/security/token.go`)
- [X] Bill sharing URL format: `/b/{billId}?t={token}`
- [X] Next.js bill viewer app with React components
- [X] Venmo deep linking for payments
- [X] Beautiful UI matching marketing site design

### Week 4: Flutter Integration 🔄 IN PROGRESS
- [X] HTTP client service in Flutter
- [X] Bill creation flow generates shareable links
- [X] Send complete bill data (with PersonShares) to backend
- [🔄] **CURRENT: Fix multiple payment methods bug**
  - [X] Update backend to accept `PaymentMethods []PaymentMethod`
  - [X] Update Flutter to send all configured payment methods
  - [X] Update Next.js viewer to display all payment methods
  - [X] Test end-to-end: Flutter → Backend → Web viewer
  - [X] Verify Venmo deep linking works with multiple payment methods
  - [X] Ensure that bill viewer is in decent shape, don't need perfect. ~Good Enough~
  - [X] Test with real bill creation flow.

  1) update shareUtils to use enhanced sheet across the application so that users can get the link again from recent bills page
  2) transition off of SQL Lite DB? Why do I still have that. our system is using the postgres instance now.

- [ ] **Deploy & Test**
  - [ ] Deploy backend to Railway/Render
  - [ ] Deploy Next.js viewer to Vercel
  - [ ] Set `NEXT_PUBLIC_API_URL` environment variable
  - [ ] Test with production URLs
  - [ ] Share test bill with friend to verify full flow

**Milestone**: End-to-end Flutter → Backend → Web working in production

---

## Phase 3: Tabs & Group Trips ✅ COMPLETE
*Goal: Support multi-bill group trips*

### Week 5-6: Tab System
- [X] **Backend: Tab Model & API**
  - [X] Create `Tab` model in `pkg/models/tab.go`
  - [X] Add `TabID *uint` to Bill model (optional foreign key)
  - [X] Create tab endpoints (POST /api/tabs, GET /api/tabs/:id, POST /api/tabs/:id/bills, PATCH /api/tabs/:id)
  - [X] Implement `internal/tab/` (handler, service, repository)

- [X] **Flutter: Tab UI**
  - [X] Tab creation via bottom sheet
  - [X] Tab list screen with TabManager (Drift DB)
  - [X] Tab detail screen with per-person totals
  - [X] "Add Bill to Tab" flow
  - [X] Migrated from SharedPreferences to Drift DB (schema v3)
  - [X] Fixed delete bug (was SharedPreferences list sync issue)
  - [X] Backend sync (fire-and-forget) with share URL support
  - [X] Tab API service methods (createTab, addBillToTab)

- [X] **Web Viewer: Tab Display**
  - [X] Create `/t/[id]` route for tab viewing
  - [X] TabHeader component (name, description, total, bill count)
  - [X] TabPersonTotals component (per-person cards with Venmo)
  - [X] Bills as collapsible sections with individual shares

**Milestone**: Users can create group trip tabs and add multiple bills

- [ ] standardize how the deletion stuff looks, the apple esque feel of recent bills or the look of tabs?
- [ ] way to quickly add another bill within tabs after building the group

---

## Phase 4: Image Uploads ✅ COMPLETE
*Goal: Receipt photos and trip memories*

### Week 7-8: Image Infrastructure
- [X] **Backend: Storage Setup**
  - [X] Local file storage with upload directory
  - [X] TabImage model with processed flag
  - [X] Image endpoints (POST, GET, PATCH, DELETE)
  - [X] Multipart upload handler with MIME validation
  - [X] Rate limiting (20/hour) and file size limits (10MB)

- [X] **Flutter: Camera & Upload**
  - [X] `image_picker` package integrated
  - [X] Camera/gallery picker UI
  - [X] Image compression before upload
  - [X] Upload progress indicator
  - [X] Display uploaded images in tab
  - [X] Mark images as "processed" checkbox

- [X] **Web Viewer: Image Gallery**
  - [X] TabImageGallery component with lightbox
  - [X] Show processed/unprocessed status

**Milestone**: Users can photograph receipts and attach to tabs

---

## Phase 5: Processing Workflow ✅ COMPLETE
*Goal: Mark trip complete and settle up*

### Week 9: Finalization
- [X] **Backend: Finalization Logic**
  - [X] `Finalized` + `FinalizedAt` fields on Tab model
  - [X] `TabSettlement` model with per-person amounts + paid status
  - [X] `POST /api/tabs/:id/finalize` — validates images, creates settlements
  - [X] `GET /api/tabs/:id/settlements` — fetch settlement list
  - [X] `PATCH /api/tabs/:id/settlements/:id` — toggle paid
  - [X] Mutation guards on AddBill, UpdateTab, UploadImage, DeleteImage

- [X] **Flutter: Settlement UI**
  - [X] "Finalize" FAB appears when all images processed
  - [X] Confirmation sheet with settlement preview
  - [X] Settlement cards with tap-to-toggle paid status
  - [X] Drift schema v4 with finalized column
  - [X] Hides camera + Add Bills when finalized

- [X] **Web Viewer: Settlement Display**
  - [X] SettlementCard component with paid/unpaid styling
  - [X] Finalized badge in TabHeader
  - [X] Venmo pay buttons on unpaid settlements
  - [X] Replaces PersonTotals when finalized

**Milestone**: Complete group trip workflow from start to settlement

---

## Phase X: Account-less Collaboration ✅ COMPLETE
*Goal: Allow different users to add bills to shared tabs without accounts — privacy-first anonymous member tokens*

### Week 10: Anonymous Member Tokens
- [X] **Backend: TabMember model + CORS middleware**
  - [X] TabMember model (display_name, member_token, role)
  - [X] Members association on Tab, AddedByMemberID on Bill
  - [X] AutoMigrate + gin-contrib/cors middleware
- [X] **Backend: Member repository + service**
  - [X] CreateMember, GetMemberByToken, GetMembersByTabID
  - [X] JoinTab, JoinTabAsCreator, GetMembers service methods
- [X] **Backend: Join endpoint + member listing**
  - [X] POST /api/tabs/:id/join — returns member_token
  - [X] GET /api/tabs/:id/members — returns member list
  - [X] CreateTab accepts optional creator_display_name
- [X] **Backend: Member attribution on write endpoints**
  - [X] AddBillToTab records added_by_member_id via ?m= param
  - [X] FinalizeTab requires creator role when members exist
  - [X] UploadImage resolves ?m= for uploaded_by attribution
- [X] **Flutter: Drift migration v5 + model update**
  - [X] memberToken, role, isRemote columns on Tabs table
  - [X] Tab model fields + isCreator/isMember getters
- [X] **Flutter: API service updates**
  - [X] joinTab, getTabMembers, getTabData methods
  - [X] Member token passed on write endpoints
- [X] **Flutter: Tab creation with display name + join flow**
  - [X] Creator display name on tab creation
  - [X] Join Tab sheet (URL + name)
  - [X] Clipboard detection for Billington URLs
- [X] **Flutter: Tab detail for remote tabs + members**
  - [X] Member list with crown icon for creator
  - [X] Member token attribution on uploads
- [X] **Web Viewer: Join flow + member display**
  - [X] JoinTabButton component (localStorage persistence)
  - [X] MemberList component with member chips
  - [X] Integrated into tab page

**Milestone**: Multiple people can join shared tabs via link, add bills, and see who contributed — all without accounts.

---

## Phase D: Document and Test ✅ COMPLETE
*Goal: Comprehensive testing, updated documentation, unified dev startup*

- [X] **Unified dev startup script** (`dev.sh`)
  - [X] Checks prerequisites (Docker, Node, Flutter)
  - [X] Creates .env files if missing
  - [X] Starts backend Docker, waits for health check
  - [X] Starts Next.js dev server in background
  - [X] Launches iOS Simulator and runs Flutter app
  - [X] Cleanup on exit (kill processes, docker-compose down)
- [X] **Backend Go tests** (`internal/tab/service_test.go`)
  - [X] Manual mocks for TabRepository and ImageQuerier
  - [X] 8 test cases: FinalizeTab (success, already finalized, no bills, unprocessed images), JoinTab, JoinTabAsCreator, AddBillToTab, GetMembers
- [X] **Web viewer tests** (Vitest)
  - [X] Vitest config + test scripts in package.json
  - [X] 8 test cases: computeTabPersonTotals (aggregation, case-insensitive, sort, empty), getBill (403, 404, success), getTab (500)
- [X] **Documentation revamp**
  - [X] Root README rewritten with architecture diagram, quickstart, project structure, core concepts
  - [X] docs/technical-overview.md rewritten for distributed architecture
  - [X] docs/backend-api.md created with full endpoint reference
  - [X] docs/privacy.md rewritten with anonymous token model and comparison table
  - [X] backend/README.md rewritten with layered architecture and dev commands
- [X] **Backend Makefile updated** with `go test -v -race` target

**Milestone**: Full test coverage for core business logic, accurate documentation, one-command dev startup.

## Phase 6: Production Deployment & Polish
*Goal: Live, reliable, production system*

### Week 10-11: Deploy & Monitor (2-3 weeks)
- [ ] **Backend Deployment**
  - [ ] Deploy to Railway/Render/Fly.io
  - [ ] Set up production PostgreSQL
  - [ ] Configure environment variables
  - [ ] Set up CloudFlare R2 bucket
  - [ ] Configure CORS for production domains
  - [ ] Add structured logging
  - [ ] Set up health check monitoring

- [ ] **Frontend Deployment**
  - [ ] Deploy Next.js viewer to Vercel
  - [ ] Configure production API URLs
  - [ ] Set up custom domain (optional)
  - [ ] Test all flows in production

- [ ] **Testing & Bug Fixes**
  - [ ] Test with real group trip
  - [ ] Fix reported bugs
  - [ ] Performance testing (should be fine, but verify)
  - [ ] Security audit (SQL injection, XSS, etc.)

**Milestone**: Production-ready Splitwise competitor

---

## Phase 7: Growth Features (After MVP)
*Only add these if users ask for them*

### Future Enhancements (Priority TBD)
- [ ] **Social Features**
  - [ ] User accounts (optional - maintain privacy-first)
  - [ ] Friend list / frequent travelers
  - [ ] Tab invites via link

- [ ] **Advanced Calculations**
  - [ ] Currency conversion for international trips
  - [ ] Unequal splitting (weighted shares)
  - [ ] Settlement optimization (minimize transactions)

- [ ] **AI/Automation**
  - [ ] OCR for receipt scanning (GPT-4 Vision)
  - [ ] Auto-categorization of expenses
  - [ ] Smart splitting suggestions

- [ ] **Performance** (Only if needed)
  - [ ] Redis caching for frequently accessed tabs
  - [ ] CDN for images
  - [ ] Database query optimization
  - [ ] Rate limiting per IP

---

## Architecture Reference

### Current Project Structure
```
Billington-backend/
├── cmd/
│   ├── bill-service/main.go       ✅ Working
│   └── web-service/main.go        ✅ Working
├── pkg/
│   ├── models/
│   │   ├── bill.go                ✅ Updated (PaymentMethods, AddedByMemberID)
│   │   ├── tab.go                 ✅ Complete (Members association)
│   │   └── tab_member.go          ✅ Complete (anonymous identity)
│   ├── database/
│   │   └── postgres.go            ✅ Working
│   └── security/
│       └── token.go               ✅ Working
├── internal/
│   ├── bill/
│   │   ├── handler.go             ✅ Complete
│   │   ├── service.go             ✅ Complete
│   │   └── repository.go          ✅ Complete
│   ├── tab/                       ✅ Complete
│   │   ├── handler.go             ✅ (Join, Members, attribution)
│   │   ├── service.go             ✅ (JoinTab, GetMembers)
│   │   └── repository.go         ✅ (Member CRUD)
│   └── web/
│       ├── handler.go             ✅ Complete
│       └── templates/
│           └── bill.html          ✅ Complete
├── web-bill-viewer/               ✅ Next.js app
│   ├── app/
│   │   ├── b/[id]/page.tsx        ✅ Updated (multiple payments)
│   │   └── t/[id]/page.tsx        ⏳ TODO
│   ├── components/
│   │   ├── PaymentDetails.tsx    ✅ Updated (multiple payments)
│   │   └── ...
│   └── lib/api.ts                 ✅ Updated (PaymentMethod[])
├── docker-compose.yml             ✅ Working
└── README.md
```

### Service Architecture (Current)
```
┌─────────────────┐    ┌─────────────────┐
│   Mobile App    │    │  Next.js Viewer │
│   (Flutter)     │    │   (Vercel)      │
└─────────┬───────┘    └─────────┬───────┘
          │                      │
          │                      │
    ┌─────┴──────────────────────┴─────┐
    │      Backend API (bill-service)  │
    │         (port 8080)              │
    └─────────────┬────────────────────┘
                  │
            ┌─────▼─────┐
            │PostgreSQL │
            │ Database  │
            └───────────┘
```

### Service Architecture (After Tabs & Images)
```
┌─────────────────┐    ┌─────────────────┐
│   Mobile App    │    │  Next.js Viewer │
│   (Flutter)     │    │   (Vercel)      │
└─────────┬───────┘    └─────────┬───────┘
          │                      │
    ┌─────┴──────────────────────┴─────┐
    │      Backend API (bill-service)  │
    │    /api/bills  /api/tabs         │
    └─────────┬───────────┬────────────┘
              │           │
        ┌─────▼─────┐   ┌─▼──────────┐
        │PostgreSQL │   │CloudFlare  │
        │ Database  │   │R2 (images) │
        └───────────┘   └────────────┘
```

---

## Current Status

### ✅ Completed
- Phase 1: Foundation (Go + PostgreSQL + Bill CRUD)
- Phase 2: Bill Sharing & Web Viewer (Next.js + Venmo deep linking)
- Phase 3: Tabs & Group Trips (Tab model + Flutter UI + Web viewer)
- Phase 4: Image Uploads (Camera, upload, processed tracking)
- Phase 5: Processing Workflow (Finalize, settlements, paid tracking)
- Phase X: Account-less Collaboration (Anonymous member tokens, join flow, attribution)
- Phase D: Document and Test (Tests, docs, dev script)

### ⏳ Next Up
1. Deploy to production (backend + frontend)
2. Test full workflow with real group trip
3. Move display name entry to onboarding flow (SharedPreferences)

---

## Success Metrics

### Technical Achievements
- [X] Working bill-service with CRUD operations
- [X] Secure token-based access control
- [X] Beautiful web interface for bill viewing
- [X] Flutter integration with backend
- [X] Tabs for group trips
- [X] Image upload system
- [X] Account-less collaboration (anonymous member tokens)
- [ ] Production deployment
- [ ] 10+ real users testing

### Resume Value
- [X] Demonstrate layered architecture (handler/service/repository)
- [X] Show Go backend development skills
- [X] Prove full-stack capabilities (Go + React + Flutter)
- [ ] Evidence of image storage/CDN integration
- [ ] Display production deployment experience
- [ ] Real users on production system

---

## Lessons Learned

### Architecture Decisions
1. **Skip premature optimization**: No Redis/caching until needed
2. **Ship features first**: Tabs & images > performance tuning
3. **Monolith is fine**: Don't split into microservices yet
4. **Privacy-first**: No user accounts required YET (token-based sharing)

### Technical Insights
- GORM's `serializer:json` handles JSONB elegantly
- Go's `crypto/rand.Text()` simplifies token generation
- Repository pattern enables easy testing
- Flutter confusion is solvable - don't rewrite to Swift

### What NOT to Build Yet
- ❌ Redis caching (0 users = no need)
- ❌ Kubernetes (single server handles thousands)
- ❌ Microservices split (adds complexity, no benefit)
- ❌ WebSockets (polling works fine for now)
- ❌ Message queues (no async processing yet)

---

## Quick Reference

### Test Curl (Create Bill)
```bash
curl -X POST http://localhost:8080/api/bills \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Dinner at Chilis",
    "subtotal": 138.0,
    "tax": 8.28,
    "tip_amount": 27.60,
    "tip_percentage": 20.0,
    "total": 173.88,
    "participants": [{"name": "Alice"}, {"name": "Bob"}],
    "items": [
      {
        "name": "Pizza",
        "price": 20.0,
        "assignments": [
          {"person_name": "Alice", "percentage": 50},
          {"person_name": "Bob", "percentage": 50}
        ]
      }
    ],
    "person_shares": [
      {
        "person_name": "Alice",
        "items": [{"name": "Pizza", "amount": 10.0, "is_shared": true}],
        "subtotal": 10.0,
        "tax_share": 0.60,
        "tip_share": 2.00,
        "total": 12.60
      }
    ],
    "payment_methods": [
      {"name": "Venmo", "identifier": "@alice"},
      {"name": "Zelle", "identifier": "555-1234"},
      {"name": "Cash App", "identifier": "$alice"},
      {"name": "Apple Pay", "identifier": "202-3333"}
    ]
  }'
```

### Start Local Dev
```bash
# Backend
cd backend
docker-compose up --build

# Frontend
cd web-bill-viewer
npm run dev
```

### Deploy Commands (Future)
```bash
# Backend to Railway
railway up

# Frontend to Vercel
vercel --prod
```