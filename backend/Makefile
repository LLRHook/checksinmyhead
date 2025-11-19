.PHONY: setup up down logs clean test

up: ## Start services
	docker-compose up --build

down: ## Stop services
	docker-compose down -v

logs: ## View logs
	docker-compose logs -f

test: ## Test the health endpoint
	curl localhost:8080/health