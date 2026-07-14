# TheFastAndTheRich
# LOCAL DEVELOPMENT SETUP

Version: 1.0  
Status: Living Document  
Document Type: Developer Environment Setup Specification

---

# 1. Purpose

This document defines the local development environment for TheFastAndTheRich.

It describes:

- required tools
- project setup
- backend startup
- frontend startup
- database setup
- Redis setup
- environment configuration
- development workflow

This document is the source of truth for local development.

---

# 2. Development Architecture Overview

TheFastAndTheRich local environment consists of:

- Go backend
- Flutter client
- PostgreSQL database
- Redis instance
- Stripe test environment

---

# 3. Required Software

Developers require:

## Go

Purpose:

Backend development.

Required:

Go version according to go.mod.

---

## Flutter

Purpose:

Mobile client development.

Required:

Flutter SDK.

---

## PostgreSQL

Purpose:

Primary database.

---

## Redis

Purpose:

Cache and event communication.

---

## Docker

Recommended for:

- PostgreSQL
- Redis
- local services

---

## Git

Purpose:

Source control.

---

# 4. Repository Structure

Main structure:

TheFastAndTheRich/

├── backend/

├── frontend/

├── docs/

└── README.md

---

# 5. Backend Setup

Navigate:

backend/

---

Install dependencies:

go mod download

---

Verify installation:

go version

---

# 6. Backend Environment Variables

Backend requires configuration.

Example:

DATABASE_URL

PostgreSQL connection.

---

REDIS_URL

Redis connection.

---

JWT_SECRET

Authentication secret.

---

STRIPE_SECRET_KEY

Stripe test key.

---

STRIPE_WEBHOOK_SECRET

Webhook validation secret.

---

Environment variables must never be committed.

---

# 7. Database Setup

Start PostgreSQL.

Create development database.

Example:

thefastandtherich_dev

---

Run migrations:

migration command depends on configured migration tool.

---

Verify:

- tables exist
- indexes created
- constraints active

---

# 8. Redis Setup

Start Redis instance.

Verify connection:

redis-cli ping

Expected:

PONG

---

Redis is used for:

- cache
- Pub/Sub events
- realtime communication

---

# 9. Start API Server

Navigate:

backend/

Run:

go run cmd/api/main.go

---

Responsibilities:

- REST API
- authentication
- user management
- platform features

---

# 10. Start Game Server

Navigate:

backend/

Run:

go run cmd/game/main.go

---

Responsibilities:

- gameplay sessions
- game processing
- match handling

---

# 11. Flutter Client Setup

Navigate:

frontend/

---

Install dependencies:

flutter pub get

---

Check environment:

flutter doctor

---

# 12. Flutter Configuration

Required configuration:

API base URL

WebSocket URL

Environment mode

---

Development example:

API:

http://localhost

---

WebSocket:

ws://localhost

---

# 13. Authentication Development Flow

Local flow:

Flutter Client

↓

API Server

↓

Authentication Service

↓

Database

↓

Token Response

↓

Secure Storage

---

# 14. Stripe Development Setup

Stripe runs in test mode.

Purpose:

- simulate payments
- test subscriptions
- validate webhook handling

---

Webhook testing requires:

- local webhook endpoint
- Stripe CLI or simulation tool
- configured secrets

---

# 15. Development Workflow

Recommended workflow:

1. Pull latest changes.

2. Start dependencies.

3. Run backend.

4. Run frontend.

5. Implement changes.

6. Run tests.

7. Update documentation.

8. Commit changes.

---

# 16. Debugging

Common areas:

## Backend

Check:

- logs
- database connection
- Redis connection
- environment variables

---

## Frontend

Check:

- API connectivity
- token state
- provider state
- WebSocket connection

---

# 17. Testing Locally

Backend:

Run Go tests.

Example:

go test ./...

---

Frontend:

Run Flutter tests.

Example:

flutter test

---

# 18. Code Quality

Before committing:

Verify:

- formatting
- tests
- documentation
- no secrets

---

# 19. Local Data

Development data may include:

- test accounts
- simulated matches
- test payments

Production data must never be used locally.

---

# 20. Troubleshooting

## Database Connection Failed

Check:

- PostgreSQL running
- credentials correct
- database exists

---

## Redis Connection Failed

Check:

- Redis running
- URL configuration

---

## Authentication Problems

Check:

- JWT configuration
- token storage
- API response

---

## WebSocket Problems

Check:

- server running
- authentication token
- Redis Pub/Sub connection

---

# 21. Future Improvements

Possible additions:

- complete Docker Compose environment
- automated local bootstrap
- development seed system
- one-command startup
- local monitoring tools

---

# End of Local Development Setup
