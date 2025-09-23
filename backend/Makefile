.PHONY: setup up down logs clean test

setup: ## Copy .env.example to .env
	cp .env.example .env

up: ## Start services
	docker-compose up --build

down: ## Stop services
	docker-compose down

logs: ## View logs
	docker-compose logs -f

clean: ## Stop and remove everything
	docker-compose down -v

test: ## Test the health endpoint
	curl localhost:8080/health