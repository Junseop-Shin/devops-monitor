# devops-monitor

Self-hosted observability platform for monitoring deployed services across multiple hosts.

## Stack

| 컴포넌트 | 역할 |
|---------|------|
| **Prometheus** | 메트릭 수집 및 저장 (15일 보존) |
| **Grafana** | 시각화 대시보드 |
| **Loki + Promtail** | 로그 집계 — glog 레벨 파싱 포함 |
| **AlertManager** | 알림 라우팅 → Slack |
| **TimescaleDB** | 유저 이벤트 시계열 DB |
| **Ingestor** | 유저 이벤트 수집 REST API (port 4000) |
| **Blackbox Exporter** | 외부 URL HTTP 프로브 (Vercel 등) |
| **cAdvisor** | Docker 컨테이너 메트릭 |
| **Node Exporter** | OS 메트릭 |
| **Nginx** | 리버스 프록시 + basic auth |
| **Cloudflare Tunnel** | 다중 호스트 보안 연결 |

## Structure

```
devops-monitor/
├── docker-compose.yml
├── prometheus/
│   ├── prometheus.yml          # scrape config (blackbox-external 포함)
│   └── rules/                  # alert rules
├── loki/loki-config.yml
├── promtail/promtail-config.yml  # glog 레벨 파싱 pipeline 포함
├── alertmanager/alertmanager.yml
├── blackbox/blackbox-config.yml  # http_2xx 모듈
├── grafana/provisioning/
│   ├── datasources/
│   └── dashboards/
│       ├── logs.json           # 에러 로그 대시보드
│       ├── service-detail.json # 서비스 상태 + 리소스
│       └── user-analytics.json # 6개 서비스 사용자 통계
├── nginx/nginx.conf
├── ingestor/                   # 유저 이벤트 수집 API
└── agents/                     # Windows 에이전트 설정
    ├── docker-compose.agent.yml
    └── promtail-remote.yml
```

## Dashboards

### 로그 (`uid: logs`)

| 패널 | 설명 |
|------|------|
| 24시간 에러 수 | glog Info/Warning 제외 — `!~ "^[IW]\\d{4}"` 패턴 적용 |
| 에러 로그 | 레벨 경계 패턴 필터 (`error\|fatal\|critical`) — 오탐 방지 |
| 전체 로그 | 24시간 전체 컨테이너 로그 스트림 |

> glog 형식(`I0325 ...`)은 Promtail pipeline에서 `glog_level` 레이블로 파싱됨.
> `I`/`W` prefix 로그는 에러 쿼리에서 제외.

### 서비스 상태 (`uid: service-detail`)

| 패널 | 설명 |
|------|------|
| 서비스 상태 | PM2(profile, seobi-chat, storybook) + Docker(lotto-oracle, techfeed-api) + Blackbox probe(studiobold) |
| CPU 사용률 | PM2 + Docker cAdvisor 통합 |
| 메모리 사용량 | PM2 + Docker cAdvisor 통합 |
| 재시작 횟수 | PM2 restarts + Docker `changes(container_start_time_seconds[24h])` |

> studiobold(boldgobynd)는 Vercel 배포라 리소스 메트릭 없음 — Blackbox HTTP probe로 UP/DOWN만 확인.

### 사용자 통계 (`uid: user-analytics`)

6개 서비스 전체 표시: `profile` / `seobi-chat` / `boldgobynd` / `lotto-oracle` / `techfeed` / `my-ui-lib`

| 패널 | 설명 |
|------|------|
| 전체 이벤트 수 | 서비스별 이벤트 합계 |
| 페이지뷰 | `page_view` 이벤트 카운트 |
| 순 방문자 | `COUNT DISTINCT user_id` |
| 시간대별 트래픽 | 24시간 이벤트 분포 |

## Analytics 연동 현황

| 서비스 | 트래킹 | 인제스터 |
|--------|--------|---------|
| profile | localStorage UUID (`_aid`) | `NEXT_PUBLIC_INGESTOR_URL` env |
| seobi-chat | localStorage UUID + server-side IP | `NEXT_PUBLIC_INGESTOR_URL` env |
| boldgobynd (studiobold) | localStorage UUID | `NEXT_PUBLIC_INGESTOR_URL` Vercel env |
| lotto-oracle | `/config.js` 엔드포인트로 주입 | `INGESTOR_URL` GitHub Secret → `.env` |
| techfeed | NestJS API → `forwardToMonitor()` | `MONITOR_INGESTOR_URL` GitHub Secret |
| my-ui-lib (storybook) | 없음 | — |

> 인제스터 외부 URL: `https://ingestor.nuclearbomb6518.com` (Mac Cloudflare Tunnel → localhost:4000)

## Cloudflare Tunnel (Mac)

```yaml
tunnel: 9ff7dc81-e003-4872-9622-21b59522ec5d
ingress:
  - monitoring.nuclearbomb6518.com  → http://localhost:3000  # Grafana
  - ingestor.nuclearbomb6518.com    → http://localhost:4000  # 이벤트 수집 API
  - mac.nuclearbomb6518.com         → ssh://localhost:22
```

## Quick Start

```bash
cp .env.example .env
# SLACK_WEBHOOK_URL, GRAFANA_PASSWORD 설정
docker compose up -d
```

Grafana: `https://monitoring.nuclearbomb6518.com`
