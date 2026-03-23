# devops-monitor

Self-hosted observability platform for monitoring deployed services across multiple hosts.

## Stack

- **Prometheus** — metrics collection
- **Grafana** — visualization dashboards
- **Loki + Promtail** — log aggregation
- **AlertManager** — alerting → Slack
- **TimescaleDB** — user event analytics
- **Nginx** — reverse proxy + basic auth
- **Cloudflare Tunnel** — secure multi-host connectivity

## Structure

```
devops-monitor/
├── docker-compose.yml          # Main stack
├── prometheus/
│   └── prometheus.yml          # Scrape config
├── loki/
│   └── loki-config.yml
├── promtail/
│   └── promtail-config.yml
├── alertmanager/
│   └── alertmanager.yml        # Slack webhook + alert rules
├── grafana/
│   └── provisioning/
│       ├── datasources/
│       └── dashboards/
├── nginx/
│   └── nginx.conf
└── agents/                     # Config for remote hosts
    ├── docker-compose.agent.yml
    └── promtail-remote.yml
```

## Quick Start

```bash
cp .env.example .env
# Fill in SLACK_WEBHOOK_URL, GRAFANA_PASSWORD
docker compose up -d
```

Grafana: http://localhost:3000
