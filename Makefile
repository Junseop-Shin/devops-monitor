.PHONY: up down restart logs ps setup htpasswd

# Start all services
up:
	docker compose up -d

# Stop all services
down:
	docker compose down

# Restart a specific service: make restart svc=grafana
restart:
	docker compose restart $(svc)

# Follow logs: make logs svc=prometheus
logs:
	docker compose logs -f $(svc)

# Show running containers
ps:
	docker compose ps

# First-time setup: copy .env and generate htpasswd
setup:
	@if [ ! -f .env ]; then cp .env.example .env; echo "Created .env — fill in your values"; fi
	@$(MAKE) htpasswd

# Generate nginx basic auth password
htpasswd:
	@read -p "Grafana username: " user; \
	docker run --rm httpd:alpine htpasswd -nb $$user $$(read -sp "Password: " pw; echo; echo $$pw) > nginx/.htpasswd; \
	echo "Created nginx/.htpasswd"

# Reload prometheus config without restart
reload-prometheus:
	curl -X POST http://localhost:9090/-/reload

# Open Grafana in browser (macOS)
open:
	open http://localhost:80

# Check stack health
health:
	@echo "=== Prometheus ===" && curl -s http://localhost:9090/-/healthy
	@echo "\n=== Ingestor ===" && curl -s http://localhost:4000/health
