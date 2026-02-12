.PHONY: setup up down logs clean test

up: ## Start services
	docker-compose up --build

down: ## Stop services
	docker-compose down -v

logs: ## View logs
	docker-compose logs -f

test: ## Run Go unit tests
	go test -v -race ./internal/... ./pkg/...

dev: ## Start full stack (use root dev.sh instead)
	@echo "Run ./dev.sh from the project root to start all services."
