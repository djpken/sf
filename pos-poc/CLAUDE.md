# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Structure

```
pos-poc/
├── pos-backend/     # Go API server
└── pos_flutter/     # Flutter client (tablet-optimized)
```

## Backend (pos-backend/)

### Commands
```bash
make dev            # Start PostgreSQL + Redis via Docker Compose
make run            # Run API server (http://localhost:8080)
make build          # Compile binary to bin/api
make test           # Run all Go tests
make migrate-up     # Apply database migrations
make migrate-down   # Rollback migrations
make migrate-create name=<name>  # Create new migration files
make clean          # Remove Docker containers and volumes
```

### Architecture
```
cmd/api/main.go          → Router registration + server startup
internal/handler/        → HTTP handlers (Gin) — request parsing, response formatting
internal/service/        → Business logic
internal/repository/
  postgres/              → PostgreSQL via GORM
  sqlite/                → SQLite (offline fallback)
internal/domain/         → Domain models (structs used across layers)
internal/middleware/      → JWT auth, CORS
internal/integration/    → LINE Pay, TapPay, ECPay e-invoice, delivery platforms
migrations/              → SQL migration files (golang-migrate format)
```

Request flow: `Gin router → Middleware (JWT) → Handler → Service → Repository → DB/Redis`

Config is loaded from `config.yaml` via Viper. Set `mock_mode: true` in payment/invoice/delivery sections to bypass real integrations.

## Frontend (pos_flutter/)

### Commands
```bash
flutter pub get          # Install dependencies
flutter run -d macos     # Run on macOS
flutter run -d chrome    # Run on web
flutter test             # Run tests
./run.sh                 # Interactive platform selector
```

### Architecture
Clean Architecture + BLoC pattern. Design size: 1024×768 (tablet).

```
lib/
├── main.dart                      # App entry, ScreenUtilInit, AuthWrapper
├── core/
│   ├── di/injection.dart          # GetIt DI setup — register all singletons here
│   ├── network/api_client.dart    # Dio with auth interceptor
│   ├── network/connectivity_service.dart  # Online/offline detection
│   ├── storage/secure_storage.dart        # JWT token storage
│   ├── local_db/                  # SQLite: LocalDatabase, MenuCache, OfflineOrderQueue
│   ├── sync/sync_service.dart     # Auto-syncs queued offline orders on reconnect
│   └── constants/                 # AppColors, AppConstants (baseUrl)
├── data/
│   ├── models/                    # Dart data models with fromJson/toJson
│   └── repositories/              # API calls via ApiClient; MenuRepository uses MenuCache
└── presentation/
    ├── auth/                      # Login (email) + PIN login
    ├── home/pages/home_page.dart  # Main NavigationRail hub
    ├── pos/                       # POS ordering page + CartBloc
    ├── orders/                    # Order list + detail + status updates
    ├── tables/                    # Table grid + status management
    ├── reports/                   # Sales dashboard
    └── menu_mgmt/                 # Menu CRUD (in progress)
```

Each feature module follows: `bloc/ (event, state, bloc)` + `pages/` + `widgets/`

### Key Patterns

**Adding a new feature:**
1. Create model in `lib/data/models/`
2. Create repository in `lib/data/repositories/` using `getIt<ApiClient>()`
3. Register repository in `lib/core/di/injection.dart`
4. Create BLoC (event, state, bloc) in `lib/presentation/<feature>/bloc/`
5. Create pages/widgets in `lib/presentation/<feature>/`

**API field mapping:** Backend JSON keys differ from original model names. Always use the fallback pattern:
```dart
json['actual_backend_key'] ?? json['fallback_key']
```
Known mismatches: `tenant_id`/`store_id`, `sort_order`/`display_order`, `is_active`/`is_available`, `name`/`table_number`, `unit_price`/`price`.

**Offline support:** CartBloc checks `ConnectivityService.isOnline`. When offline, orders go to `OfflineOrderQueue` (SQLite). `SyncService` auto-uploads queued orders when connectivity is restored.

## Test Accounts
- Manager: `manager@test.com` / `password123` / PIN `1234`
- Cashier: `cashier1@test.com` / `password123` / PIN `5678`
- Server: `server1@test.com` / `password123` / PIN `9012`
