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

## Dashboards

### 로그 (`uid: logs`)

| 패널 | 타입 | 설명 |
|------|------|------|
| 24시간 에러 수 | stat | 레벨 기준 에러 카운트 (`ERROR\|FATAL\|CRITICAL`) |
| 에러 로그 | logs | 레벨 기반 필터 — `[ \["'](error\|fatal\|critical)[ :\]"',}]` |
| 전체 로그 | logs | 컨테이너 전체 로그 스트림 |
| PM2 프로세스 상태 (Windows) | stat | `pm2_up` — UP/DOWN 표시 |
| 재시작 횟수 | stat | `pm2_restarts` — 가로 레이아웃 |
| PM2 재시작 추이 | timeseries | `pm2_restarts` 시계열 |

> Loki `timeseries` 패널은 Grafana 12 Scenes 아키텍처 버그로 렌더링 불가 → `logs` 타입으로 대체.
> 에러 필터는 단순 텍스트 매칭이 아닌 레벨 경계 패턴 사용 (stderr/server 등 오탐 방지).

## Quick Start

```bash
cp .env.example .env
# Fill in SLACK_WEBHOOK_URL, GRAFANA_PASSWORD
docker compose up -d
```

Grafana: http://localhost:3000
