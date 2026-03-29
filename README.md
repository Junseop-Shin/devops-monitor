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
│       ├── overview.json        # 전체 서버 현황 요약
│       ├── host-detail.json     # 호스트별 OS 상세 메트릭
│       ├── service-detail.json  # 서비스 상태 + 리소스
│       ├── logs.json            # 에러 로그 대시보드
│       └── user-analytics.json  # 8개 서비스 사용자 통계
├── nginx/nginx.conf
├── ingestor/                   # 유저 이벤트 수집 API
└── agents/                     # Windows 에이전트 설정
    ├── docker-compose.agent.yml
    └── promtail-remote.yml
```

> 대시보드별 상세 패널 목록: `docs/dashboards.md`

## Dashboards

### 전체 현황 (`uid: overview`)

Mac + Windows 양쪽 서버의 상태를 한 화면에 요약.

| 패널 | 설명 |
|------|------|
| 서버 UP/DOWN | Mac/Windows 각각 상태 표시 |
| 컨테이너 수 | 전체 실행 중 컨테이너 |
| CPU / 메모리 | Mac vs Windows 비교 |
| 컨테이너 메모리 Top 10 | 메모리 사용량 상위 컨테이너 |

### OS 상세 (`uid: os-detail`)

호스트별 (Mac / Windows) OS 레벨 상세 메트릭. `$job` 변수로 호스트 선택.

| 패널 | 설명 |
|------|------|
| OS 정보 / Uptime | 호스트명, 커널, 업타임 |
| CPU / 메모리 / 디스크 | 사용률 stat + 시계열 |
| 네트워크 / Disk I/O | 수신/송신 바이트, 읽기/쓰기 |

### 로그 (`uid: logs`)

| 패널 | 설명 |
|------|------|
| 24시간 에러 수 | glog Info/Warning 제외 — `!~ "^[IW]\\d{4}"` 패턴 적용 |
| 에러 로그 | `error\|fatal\|critical` 레벨 필터 |
| 전체 로그 | 24시간 전체 컨테이너 로그 스트림 |

> glog 형식(`I0325 ...`)은 Promtail pipeline에서 `glog_level` 레이블로 파싱됨.

### 서비스 상태 (`uid: service-detail`)

| 패널 | 설명 |
|------|------|
| 서비스 상태 | PM2(profile, seobi-chat, storybook) + Docker(lotto-oracle, techfeed-api) + Blackbox probe(studiobold) + Docker(kis-trader) |
| CPU 사용률 | PM2 + Docker cAdvisor 통합 |
| 메모리 사용량 | PM2 + Docker cAdvisor 통합 |
| 재시작 횟수 | PM2 restarts + Docker `changes(container_start_time_seconds[24h])` |

> studiobold(boldgobynd)는 Vercel 배포라 리소스 메트릭 없음 — Blackbox HTTP probe로 UP/DOWN만 확인.

### 사용자 통계 (`uid: user-analytics`)

8개 서비스 사용자 이벤트 분석. `$service_id` 변수로 서비스 필터링.

서비스: `profile` / `seobi-chat` / `boldgobynd` / `lotto-oracle` / `techfeed` / `my-ui-lib` / `kis-trader`

| 섹션 | 패널 |
|------|------|
| 전체 KPI | 전체 이벤트, 순 방문자, 페이지뷰, 재방문율 |
| 서비스별 현황 | 서비스별 이벤트 수 bargauge + 서비스별 PV/UV stat |
| 시계열 & 분포 | 시간대별 이벤트, 서비스별/이벤트별 테이블, 유입 경로 Top 20, 파이차트 |
| seobi-chat 음성 분석 | 음성 입력/미인식 횟수, 인식 성공률, 시계열 |
| kis-trader 트레이딩 분석 | 페이지뷰, 로그인, 백테스트, 시뮬레이션 활성화, 시계열 |
| techfeed 앱 이벤트 분석 | 이벤트 타입 파이차트, 시간별 트렌드, 앱오픈/리뷰/로그인/가입, 비로그인 비율, 콘텐츠 이벤트 상세 (read/click/bookmark/share/like/search/filter_apply/tab_visit/push_enable/push_disable/login_prompt_seen) |

## Ingestor API

```
POST /v1/events
{
  "event_type": "string (required)",
  "service_id": "string (required)",
  "user_id": "string (optional)",
  "time": "ISO timestamp (optional)",
  "metadata": "object (optional)"
}
GET /health → { status: 'ok', queued: N }
```

배치 전송 지원 (배열). 5초 또는 100건마다 TimescaleDB flush. `review` 이벤트 발생 시 Slack 알림.

## Analytics 연동 현황

| 서비스 | 트래킹 방식 | 인제스터 설정 |
|--------|-----------|-------------|
| profile | localStorage UUID (`_aid`) | `NEXT_PUBLIC_INGESTOR_URL` env |
| seobi-chat | localStorage UUID + server-side IP | `NEXT_PUBLIC_INGESTOR_URL` env |
| boldgobynd | localStorage UUID | `NEXT_PUBLIC_INGESTOR_URL` Vercel env |
| lotto-oracle | `/config.js` 엔드포인트 주입 | `INGESTOR_URL` GitHub Secret |
| techfeed | NestJS API `forwardToMonitor()` — 서버사이드 전송 | `MONITOR_INGESTOR_URL` GitHub Secret |
| kis-trader | 클라이언트 직접 전송 | `NEXT_PUBLIC_INGESTOR_URL` env |
| my-ui-lib (storybook) | 없음 | — |

> 인제스터 외부 URL: `https://ingestor.nuclearbomb6518.com` (Mac Cloudflare Tunnel → localhost:4000)

### techfeed 이벤트 타입

| 이벤트 | 설명 |
|--------|------|
| `app_open` | 앱 실행 |
| `login` / `signup` | 로그인 / 신규 가입 |
| `login_prompt_seen` | 비로그인 유저 로그인 유도 화면 노출 |
| `read` | 콘텐츠 읽기 (스크롤) |
| `click` | 콘텐츠 클릭 |
| `bookmark` | 북마크 추가 |
| `share` | 공유 |
| `like` | 좋아요 |
| `search` | 검색 |
| `filter_apply` | 태그/소스 필터 적용 |
| `tab_visit` | 탭(피드/검색/마이페이지) 이동 |
| `push_enable` / `push_disable` | FCM 알림 허용 / 비허용 |
| `review` | 앱 리뷰 제출 |

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
