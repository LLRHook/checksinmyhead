# Billington Backend Development Roadmap

## Project Overview
Transform Billington from a local Flutter app into a distributed microservices architecture with real-time bill sharing, payment integration, and collaborative features - all while maintaining privacy-first principles.

## Goals
- **Primary**: Build impressive distributed systems experience for resume
- **Secondary**: Create a production-ready bill splitting platform
- **Learning**: Master Go, microservices, Kubernetes, real-time systems

---

## Phase 1: Foundation (Week 1-2)
*Goal: Get basic infrastructure running locally*

### Week 1: Environment & Project Setup
- [X] **Day 1-2: Development Environment**
  - [X] Install Go 1.21+ on development machine
  - [X] Install Docker & Docker Compose
  - [ ] Set up DigitalOcean Kubernetes cluster OR install K3s on home lab
  - [X] Create GitHub repository with proper .gitignore
  - [X] Initialize Go module: `go mod init github.com/username/Billington-backend`

- [X] **Day 3-4: Project Structure**
  - [X] Create directory structure (see architecture section below)
  - [X] Set up `pkg/models/` with basic structs
  - [X] Create `docker-compose.yml` for local development
  - [X] Write initial `README.md` with setup instructions

- [X] **Day 5-7: First Service**
  - [X] Create `bill-service` with basic HTTP server (Gin)
  - [X] Add health check endpoint (`GET /health`)
  - [X] Add placeholder bill endpoints (`POST /api/bills`, `GET /api/bills/:id`)
  - [X] Test with Docker Compose
  - [X] **Milestone**: Can run service locally and get 200 responses

### Week 2: Database Integration
- [X] **Day 8-10: Database Setup**
  - [X] Add PostgreSQL to docker-compose
  - [ ] Install database migration tool (golang-migrate)
  - [X] Create initial database schema
  - [X] Set up database connection in `pkg/database/`
  - [X] Add environment variable configuration

- [X] **Day 11-14: Bill CRUD Operations**
  - [X] Complete `Bill`, `BillItem`, `Person`, `ItemAssignment`, `PersonShare` models in `pkg/models/bill.go`
  - [X] Implement `internal/bill/repository.go` with database operations
  - [X] Implement `internal/bill/service.go` with business logic
  - [X] Complete `internal/bill/handler.go` with HTTP endpoints
  - [X] **Milestone**: Can create and retrieve bills via API

---

## Phase 2: Core Functionality (Week 3-4)
*Goal: Working bill sharing with real-time updates*

### Week 3: Bill Sharing & Access Control
- [X] **Day 15-17: Security & Access Tokens**
  - [X] Implement secure token generation for bill access (`pkg/security/token.go`)
  - [X] Add token validation in handler
  - [X] Create bill sharing URL format: `/b/{billId}?t={token}`
  - [X] Create web service for recipient bill viewing
  - [X] Add web pages for recipients to view their portions
  - [X] Test bill access control

- [X] **Day 18-21: Web Bill Viewer**
  - [X] Create Next.js bill viewer app
  - [X] Build React components matching marketing site design
  - [X] Implement API client for fetching bills
  - [X] Add Venmo deep linking for payments
  - [X] Deploy bill viewer (separate from marketing site)
  - [X] **Milestone**: Recipients can view bills in browser with beautiful UI

### Week 4: Flutter Integration & Real-time Updates
- [ ] **Day 22-25: Flutter Backend Integration**
  - [ ] Update Flutter app to call backend APIs
  - [ ] Add HTTP client service in Flutter
  - [ ] Update bill creation flow to generate shareable links
  - [ ] Send complete bill data (with PersonShares) to backend
  - [ ] Test bill sharing between devices

- [ ] **Day 26-28: Event System (Optional)**
  - [ ] Set up Redis for event caching
  - [ ] Create `pkg/models/events.go` with event structures
  - [ ] Implement `internal/events/` service for event publishing
  - [ ] Add event publishing to bill operations
  - [ ] Create event polling endpoint for clients
  - [ ] **Milestone**: Real-time bill collaboration working

---

## Phase 3: Payment Integration (Week 5-6)
*Goal: Actual payment processing with Venmo/Zelle*

### Week 5: Payment Service
- [ ] **Day 29-31: Payment Architecture**
  - [ ] Create `payment-service` with basic structure
  - [ ] Define payment models in `pkg/models/payment.go`
  - [ ] Set up payment database schema
  - [ ] Research Venmo/Zelle API integration options
  - [ ] Create payment initiation endpoints

- [ ] **Day 32-35: Payment Provider Integration**
  - [X] Implement Venmo deep linking for web recipients
  - [ ] Add payment status tracking
  - [ ] Create payment webhooks for status updates (if available)
  - [ ] Add Zelle integration (if available)
  - [ ] Test payment flow end-to-end

### Week 6: Polish & Testing
- [ ] **Day 36-38: Payment UX**
  - [ ] Update Flutter app with payment buttons
  - [ ] Add payment status UI indicators
  - [ ] Implement payment confirmation flow
  - [ ] Add payment history tracking
  - [ ] Test payment edge cases

- [ ] **Day 39-42: Integration Testing**
  - [ ] End-to-end testing of full bill splitting flow
  - [ ] Performance testing with multiple concurrent users
  - [ ] Error handling and recovery testing
  - [ ] **Milestone**: Complete payment-enabled bill splitting

---

## Phase 4: Production Deployment (Week 7-8)
*Goal: Deployed, monitored, production-ready system*

### Week 7: Cloud Deployment
- [ ] **Day 43-45: Deploy Backend**
  - [ ] Choose deployment platform (Railway, Render, Fly.io, or DigitalOcean)
  - [ ] Set up production PostgreSQL database
  - [ ] Configure environment variables
  - [ ] Deploy bill-service to production
  - [ ] Test API with production URLs

- [ ] **Day 46-49: Monitoring & Observability**
  - [ ] Add structured logging to all services
  - [ ] Set up basic monitoring (platform metrics)
  - [ ] Configure health checks
  - [ ] Set up alerting for critical failures
  - [ ] Test production deployment

### Week 8: Production Readiness
- [ ] **Day 50-52: Security & Performance**
  - [ ] Add rate limiting
  - [ ] Configure TLS/SSL certificates
  - [ ] Implement database connection pooling
  - [ ] Add caching strategies for frequently accessed data
  - [ ] Performance tuning and optimization

- [ ] **Day 53-56: Documentation & Cleanup**
  - [ ] Write comprehensive API documentation
  - [ ] Create deployment guides
  - [ ] Clean up code and add comments
  - [ ] Write architecture decision records (ADRs)
  - [ ] **Milestone**: Production-ready distributed system

---

## Architecture Reference

### Current Project Structure
```
Billington-backend/
├── cmd/
│   ├── bill-service/main.go       ✅ Working
│   └── web-service/main.go         ✅ Working (serves static Next.js)
├── pkg/
│   ├── models/
│   │   └── bill.go                ✅ Complete with PersonShare
│   ├── database/
│   │   └── postgres.go            ✅ Working
│   └── security/
│       └── token.go               ✅ Working
├── internal/
│   ├── bill/
│   │   ├── handler.go             ✅ Complete
│   │   ├── service.go             ✅ Complete
│   │   └── repository.go          ✅ Complete
│   └── web/
│       ├── handler.go             ✅ Complete
│       └── templates/
│           └── bill.html          ✅ Complete
├── web-bill-viewer/               ✅ Next.js app (separate repo)
│   ├── app/
│   │   └── b/[id]/page.tsx
│   ├── components/
│   └── lib/api.ts
├── services/
│   ├── bill-service/Dockerfile    ✅ Working
│   └── web-service/Dockerfile     ✅ Working
├── docker-compose.yml             ✅ Working
└── README.md
```

### Service Architecture
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

---

## Success Metrics

### Technical Achievements
- [X] Working bill-service with CRUD operations
- [X] Secure token-based access control
- [X] Beautiful web interface for bill viewing
- [ ] Flutter integration complete
- [ ] Sub-100ms API response times
- [ ] Handle 100+ concurrent users
- [ ] Production deployment
- [ ] Zero data breaches/privacy violations

### Resume Value
- [X] Demonstrate layered architecture (handler/service/repository)
- [X] Show Go backend development skills
- [X] Prove full-stack capabilities (Go + React)
- [ ] Evidence of payment system integration
- [ ] Display production deployment experience

### Learning Goals
- [X] Comfortable with Go backend development
- [X] Understanding of REST API design
- [X] Experience with Docker and containerization
- [X] Knowledge of database design and ORMs (GORM)
- [ ] Familiarity with production deployment

---

## Current Progress

### Completed Tasks
- [X] Environment setup
- [X] Project structure
- [X] First service running
- [X] Database integration
- [X] Bill CRUD operations with complete data model
- [X] Access token system with secure generation
- [X] Token validation middleware
- [X] Web service for recipients (Go templates)
- [X] Next.js bill viewer with React components
- [X] Beautiful UI matching marketing site
- [X] Venmo deep linking

### Current Focus

**Week**: Week 3-4 transition  
**Goal**: Complete Flutter integration to send bills to backend  
**Blockers**: None currently  
**Next Steps**: 
1. Update Flutter app to POST bills to backend API
2. Test end-to-end flow from app to web viewer
3. Deploy backend to production (Railway/Render)
4. Deploy Next.js viewer to Vercel
5. Test with real URLs

---

## Lessons Learned

### Architecture Decisions
1. **Denormalized PersonShare model**: Storing pre-calculated shares with item details in JSONB makes the web display simple and performant. Source of truth stays in Flutter.

2. **Separate bill viewer app**: Creating a dedicated Next.js app for bill viewing (instead of adding to marketing site) keeps concerns separated and allows independent deployment.

3. **Token-based access**: Using secure random tokens instead of user accounts maintains privacy while enabling sharing.

4. **Go templates vs React**: Started with Go templates, but React provides much better UX and matches the existing design system.

### Technical Insights
- GORM's `serializer:json` tag handles JSONB columns elegantly
- Go's `crypto/rand.Text()` (1.24+) simplifies token generation
- Repository pattern enables easy testing and future database changes
- Gin's template loading needs to happen before route registration

---

## Future Enhancements
- [ ] OCR integration for receipt scanning
- [ ] Payment status tracking and webhooks
- [ ] Multi-currency support
- [ ] Bill history/analytics dashboard
- [ ] Social features (frequent dining partners)
- [ ] Real-time collaboration with WebSockets/SSE
- [ ] Kubernetes orchestration for true microservices

## Test Curl for Local Dev

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
    "participants": [
      { "name": "V" },
      { "name": "J" },
      { "name": "G" },
      { "name": "D" },
      { "name": "M" },
      { "name": "P" }
    ],
    "items": [
      {
        "name": "apps",
        "price": 30.0,
        "assignments": [
          { "person_id": 1, "percentage": 16.67 },
          { "person_id": 2, "percentage": 16.67 },
          { "person_id": 3, "percentage": 16.67 },
          { "person_id": 4, "percentage": 16.67 },
          { "person_id": 5, "percentage": 16.67 },
          { "person_id": 6, "percentage": 16.67 }
        ]
      },
      {
        "name": "beef pad",
        "price": 19.0,
        "assignments": [{ "person_id": 1, "percentage": 100 }]
      },
      {
        "name": "duck",
        "price": 19.0,
        "assignments": [{ "person_id": 2, "percentage": 100 }]
      },
      {
        "name": "beef dui",
        "price": 19.0,
        "assignments": [{ "person_id": 3, "percentage": 100 }]
      },
      {
        "name": "dui chicken",
        "price": 17.0,
        "assignments": [{ "person_id": 4, "percentage": 100 }]
      },
      {
        "name": "pannag curry",
        "price": 17.0,
        "assignments": [{ "person_id": 5, "percentage": 100 }]
      },
      {
        "name": "pork dui",
        "price": 17.0,
        "assignments": [{ "person_id": 6, "percentage": 100 }]
      }
    ],
    "person_shares": [
      {
        "person_name": "V",
        "items": [
          { "name": "apps", "amount": 5.00, "is_shared": true },
          { "name": "beef pad", "amount": 19.00, "is_shared": false }
        ],
        "subtotal": 24.00,
        "tax_share": 1.44,
        "tip_share": 4.80,
        "total": 30.24
      },
      {
        "person_name": "J",
        "items": [
          { "name": "apps", "amount": 5.00, "is_shared": true },
          { "name": "duck", "amount": 19.00, "is_shared": false }
        ],
        "subtotal": 24.00,
        "tax_share": 1.44,
        "tip_share": 4.80,
        "total": 30.24
      },
      {
        "person_name": "G",
        "items": [
          { "name": "apps", "amount": 5.00, "is_shared": true },
          { "name": "beef dui", "amount": 19.00, "is_shared": false }
        ],
        "subtotal": 24.00,
        "tax_share": 1.44,
        "tip_share": 4.80,
        "total": 30.24
      },
      {
        "person_name": "D",
        "items": [
          { "name": "apps", "amount": 5.00, "is_shared": true },
          { "name": "dui chicken", "amount": 17.00, "is_shared": false }
        ],
        "subtotal": 22.00,
        "tax_share": 1.32,
        "tip_share": 4.40,
        "total": 27.72
      },
      {
        "person_name": "M",
        "items": [
          { "name": "apps", "amount": 5.00, "is_shared": true },
          { "name": "pannag curry", "amount": 17.00, "is_shared": false }
        ],
        "subtotal": 22.00,
        "tax_share": 1.32,
        "tip_share": 4.40,
        "total": 27.72
      },
      {
        "person_name": "P",
        "items": [
          { "name": "apps", "amount": 5.00, "is_shared": true },
          { "name": "pork dui", "amount": 17.00, "is_shared": false }
        ],
        "subtotal": 22.00,
        "tax_share": 1.32,
        "tip_share": 4.40,
        "total": 27.72
      }
    ],
    "payment_method": {
      "name": "Venmo",
      "identifier": "@dhaliwgs"
    }
  }'

```