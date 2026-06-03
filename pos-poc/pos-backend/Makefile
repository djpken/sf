.PHONY: help dev up down logs clean migrate-up migrate-down migrate-create run build test

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

dev: ## Start development environment (PostgreSQL + Redis)
	docker-compose up -d postgres redis

up: ## Start all services
	docker-compose up -d

down: ## Stop all services
	docker-compose down

logs: ## Show logs
	docker-compose logs -f

clean: ## Stop and remove all containers, volumes
	docker-compose down -v

run: ## Run API server locally
	go run cmd/api/main.go

build: ## Build the application
	go build -o bin/api cmd/api/main.go

test: ## Run tests
	go test -v ./...

migrate-up: ## Run database migrations up
	@echo "Running migrations..."
	go run cmd/migrate/main.go up

migrate-down: ## Run database migrations down
	@echo "Rolling back migrations..."
	go run cmd/migrate/main.go down

migrate-create: ## Create a new migration file (usage: make migrate-create name=create_users_table)
	@if [ -z "$(name)" ]; then \
		echo "Error: name is required. Usage: make migrate-create name=your_migration_name"; \
		exit 1; \
	fi
	@timestamp=$$(date +%Y%m%d%H%M%S); \
	touch migrations/$${timestamp}_$(name).up.sql; \
	touch migrations/$${timestamp}_$(name).down.sql; \
	echo "Created migrations/$${timestamp}_$(name).up.sql"; \
	echo "Created migrations/$${timestamp}_$(name).down.sql"

deps: ## Download dependencies
	go mod download
	go mod tidy

.DEFAULT_GOAL := help
