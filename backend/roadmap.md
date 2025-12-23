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
  - [ ] Test with real bill creation flow.
  1) when sending bill from mobile, NO PAYMENT info gets through. Just says "@username". Even though payment info is set within the settings.
  2) No way to get the link again later from Recent Bills?
  3) Offer choice between link/text share

- [ ] **Deploy & Test**
  - [ ] Deploy backend to Railway/Render
  - [ ] Deploy Next.js viewer to Vercel
  - [ ] Set `NEXT_PUBLIC_API_URL` environment variable
  - [ ] Test with production URLs
  - [ ] Share test bill with friend to verify full flow

**Milestone**: End-to-end Flutter → Backend → Web working in production

---

## Phase 3: Tabs & Group Trips (Next Priority)
*Goal: Support multi-bill group trips*

### Week 5-6: Tab System (4-6 weeks)
- [ ] **Backend: Tab Model & API**
  - [X] Create `Tab` model in `pkg/models/tab.go`
    ```go
    type Tab struct {
        ID          uint
        Name        string
        Description string
        Bills       []Bill
        TotalAmount float64
        AccessToken string
        CreatedAt   time.Time
    }
    ```
  - [X] Add `TabID *uint` to Bill model (optional foreign key)
  - [ ] Create tab endpoints:
    - `POST /api/tabs` - Create new tab
    - `GET /api/tabs/:id?t=token` - Get tab with all bills
    - `POST /api/tabs/:id/bills` - Add bill to existing tab
    - `PATCH /api/tabs/:id` - Update tab details
  - [ ] Implement `internal/tab/` (handler, service, repository)
  - [ ] Test with curl

- [ ] **Flutter: Tab UI**
  - [X] Add "New Tab" option on home screen
  - [ ] Create tab creation screen (name, description)
  - [X] Tab list screen (show all user's tabs)
  - [X] Tab detail screen (show all bills in tab + total)
  - [X] "Add Bill to Tab" flow
  - [ ] Save tabs to local database

- [ ] **Web Viewer: Tab Display**
  - [ ] Create `/t/[id]` route for tab viewing
  - [ ] Display tab name, description, total
  - [ ] List all bills in tab with expandable details
  - [ ] Show per-person totals across all bills
  - [ ] Payment buttons for settling entire tab

**Milestone**: Users can create group trip tabs and add multiple bills

---

## Phase 4: Image Uploads (After Tabs)
*Goal: Receipt photos and trip memories*

### Week 7-8: Image Infrastructure (3-4 weeks)
- [ ] **Backend: Storage Setup**
  - [ ] Sign up for CloudFlare R2 (free 10GB) OR AWS S3
  - [ ] Add image model:
    ```go
    type TabImage struct {
        ID          uint
        TabID       uint
        URL         string
        Processed   bool
        UploadedBy  string
        CreatedAt   time.Time
    }
    ```
  - [ ] Create image endpoints:
    - `POST /api/tabs/:id/images` - Upload image
    - `GET /api/tabs/:id/images` - List tab images
    - `PATCH /api/tabs/:id/images/:imageId` - Mark as processed
    - `DELETE /api/tabs/:id/images/:imageId` - Delete image
  - [ ] Implement image upload handler (multipart/form-data)
  - [ ] Add abuse prevention (rate limiting, file size limits)

- [ ] **Flutter: Camera & Upload**
  - [ ] Add `image_picker` package
  - [ ] Camera/gallery picker UI
  - [ ] Image compression before upload
  - [ ] Upload progress indicator
  - [ ] Display uploaded images in tab
  - [ ] Mark images as "processed" checkbox

- [ ] **Web Viewer: Image Gallery**
  - [ ] Display tab images in grid layout
  - [ ] Lightbox for full-size viewing
  - [ ] Show processed/unprocessed status

**Milestone**: Users can photograph receipts and attach to tabs

---

## Phase 5: Processing Workflow (After Images)
*Goal: Mark trip complete and settle up*

### Week 9: Finalization (1-2 weeks)
- [ ] **Backend: Finalization Logic**
  - [ ] Add `Finalized bool` to Tab model
  - [ ] `POST /api/tabs/:id/finalize` endpoint
  - [ ] Validate all images are processed
  - [ ] Lock tab from further edits
  - [ ] Calculate final settlements

- [ ] **Flutter: Settlement UI**
  - [ ] "Finalize Tab" button (only when all images processed)
  - [ ] Show warning: "This will lock the tab"
  - [ ] Display final settlement amounts
  - [ ] "Mark as Paid" buttons per person

- [ ] **Web Viewer: Settlement Display**
  - [ ] Show finalized status
  - [ ] Display who owes whom
  - [ ] Payment tracking checkboxes

**Milestone**: Complete group trip workflow from start to settlement

---

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
│   │   ├── bill.go                ✅ Updated (PaymentMethods array)
│   │   └── tab.go                 ⏳ TODO
│   ├── database/
│   │   └── postgres.go            ✅ Working
│   └── security/
│       └── token.go               ✅ Working
├── internal/
│   ├── bill/
│   │   ├── handler.go             ✅ Complete
│   │   ├── service.go             ✅ Complete
│   │   └── repository.go          ✅ Complete
│   ├── tab/                       ⏳ TODO
│   │   ├── handler.go
│   │   ├── service.go
│   │   └── repository.go
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
- Basic backend infrastructure (Go + PostgreSQL)
- Bill CRUD with access tokens
- Next.js web viewer with beautiful UI
- Flutter app sends bills to backend
- Venmo deep linking

### 🔄 In Progress (This Week)
- **Fix multiple payment methods bug**
  - Backend accepts array
  - Flutter sends all payment methods
  - Web viewer displays all methods
  - Test end-to-end flow

### ⏳ Next Up (After Current Fix)
1. Deploy to production (backend + frontend)
2. Test with real bill sharing
3. Start Tab backend implementation
4. Build Tab UI in Flutter

---

## Success Metrics

### Technical Achievements
- [X] Working bill-service with CRUD operations
- [X] Secure token-based access control
- [X] Beautiful web interface for bill viewing
- [X] Flutter integration with backend
- [ ] Tabs for group trips
- [ ] Image upload system
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
4. **Privacy-first**: No user accounts required (token-based sharing)

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