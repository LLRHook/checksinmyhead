.PHONY: up down logs test dev reset-test

up: ## Start PostgreSQL and API
	docker compose up --build

down: ## Stop services; preserve all data volumes
	docker compose down

logs: ## View logs
	docker compose logs -f

test: ## Run Go unit tests
	go test -v -race ./...

dev: ## Start full stack from root
	../dev.sh

reset-test: ## Destroy only explicitly selected, ownership-labelled synthetic test data
	python3 ../scripts/reset_local_test.py --project "$(TEST_PROJECT)" --owner "$(TEST_OWNER)"
