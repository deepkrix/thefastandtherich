# TheFastAndTheRich
# BACKEND ARCHITECTURE

Version: 1.0  
Status: Living Document  
Document Type: Backend Technical Architecture Specification

---

# 1. Purpose

This document defines the current backend architecture of TheFastAndTheRich.

It describes:

- backend technology stack
- repository structure
- service responsibilities
- application lifecycle
- database communication
- cache usage
- event communication
- deployment model

This document represents the actual implementation architecture.

---

# 2. Backend Overview

TheFastAndTheRich backend is implemented as a Go monorepo.

The backend contains two executable binaries:

- api-server
- game-server

The separation allows clear responsibility boundaries between:

- platform communication
- competitive gameplay processing

---

# 3. Technology Stack

## Programming Language

Go

Purpose:

- high performance
- concurrency support
- scalable backend services

---

## HTTP Framework

Gin

Purpose:

- HTTP routing
- middleware handling
- API endpoint management

---

## Database Driver

pgx/v5

Purpose:

- PostgreSQL communication
- optimized database access
- native PostgreSQL features

---

## Cache and Event Layer

go-redis/v9

Purpose:

- Redis communication
- caching
- Pub/Sub events

---

## Database

PostgreSQL

Purpose:

Persistent storage for:

- users
- profiles
- games
- matches
- rankings
- payments
- statistics

---

## Cache

Redis

Purpose:

Temporary and high-performance operations.

Examples:

- live states
- matchmaking data
- WebSocket event distribution

---

# 4. Repository Structure

Current backend structure:

backend/

├── cmd/

│   ├── api/

│   │   └── main.go

│   │

│   └── game/

│       └── main.go


├── internal/

│   ├── auth/

│   ├── database/

│   ├── redis/

│   ├── users/

│   ├── games/

│   ├── matches/

│   └── shared/


├── migrations/

├── go.mod

└── go.sum

---

# 5. Binary Architecture

## api-server

Responsible for:

- HTTP API
- authentication
- user management
- lobby communication
- payments
- administrative functions

---

Responsibilities:

- receive client requests
- validate input
- execute business logic
- communicate with database
- publish events

---

## game-server

Responsible for:

- real-time gameplay
- game sessions
- game state
- score validation

---

Responsibilities:

- manage active matches
- process gameplay events
- validate results
- communicate completed results

---

# 6. API Server Flow

Request lifecycle:

Client

↓

Gin Router

↓

Middleware

↓

Handler

↓

Service Layer

↓

Repository Layer

↓

PostgreSQL

---

# 7. Layer Architecture

The backend follows layered architecture.

---

# Handler Layer

Responsible for:

- HTTP requests
- validation
- response formatting

Does not contain:

- business logic
- database queries

---

# Service Layer

Responsible for:

- business rules
- workflows
- coordination

Examples:

- authentication logic
- matchmaking logic
- reward calculation

---

# Repository Layer

Responsible for:

- database communication
- queries
- persistence

---

# Domain Layer

Responsible for:

- entities
- business models
- rules

---

# 8. Database Communication

PostgreSQL access uses:

pgx/v5

Requirements:

- prepared queries where needed
- transactions for critical operations
- context-aware operations

---

Critical transactional areas:

- match results
- ranking updates
- payments
- rewards

---

# 9. Redis Usage

Redis is used for:

## Cache

Examples:

- frequently requested player data
- temporary game information

---

## Pub/Sub

Used for:

- WebSocket event distribution
- live lobby updates
- matchmaking events

---

# 10. Event Architecture

Redis Pub/Sub is used instead of PostgreSQL LISTEN/NOTIFY.

Reason:

Redis Pub/Sub provides:

- easier horizontal scaling
- separation from database workload
- better real-time distribution

---

Event flow:

Service

↓

Redis Channel

↓

WebSocket Layer

↓

Connected Clients

---

# 11. Authentication Architecture

Authentication system handles:

- registration
- login
- token generation
- session management

Security requirements:

- password hashing
- secure token handling
- protected routes

---

# 12. Payment Integration

Stripe integration currently uses:

Test mode

Purpose:

- payment flow development
- webhook testing
- transaction simulation

---

Webhook flow:

Stripe

↓

Webhook Endpoint

↓

Validation

↓

Business Processing

↓

Database Update

---

# 13. Error Handling

Backend errors must:

- use consistent error responses
- contain internal logs
- avoid exposing sensitive information

---

# 14. Configuration Management

Configuration must use:

- environment variables
- secure secrets

Never:

- hardcode credentials
- commit secrets

---

# 15. Concurrency Model

Go concurrency is used for:

- real-time connections
- background processing
- event handling

Concurrency must consider:

- race conditions
- resource cleanup
- graceful shutdown

---

# 16. Testing Requirements

Backend tests include:

- unit tests
- service tests
- repository tests
- API tests

Critical systems:

- authentication
- matchmaking
- payments
- scoring

require additional coverage.

---

# 17. Future Backend Extensions

Possible additions:

- dedicated matchmaking service
- message queue system
- distributed game servers
- metrics infrastructure
- tracing system

---

# End of Backend Architecture
