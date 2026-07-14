# TheFastAndTheRich
# DATABASE SPECIFICATION

Version: 1.0  
Status: Living Document  
Document Type: Database Architecture Specification

---

# 1. Purpose

This document defines the database architecture of TheFastAndTheRich.

It describes:

- database strategy
- data ownership
- entities
- tables
- relationships
- constraints
- indexing strategy
- data lifecycle
- migration principles

This document is the source of truth for all database-related decisions.

---

# 2. Database Philosophy

The database architecture must support:

- high performance
- scalability
- reliability
- data integrity
- security
- historical consistency

The database must preserve competitive fairness.

Historical competition results must remain reproducible.

---

# 3. Database Technology Strategy

## Primary Database

Technology:

PostgreSQL

Purpose:

Primary relational storage.

Used for:

- user accounts
- profiles
- games
- matches
- rankings
- tournaments
- rewards
- configuration data

---

## Cache Database

Technology:

Redis

Purpose:

High-speed temporary data.

Used for:

- sessions
- matchmaking queues
- live lobby state
- temporary rankings
- rate limiting

---

## Event Storage

Purpose:

Historical and asynchronous processing.

Used for:

- domain events
- analytics
- audit trails
- system communication

---

## Object Storage

Purpose:

Large binary data.

Used for:

- avatars
- images
- assets
- reports
- media files

---

# 4. Database Design Principles

## 4.1 Data Ownership

Every service owns its own data.

Services must not directly modify data owned by another service.

Example:

User Service owns:

- users
- authentication data

Ranking Service owns:

- ratings
- leaderboard data

---

## 4.2 Data Integrity

All important relationships must be protected through:

- foreign keys
- constraints
- validation
- transactions

---

## 4.3 Historical Preservation

Competitive data must never be overwritten.

Examples:

- match results
- rankings
- season statistics

Changes create new records instead of modifying history.

---

## 4.4 Migration First

Every database change requires:

- migration file
- documentation
- rollback strategy
- testing

---

# 5. Database Naming Standards

## Tables

Use:

snake_case plural naming.

Examples:

users

player_profiles

matches

game_results


---

## Columns

Use:

snake_case.

Examples:

created_at

updated_at

player_id

game_id

---

## Primary Keys

All primary keys use:

UUID

Reason:

- distributed systems compatibility
- security
- scalability

---

# 6. Core Database Entities

Main entities:

- users
- player_profiles
- user_sessions
- connected_devices
- games
- game_versions
- game_sessions
- matches
- match_players
- match_results
- skill_ratings
- rankings
- seasons
- tournaments
- tournament_players
- achievements
- player_achievements
- rewards
- notifications
- friendships
- parties
- audit_logs

---

# 7. USERS TABLE

Purpose:

Stores account identity.

Owner:

User Service

---

Fields:

id

UUID primary key.

email

Unique login identifier.

username

Unique public identifier.

password_hash

Encrypted password representation.

status

Account state.

email_verified

Email verification state.

mfa_enabled

Multi-factor authentication state.

created_at

Account creation timestamp.

updated_at

Last update timestamp.

deleted_at

Soft deletion timestamp.

---

Rules:

- email must be unique
- username must be unique
- deleted users remain traceable
- passwords are never stored directly

---

# 8. PLAYER_PROFILES TABLE

Purpose:

Stores public player identity.

Owner:

User Service

---

Fields:

id

UUID primary key.

user_id

Reference to users.

display_name

Public name.

avatar_url

Avatar reference.

region

Player region.

level

Progression level.

experience

Accumulated experience.

visibility

Profile visibility.

created_at

Creation timestamp.

updated_at

Update timestamp.

---

Rules:

- one user has one profile
- private information must not exist here

---

# 9. USER_SESSIONS TABLE

Purpose:

Stores active login sessions.

Owner:

User Service

---

Fields:

id

Session identifier.

user_id

User reference.

device_id

Connected device reference.

token_hash

Stored token reference.

created_at

Creation time.

expires_at

Expiration time.

revoked

Session status.

---

# 10. CONNECTED_DEVICES TABLE

Purpose:

Stores trusted player devices.

Owner:

User Service

---

Fields:

id

Device identifier.

user_id

User reference.

device_name

Readable device name.

platform

Operating system.

last_seen

Last activity.

trusted

Trust status.

---

# 11. GAMES TABLE

Purpose:

Stores available skill games.

Owner:

Game Service

---

Fields:

id

Game identifier.

name

Game name.

category

Skill category.

status

Development state.

current_version

Active version.

created_at

Creation timestamp.

---

# 12. GAME_VERSIONS TABLE

Purpose:

Stores historical game versions.

Owner:

Game Service

---

Fields:

id

Version identifier.

game_id

Game reference.

version_number

Version number.

ruleset

Rules configuration.

created_at

Creation timestamp.

---

Rules:

Historical results always reference the exact game version used.

---

# 13. GAME_SESSIONS TABLE

Purpose:

Stores individual game attempts.

Owner:

Match Service

---

Fields:

id

Session identifier.

game_id

Game reference.

player_id

Player reference.

started_at

Start timestamp.

finished_at

Finish timestamp.

status

Session state.

---

# 14. MATCHES TABLE

Purpose:

Stores competitive matches.

Owner:

Match Service

---

Fields:

id

Match identifier.

game_id

Game reference.

status

Match state.

created_at

Creation timestamp.

started_at

Start timestamp.

finished_at

Finish timestamp.

---

# 15. MATCH_PLAYERS TABLE

Purpose:

Stores participants.

Owner:

Match Service

---

Fields:

id

Identifier.

match_id

Match reference.

player_id

Player reference.

position

Final placement.

---

# 16. MATCH_RESULTS TABLE

Purpose:

Stores final outcomes.

Owner:

Match Service

---

Fields:

id

Result identifier.

match_id

Match reference.

player_id

Player reference.

score

Final score.

metrics

Performance measurements.

validated

Validation state.

created_at

Creation timestamp.

---

Rules:

Results become immutable after validation.

---

# 17. SKILL_RATINGS TABLE

Purpose:

Stores player skill measurement.

Owner:

Ranking Service

---

Fields:

id

Identifier.

player_id

Player reference.

game_id

Game reference.

rating

Skill value.

confidence

Rating confidence.

updated_at

Last update.

---

# 18. RANKINGS TABLE

Purpose:

Stores leaderboard positions.

Owner:

Ranking Service

---

Fields:

id

Identifier.

player_id

Player reference.

ranking_type

Ranking category.

position

Current position.

season_id

Season reference.

updated_at

Update timestamp.

---

# 19. SEASONS TABLE

Purpose:

Stores competitive seasons.

Owner:

Tournament Service

---

Fields:

id

Season identifier.

name

Season name.

start_date

Start.

end_date

End.

status

Season state.

---

# 20. TOURNAMENTS TABLE

Purpose:

Stores competitions.

Owner:

Tournament Service

---

Fields:

id

Tournament identifier.

name

Tournament name.

game_id

Related game.

status

Tournament state.

start_time

Start time.

end_time

End time.

---

# 21. ACHIEVEMENTS TABLE

Purpose:

Stores available achievements.

Owner:

Reward Service

---

Fields:

id

Achievement identifier.

name

Achievement name.

description

Requirement description.

type

Achievement category.

---

# 22. PLAYER_ACHIEVEMENTS TABLE

Purpose:

Stores unlocked achievements.

Owner:

Reward Service

---

Fields:

id

Identifier.

player_id

Player reference.

achievement_id

Achievement reference.

unlocked_at

Unlock timestamp.

---

# 23. FRIENDSHIPS TABLE

Purpose:

Stores player relationships.

Owner:

Social Service

---

Fields:

id

Identifier.

requester_id

Sender.

receiver_id

Receiver.

status

Relationship state.

created_at

Creation time.

---

# 24. AUDIT_LOGS TABLE

Purpose:

Stores important system actions.

Owner:

Security Service

---

Fields:

id

Identifier.

actor_id

Responsible user.

event_type

Action type.

metadata

Additional information.

created_at

Timestamp.

---

# 25. Index Strategy

Required indexes:

Users:

- email
- username

Matches:

- player_id
- game_id
- created_at

Rankings:

- player_id
- ranking_type
- position

Events:

- timestamp
- event_type

---

# 26. Backup Strategy

Requirements:

- automated backups
- point-in-time recovery
- encrypted storage
- backup validation

---

# 27. Performance Strategy

Required:

- query optimization
- indexing
- caching
- connection pooling
- read replicas when required

---

# 28. Security Requirements

Database security:

- encrypted connections
- restricted access
- separate credentials
- audit logging
- least privilege principle

---

# 29. Future Extensions

Possible future entities:

- teams
- clans
- creators
- coaches
- sponsors
- marketplace
- esports leagues
- AI training profiles

---

# End of Database Specification
