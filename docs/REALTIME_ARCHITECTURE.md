# TheFastAndTheRich
# REALTIME ARCHITECTURE

Version: 1.0  
Status: Living Document  
Document Type: Real-Time Communication Architecture Specification

---

# 1. Purpose

This document defines the real-time communication architecture of TheFastAndTheRich.

It describes:

- WebSocket architecture
- Redis Pub/Sub integration
- live lobby communication
- real-time events
- connection management
- synchronization strategy

This document represents the actual real-time implementation strategy.

---

# 2. Real-Time Requirements

TheFastAndTheRich requires real-time communication for:

- live lobby
- matchmaking updates
- player presence
- match state updates
- notifications
- tournament events

---

# 3. Architecture Overview

The real-time communication flow:

Flutter Client

↓

WebSocket Connection

↓

WebSocket Handler

↓

Redis Pub/Sub

↓

Backend Services

---

# 4. Technology Stack

## WebSocket

Purpose:

Provides persistent bidirectional communication between:

- client
- server

Used for:

- instant updates
- live states
- event delivery

---

## Redis Pub/Sub

Purpose:

Distributes events between backend components.

Advantages:

- horizontal scalability
- low latency
- separation from PostgreSQL
- simple event broadcasting

---

# 5. Why Redis Pub/Sub

Alternative considered:

PostgreSQL LISTEN/NOTIFY

---

Decision:

Use Redis Pub/Sub.

---

Reasons:

- better suited for high-frequency events
- easier scaling across multiple servers
- avoids database event workload
- independent event infrastructure

---

# 6. WebSocket Architecture

The WebSocket layer is responsible for:

- maintaining client connections
- subscribing users to events
- forwarding relevant events
- handling disconnects

---

The WebSocket layer must not contain:

- business logic
- ranking calculations
- matchmaking calculations

---

# 7. Connection Lifecycle

## Connection Start

Client connects.

↓

Server validates authentication.

↓

Connection is registered.

↓

User presence becomes active.

---

## Active Connection

Server:

- listens for Redis events
- sends relevant updates
- maintains connection state

---

## Disconnect

Server:

- removes connection
- updates presence
- cleans resources

---

# 8. Authentication

WebSocket connections require authentication.

Validation:

- access token
- user identity
- session validity

---

Unauthorized connections are rejected.

---

# 9. Channel Architecture

Redis channels are organized by purpose.

Examples:

## Global Channel

Used for:

- global announcements
- system events

---

## User Channel

Example:

user:{user_id}

Used for:

- personal notifications
- private updates

---

## Match Channel

Example:

match:{match_id}

Used for:

- live match events

---

## Lobby Channel

Used for:

- lobby updates
- presence changes

---

# 10. Event Flow Example

Match Found:

Matchmaking Service

↓

MATCH_FOUND Event

↓

Redis Pub/Sub

↓

WebSocket Layer

↓

Flutter Client

↓

Riverpod State Update

↓

UI Update

---

# 11. Live Lobby Architecture

The live lobby displays:

- online players
- active matches
- available games
- matchmaking status
- notifications

---

Lobby updates happen through events.

Examples:

PLAYER_ONLINE

PLAYER_OFFLINE

PLAYER_STATUS_CHANGED

MATCH_AVAILABLE

---

# 12. Presence System

The presence system tracks:

- online status
- last activity
- current location

Possible states:

ONLINE

OFFLINE

IN_MATCH

IN_QUEUE

AWAY

---

# 13. Matchmaking Real-Time Flow

Player action:

Join Queue

↓

Matchmaking Service

↓

Queue Update Event

↓

Redis

↓

WebSocket

↓

Client Update

---

When match found:

MATCH_FOUND Event

contains:

- match id
- opponent information
- game mode
- server information

---

# 14. Match Live Events

During gameplay possible events:

MATCH_STARTED

PLAYER_ACTION

SCORE_UPDATE

MATCH_COMPLETED

---

Sensitive calculations remain server-side.

Client only receives validated updates.

---

# 15. Event Delivery Rules

Events must contain:

- event id
- timestamp
- type
- payload
- target

---

# 16. Duplicate Event Handling

Clients must handle:

- duplicate messages
- delayed messages
- missing messages

---

Synchronization strategy:

- event identifiers
- state refresh requests
- server authority

---

# 17. Reconnection Handling

When connection is lost:

Client:

- detects disconnect
- retries connection
- restores subscriptions

Server:

- validates session
- restores user state

---

# 18. Scaling Strategy

Multiple WebSocket servers are supported.

Architecture:

Client

↓

Load Balancer

↓

WebSocket Instances

↓

Redis Pub/Sub

---

Redis allows events to reach users regardless of WebSocket instance.

---

# 19. Performance Requirements

Realtime systems should optimize:

- message size
- event frequency
- connection handling
- memory usage

---

# 20. Security Requirements

Realtime communication requires:

- authentication
- authorization
- rate limiting
- message validation

---

# 21. Monitoring

Monitor:

- active connections
- message rate
- latency
- disconnect rate
- failed deliveries

---

# 22. Future Extensions

Possible additions:

- dedicated realtime gateway
- event streaming system
- presence cluster
- regional realtime servers
- advanced matchmaking communication

---

# End of Real-Time Architecture
