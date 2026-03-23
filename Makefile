.PHONY: up down restart logs ps setup reload-prometheus open health

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

# First-time setup: copy .env
setup:
	@if [ ! -f .env ]; then cp .env.example .env; echo "Created .env — fill in GRAFANA_PASSWORD, SLACK_WEBHOOK_URL, CLOUDFLARE_TUNNEL_TOKEN"; fi

# Reload prometheus config without restart
reload-prometheus:
	curl -X POST http://localhost:9090/-/reload

# Open Grafana locally in browser (macOS)
open:
	open http://localhost:3000

# Check stack health
health:
	@echo "=== Prometheus ===" && curl -s http://localhost:9090/-/healthy
	@echo "\n=== Ingestor ===" && curl -s http://localhost:4000/health
