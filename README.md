# TheFastAndTheRich

Mobile-first Plattform für skill-basierte Echtzeit-Wettbewerbe mit Coin-Wallet-System.

## Architektur

```
thefastandtherich/
├── backend/          # Go-Monorepo (api-server + game-server)
│   ├── cmd/
│   │   ├── api/main.go
│   │   └── game/main.go
│   ├── internal/
│   │   ├── auth/     # JWT + Argon2id
│   │   ├── wallet/   # Stripe Test + fn_apply_transaction
│   │   ├── match/    # Dynamic Arena + Lifecycle
│   │   ├── websocket/# Redis Pub/Sub
│   │   ├── middleware/# CORS + Auth
│   │   ├── models/   # OpenAPI-Structs
│   │   └── config/
│   └── pkg/argon2/   # Passwort-Hashing
├── frontend/         # Flutter (iOS, Android, Web)
│   ├── lib/
│   │   ├── screens/  # Login, Register, Verify, Lobby, Wallet, 5 Spiele
│   │   ├── providers/# Riverpod (Auth, Wallet)
│   │   ├── services/ # API + WebSocket
│   │   └── models/   # User, Wallet, Transaction
│   └── pubspec.yaml
├── infra/            # Docker-Compose & DB-Migrationen
│   └── migrations/
│       ├── 001_init_schema.sql
│       ├── 002_auth_extensions.sql
│       ├── 003_attempts_extension.sql
│       └── 004_seed_matches.sql
└── docker-compose.yml
```

## Tech-Stack

| Schicht | Technologie |
|---------|-------------|
| Mobile/Web | Flutter / Dart |
| Backend | Go 1.22 |
| API | REST (OpenAPI 3.0.3) + WebSocket |
| Datenbank | PostgreSQL 15 |
| Cache/Echtzeit | Redis 7 |
| Auth | JWT (Access 15min + Refresh 7d) + Argon2id |
| Zahlungen | Stripe Test/Sandbox |

## Schnellstart

### 1. Repository entpacken

```bash
cd thefastandtherich
```

### 2. Umgebungsvariablen

```bash
cp .env.example .env
# Optional: STRIPE_SECRET_KEY anpassen
```

### 3. Infrastruktur starten (Postgres + Redis)

```bash
docker-compose up -d postgres redis
```

Migrationen 001-004 werden automatisch eingespielt:
- `001_init_schema.sql` — Core Schema (Users, Wallets, Matches, Ledger)
- `002_auth_extensions.sql` — Verification Codes + Refresh Tokens
- `003_attempts_extension.sql` — Spiel-Input Payload
- `004_seed_matches.sql` — Auto-Match-Creation Function

### 4. Backend-Abhängigkeiten laden

```bash
cd backend
go mod tidy
```

### 5. API-Server starten

```bash
go run cmd/api/main.go
```

### 6. Game-Server starten (neues Terminal)

```bash
go run cmd/game/main.go
```

### 7. Flutter-App starten

```bash
cd ../frontend
flutter pub get
flutter run -d chrome        # Web
flutter run -d ios            # iOS Simulator
flutter run -d android        # Android Emulator
```

> **Hinweis:** Für mobile Emulatoren `localhost` in `lib/providers/auth_provider.dart` durch Host-IP ersetzen (z.B. `10.0.2.2` für Android).

## Korrekter Test-Flow (Ende-zu-Ende)

```
1. Registrieren → Verify-Code eingeben (steht in Server-Logs) → Login
2. Wallet öffnen → "Coins einzahlen" → 100 Coins
   → Server: fn_apply_transaction('DEPOSIT', 100)
   → Balance zeigt 100 Coins
3. Lobby: Stake "1 C" auswählen
   → Auto-Creation: fn_ensure_open_matches() erstellt Matches
   → Match-Liste zeigt Pot + Teilnehmerzahl (live via WebSocket)
4. "Beitreten" klicken
   → 1 Coin ENTRY_FEE via fn_apply_transaction
   → reserved_coins +1
   → WebSocket: match.updated an alle Clients
   → GameScreen öffnet sich (basierend auf gameName)
5. Spiel spielen (Reaction Tap / Precision Timing / Sequence Memory / Aim & Click / Math Sprint)
   → Seed-basierte Verzögerung/Generierung
   → Vollständiger Payload an Server
6. Server validiert & wertet aus
   → niedrigste duration_ms / höchster Score gewinnt
   → PAYOUT = Pot - 0.1% Gebühr
   → Ledger-Buchung für Gewinner
   → Profile-Stats aktualisiert
7. Wallet-Historie zeigt:
   → ENTRY_FEE: -X Coins
   → PAYOUT: +X Coins (falls Gewinner)
```

## API-Endpunkte

| Methode | Pfad | Auth | Beschreibung |
|---------|------|------|-------------|
| POST | /v1/auth/register | Nein | Registrierung |
| POST | /v1/auth/login | Nein | Login |
| POST | /v1/auth/verify | Nein | E-Mail-Verifizierung |
| POST | /v1/auth/refresh | Nein | Token-Refresh |
| POST | /v1/auth/logout | Ja | Logout |
| GET | /v1/wallet | Ja | Wallet-Status |
| POST | /v1/wallet/deposit | Ja | Stripe-Einzahlung |
| POST | /v1/wallet/withdraw | Ja | Auszahlung (KYC erforderlich) |
| GET | /v1/wallet/transactions | Ja | Transaktionshistorie |
| GET | /v1/games | Ja | Verfügbare Spiele |
| GET | /v1/matches | Ja | Offene Matches (Query: category) |
| GET | /v1/matches/:id | Ja | Match-Details |
| POST | /v1/matches/:id/join | Ja | Beitritt mit Reservierung |
| POST | /v1/matches/:id/attempts/:id/submit | Ja | Ergebnis einreichen |
| GET | /v1/matches/:id/results | Ja | Rangliste |
| GET | /v1/ws | Ja (Query: token) | WebSocket für Live-Events |

## Stripe Testmodus

Testkarten:
- `4242 4242 4242 4242` — Erfolgreiche Zahlung
- `4000 0000 0000 0002` — Abgelehnte Zahlung

## Leitprinzipien

- **Keine Mock-Daten:** Jede Zahl kommt aus der Datenbank.
- **Ledger-Prinzip:** Alle Coin-Bewegungen laufen über `fn_apply_transaction()`.
- **Backend-first:** Business-Logik (Gewinner, Gebühren) liegt im Backend.
- **Echtzeit:** WebSocket-Events durch echte Serverereignisse (Redis Pub/Sub).

## Lizenz

Intern — TheFastAndTheRich Engineering.
