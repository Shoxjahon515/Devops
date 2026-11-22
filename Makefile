.DEFAULT_GOAL := help
.PHONY: help install run lint format test test-pg up down logs ps scale clean

help:            ## Show this help
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

install:         ## Install dev dependencies into the active virtualenv
	pip install -r requirements-dev.txt

run:             ## Run the API locally with auto-reload (SQLite)
	uvicorn app.main:app --reload

lint:            ## Static checks
	ruff check .
	ruff format --check .

format:          ## Auto-format the code
	ruff format .
	ruff check --fix .

test:            ## Run tests on SQLite
	pytest -q

test-pg:         ## Run tests on PostgreSQL (set TEST_DATABASE_URL)
	@test -n "$(TEST_DATABASE_URL)" || (echo "set TEST_DATABASE_URL" && exit 1)
	pytest -q

up:              ## Build and start the Docker stack
	@test -f .env || cp .env.example .env
	docker compose up --build -d

down:            ## Stop the stack (data is kept)
	docker compose down

logs:            ## Follow API and nginx logs
	docker compose logs -f api nginx

ps:              ## Show container health
	docker compose ps

scale:           ## Run 3 API replicas behind nginx
	docker compose up -d --scale api=3

clean:           ## Remove caches and the local SQLite file
	rm -rf .pytest_cache .ruff_cache payfast.db
	find . -name __pycache__ -type d -prune -exec rm -rf {} +
