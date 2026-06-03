# AGENT.md

This repository contains two Flutter applications and one Go backend proof of concept. Follow these instructions when working in this workspace.

## Required Shell Wrapper

The workspace-level instruction file imports `~/.codex/RTK.md`.

Always prefix shell commands with `rtk`:

```bash
rtk git status
rtk go test ./...
rtk flutter analyze
```

If `rtk` cannot express a command cleanly, use `rtk proxy <command>`.

## Repository Layout

```text
/Users/kunkun/Projects/sf
├── pos-poc/
│   ├── pos-backend/     # Go + Gin POS API server
│   ├── pos_flutter/     # Flutter POS client
│   ├── req.md           # Original POS system design notes
│   └── CLAUDE.md        # Existing agent guidance for POS work
└── warehouse-keeper/    # Flutter warehouse inventory app
```

## POS Backend

Path: `/Users/kunkun/Projects/sf/pos-poc/pos-backend`

Stack:
- Go 1.21+
- Gin
- PostgreSQL
- Redis
- GORM
- Viper config
- Zap logging
- Docker Compose for local dependencies

Common commands:

```bash
rtk make dev
rtk make run
rtk make build
rtk make test
rtk make migrate-up
rtk make migrate-down
rtk go build ./...
rtk go test ./...
```

Architecture:
- `cmd/api/main.go`: application bootstrap and route registration.
- `internal/domain/`: shared domain structs.
- `internal/handler/`: Gin HTTP handlers.
- `internal/service/`: business logic.
- `internal/repository/postgres/`: GORM-backed persistence.
- `internal/middleware/`: JWT auth and CORS.
- `internal/integration/`: payment, e-invoice, and delivery integrations.
- `pkg/utils/`: shared utility helpers.
- `migrations/`: SQL migration files.

Request flow:

```text
Gin router -> middleware -> handler -> service -> repository -> PostgreSQL/Redis
```

Config is loaded from `config.yaml`. Payment, invoice, and delivery integrations default to mock mode. Keep mock mode enabled for local development unless real credentials are explicitly available.

## POS Flutter Client

Path: `/Users/kunkun/Projects/sf/pos-poc/pos_flutter`

Stack:
- Flutter / Dart
- Clean Architecture
- BLoC
- GetIt dependency injection
- Dio API client
- flutter_secure_storage and shared_preferences
- SQLite cache/offline queue through `sqflite`
- Material 3
- Generated localization from `lib/l10n/*.arb`

Common commands:

```bash
rtk flutter pub get
rtk flutter analyze
rtk flutter test
rtk flutter run -d chrome
rtk flutter run -d macos
rtk ./run.sh
```

Architecture:
- `lib/main.dart`: app entry, localization, `ScreenUtilInit`, auth wrapper.
- `lib/core/di/injection.dart`: GetIt registrations. Register new repositories/services here.
- `lib/core/network/api_client.dart`: Dio client and auth behavior.
- `lib/core/local_db/`: local database, menu cache, and offline order queue.
- `lib/core/sync/sync_service.dart`: reconnect sync for queued offline orders.
- `lib/data/models/`: JSON models.
- `lib/data/repositories/`: API/data access layer.
- `lib/presentation/`: feature UI, BLoC, and widgets.

Feature modules should follow:

```text
presentation/<feature>/
├── bloc/
├── pages/
└── widgets/
```

When mapping backend JSON, preserve the fallback style already used in this project because backend and frontend field names are not fully aligned. Known mismatches include `tenant_id`/`store_id`, `sort_order`/`display_order`, `is_active`/`is_available`, `name`/`table_number`, and `unit_price`/`price`.

## Warehouse Keeper

Path: `/Users/kunkun/Projects/sf/warehouse-keeper`

Stack:
- Flutter / Dart
- Material app
- Local model-driven UI for store selection and monthly inventory flows

Common commands:

```bash
rtk flutter pub get
rtk flutter analyze
rtk flutter test
rtk flutter run -d chrome
rtk flutter run -d macos
```

Current structure:
- `lib/main.dart`: app entry.
- `lib/theme/app_theme.dart`: app styling.
- `lib/models/`: inventory-related models.
- `lib/screens/`: store selection, inventory menu, monthly inventory, and zone detail screens.
- `test/widget_test.dart`: smoke test.

## Current Implementation Status

As of 2026-05-11:

- `pos-poc/pos-backend` is implemented enough to compile successfully with `rtk go build ./...`.
- Backend routes are registered for auth, menu, orders, tables, reports, invoices, and delivery webhooks/status updates.
- Backend has no `_test.go` files, so `rtk go test ./...` reports no Go tests rather than meaningful test coverage.
- Real third-party integrations are incomplete. LINE Pay, credit card/TapPay, ECPay e-invoice, Foodpanda, and Uber Eats have mock implementations or TODO-backed real clients.
- Swagger UI is documented as pending.
- `pos-poc/pos_flutter` passes `rtk flutter analyze`.
- `pos-poc/pos_flutter` has implemented modules for auth, home, POS ordering, orders, tables, reports, and menu management, but no `test/` directory is present.
- `warehouse-keeper` passes `rtk flutter analyze` and `rtk flutter test`.
- `warehouse-keeper` appears to be a focused inventory app with store selection and monthly inventory screens; its README is still the default Flutter starter README.
- The root git repository currently treats `.DS_Store`, `pos-poc/`, and `warehouse-keeper/` as untracked files.

## Development Guidelines

- Keep changes scoped to the relevant subproject.
- Do not rewrite generated or build output under Flutter `build/`.
- For Go changes, keep the handler/service/repository boundaries intact.
- For Flutter changes, keep BLoC state and event definitions near the feature they serve.
- Prefer adding focused tests when changing business logic, persistence, or cross-module behavior.
- Do not replace mock integrations with real external calls unless credentials, sandbox behavior, and error handling are part of the task.
- Do not commit secrets. Treat `config.yaml` as local configuration and prefer `config.example.yaml` for shareable defaults.

## Verification Checklist

Use the smallest relevant verification set:

```bash
# Backend
rtk go build ./...
rtk go test ./...

# POS Flutter
rtk flutter analyze
rtk flutter test

# Warehouse Keeper
rtk flutter analyze
rtk flutter test
```

For frontend visual or interaction changes, also run the relevant app locally and inspect the affected screen.
