#!/bin/bash

# Database migration script
# Usage: ./scripts/migrate.sh [up|down|force|version]

set -e

DB_HOST="${DATABASE_HOST:-localhost}"
DB_PORT="${DATABASE_PORT:-5432}"
DB_USER="${DATABASE_USER:-pos}"
DB_PASSWORD="${DATABASE_PASSWORD:-pos_password}"
DB_NAME="${DATABASE_NAME:-pos_db}"

MIGRATE_PATH="migrations"
DATABASE_URL="postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable"

command=$1

if [ -z "$command" ]; then
    echo "Usage: $0 [up|down|force|version|create]"
    echo ""
    echo "Commands:"
    echo "  up      Apply all up migrations"
    echo "  down    Apply all down migrations"
    echo "  force   Force set version (requires version number)"
    echo "  version Show current migration version"
    echo "  create  Create a new migration (requires migration name)"
    exit 1
fi

# Check if golang-migrate is installed
if ! command -v migrate &> /dev/null; then
    echo "Error: golang-migrate is not installed"
    echo "Install with: brew install golang-migrate (macOS)"
    echo "Or visit: https://github.com/golang-migrate/migrate"
    exit 1
fi

case "$command" in
    up)
        echo "Running migrations up..."
        migrate -path ${MIGRATE_PATH} -database "${DATABASE_URL}" up
        echo "Migrations completed successfully!"
        ;;
    down)
        echo "Rolling back migrations..."
        migrate -path ${MIGRATE_PATH} -database "${DATABASE_URL}" down
        echo "Rollback completed!"
        ;;
    force)
        if [ -z "$2" ]; then
            echo "Error: Version number required"
            echo "Usage: $0 force <version>"
            exit 1
        fi
        echo "Forcing version to $2..."
        migrate -path ${MIGRATE_PATH} -database "${DATABASE_URL}" force $2
        ;;
    version)
        echo "Current migration version:"
        migrate -path ${MIGRATE_PATH} -database "${DATABASE_URL}" version
        ;;
    create)
        if [ -z "$2" ]; then
            echo "Error: Migration name required"
            echo "Usage: $0 create <migration_name>"
            exit 1
        fi
        timestamp=$(date +%Y%m%d%H%M%S)
        up_file="${MIGRATE_PATH}/${timestamp}_${2}.up.sql"
        down_file="${MIGRATE_PATH}/${timestamp}_${2}.down.sql"
        touch "$up_file"
        touch "$down_file"
        echo "Created migration files:"
        echo "  $up_file"
        echo "  $down_file"
        ;;
    *)
        echo "Unknown command: $command"
        echo "Usage: $0 [up|down|force|version|create]"
        exit 1
        ;;
esac
