# Spliq Backend Development Roadmap

## Project Overview
Transform Spliq from a local Flutter app into a distributed microservices architecture with real-time bill sharing, payment integration, and collaborative features - all while maintaining privacy-first principles.

## Goals
- **Primary**: Build impressive distributed systems experience for resume
- **Secondary**: Create a production-ready bill splitting platform
- **Learning**: Master Go, microservices, Kubernetes, real-time systems

---

## Phase 1: Foundation (Week 1-2)
*Goal: Get basic infrastructure running locally*

### Week 1: Environment & Project Setup
- [ ] **Day 1-2: Development Environment**
  - [X] Install Go 1.21+ on development machine
  - [X] Install Docker & Docker Compose
  - [ ] Set up DigitalOcean Kubernetes cluster OR install K3s on home lab
  - [X] Create GitHub repository with proper .gitignore
  - [X] Initialize Go module: `go mod init github.com/username/spliq-backend`

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
- [ ] **Day 8-10: Database Setup**
  - [X] Add PostgreSQL to docker-compose
  - [ ] Install database migration tool (golang-migrate)
  - [X] Create initial database schema
  - [X] Set up database connection in `pkg/database/`
  - [X] Add environment variable configuration

- [ ] **Day 11-14: Bill CRUD Operations**
  - [ ] Complete `Bill`, `BillItem`, `Person`, `ItemAssignment` models in `pkg/models/bill.go`
  - [ ] Implement `internal/bill/repository.go` with database operations
  - [ ] Implement `internal/bill/service.go` with business logic
  - [ ] Complete `internal/bill/handler.go` with HTTP endpoints
  - [ ] **Milestone**: Can create and retrieve bills via API

---

## Phase 2: Core Functionality (Week 3-4)
*Goal: Working bill sharing with real-time updates*

### Week 3: Bill Sharing & Access Control
- [ ] **Day 15-17: Security & Access Tokens**
  - [ ] Implement secure token generation for bill access
  - [ ] Add token validation middleware
  - [ ] Create bill sharing URL format: `/b/{billId}?t={token}`
  - [ ] Create web service for recipient bill viewing
  - [ ] Add web pages for recipients to view their portions
  - [ ] Test bill access control

- [ ] **Day 18-21: Flutter Integration**
  - [ ] Update Flutter app to call backend APIs
  - [ ] Add HTTP client service in Flutter
  - [ ] Update bill creation flow to generate shareable links
  - [ ] Test bill sharing between devices
  - [ ] **Milestone**: Can share bills between Flutter apps

### Week 4: Real-time Updates
- [ ] **Day 22-25: Event System**
  - [ ] Set up Redis for event caching
  - [ ] Create `pkg/models/events.go` with event structures
  - [ ] Implement `internal/events/` service for event publishing
  - [ ] Add event publishing to bill operations
  - [ ] Create event polling endpoint for clients

- [ ] **Day 26-28: Flutter Real-time**
  - [ ] Add polling mechanism to Flutter app
  - [ ] Show real-time payment status updates
  - [ ] Add "who's viewing" indicators
  - [ ] Test multi-device collaboration
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
  - [ ] Implement Venmo deep linking
  - [ ] Implement Venmo deep linking for web recipients
  - [ ] Add Zelle integration (if available)
  - [ ] Create payment webhooks for status updates
  - [ ] Add payment status tracking
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

### Week 7: Kubernetes Deployment
- [ ] **Day 43-45: Container Orchestration**
  - [ ] Create Kubernetes manifests for all services
  - [ ] Set up ConfigMaps and Secrets
  - [ ] Configure service discovery and load balancing
  - [ ] Deploy to DigitalOcean Kubernetes (or home lab)
  - [ ] Test service-to-service communication

- [ ] **Day 46-49: Monitoring & Observability**
  - [ ] Add structured logging to all services
  - [ ] Set up Prometheus metrics collection
  - [ ] Configure Grafana dashboards
  - [ ] Add distributed tracing (optional)
  - [ ] Set up alerting for critical failures

### Week 8: Production Readiness
- [ ] **Day 50-52: Security & Performance**
  - [ ] Add rate limiting and DDoS protection
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

### Project Structure
```
spliq-backend/
├── cmd/
│   ├── bill-service/main.go
│   ├── web-service/main.go
│   ├── event-service/main.go
│   └── payment-service/main.go
├── pkg/
│   ├── models/
│   │   ├── bill.go
│   │   ├── payment.go
│   │   └── events.go
│   └── database/
│       └── postgres.go
├── internal/
│   ├── bill/
│   │   ├── handler.go
│   │   ├── service.go
│   │   └── repository.go
│   ├── web/
│   │   ├── handler.go
│   │   ├── service.go
│   │   └── templates/
│   ├── events/
│   │   ├── handler.go
│   │   ├── service.go
│   │   └── repository.go
│   └── payments/
│       ├── handler.go
│       ├── service.go
│       └── repository.go
├── deployments/k8s/
├── migrations/
├── docker-compose.yml
└── README.md
```

### Service Architecture
```
┌─────────────────┐    ┌─────────────────┐
│   Mobile App    │    │   Web Recipients│
└─────────┬───────┘    └─────────┬───────┘
          │                      │
    ┌─────┴──────────────────────┴─────┐
    │      Load Balancer/Ingress      │
    └─────┬────────────────────────────┘
          │
    ┌─────┴─────┐
    │           │
┌───▼────┐  ┌──▼──────┐  ┌────────▼─┐  ┌────────▼─┐
│  Bill  │  │   Web   │  │ Events  │  │ Payments │
│Service │  │ Service │  │ Service │  │ Service  │
└────────┘  └─────────┘  └─────────┘  └──────────┘
     │           │           │           │
┌────▼────┐ ┌───▼────┐ ┌───▼────┐ ┌────▼─────┐
│Bills DB │ │Bills DB│ │ Redis  │ │Payments  │
│         │ │ (Read) │ │ Cache  │ │    DB    │
└─────────┘ └────────┘ └────────┘ └──────────┘
```

---

## Success Metrics

### Technical Achievements
- [ ] 4+ microservices running independently
- [ ] Sub-100ms API response times
- [ ] Handle 100+ concurrent users
- [ ] 99.9% uptime over 30 days
- [ ] Zero data breaches/privacy violations

### Resume Value
- [ ] Demonstrate microservices architecture
- [ ] Show Kubernetes orchestration experience
- [ ] Prove real-time system capabilities
- [ ] Evidence of payment system integration
- [ ] Display monitoring and observability setup

### Learning Goals
- [ ] Comfortable with Go backend development
- [ ] Understand distributed systems patterns
- [ ] Experience with container orchestration
- [ ] Knowledge of event-driven architecture
- [ ] Familiarity with production deployment

---

## Troubleshooting & Resources

### Common Issues
- **Database connection problems**: Check connection strings and network access
- **Service discovery issues**: Verify Kubernetes DNS and service configurations
- **Payment integration failures**: Review API credentials and webhook configurations
- **Performance bottlenecks**: Monitor database queries and add caching
- **Deployment problems**: Check resource limits and pod logs

### Learning Resources
- [Effective Go](https://golang.org/doc/effective_go.html)
- [Microservices Patterns](https://microservices.io/patterns/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Gin Web Framework](https://gin-gonic.com/docs/)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)

---

## Progress Tracking

### Completed Tasks
- [ ] Environment setup
- [ ] Project structure
- [ ] First service running
- [ ] Database integration
- [ ] Bill CRUD operations
- [ ] Access token system
- [ ] Flutter integration
- [ ] Web service for recipients
- [ ] Event system
- [ ] Real-time updates
- [ ] Payment service
- [ ] Venmo integration
- [ ] Kubernetes deployment
- [ ] Monitoring setup
- [ ] Production readiness

### Current Focus
*Update this section as you progress*

**Week**: [Current week number]  
**Goal**: [Current week's main objective]  
**Blockers**: [Any current obstacles]  
**Next Steps**: [Immediate next actions]

---

## Notes & Decisions
*Use this section to document important architectural decisions, lessons learned, and insights gained during development*

### Lessons Learned
*Document key insights as you build*

### Future Enhancements
- [ ] OCR integration for receipt scanning
- [ ] Advanced analytics dashboard
- [ ] Multi-currency support
- [ ] Restaurant integration APIs
- [ ] Social features (frequent dining partners)