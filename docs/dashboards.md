# Grafana 대시보드 상세 문서

Grafana URL: `https://monitoring.nuclearbomb6518.com`

---

## 1. 전체 현황 (`uid: overview`)

**목적:** Mac + Windows 양쪽 서버의 상태를 한 화면에 요약.

| 패널명 | 타입 | 쿼리 / 설명 |
|--------|------|------------|
| Mac UP/DOWN | stat | `up{job="mac-node"}` |
| Windows UP/DOWN | stat | `up{job="windows-node"}` |
| 컨테이너 수 | stat | `count(container_last_seen{...})` |
| Mac CPU % | stat | `100 - avg(rate(node_cpu_seconds_total{job="mac-node",mode="idle"}...))` |
| Win CPU % | stat | 동일, job="windows-node" |
| Mac 메모리 % | gauge | `(1 - node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes) * 100` |
| Win 메모리 % | gauge | 동일 |
| Mac Load Average | gauge | `node_load1{job="mac-node"}` |
| Win Load Average | gauge | `node_load1{job="windows-node"}` |
| CPU 사용률 추이 | timeseries | Mac vs Windows 시계열 |
| 메모리 사용률 추이 | timeseries | Mac vs Windows 시계열 |
| 컨테이너 메모리 Top 10 | bargauge | `topk(10, container_memory_usage_bytes)` |

**갱신:** 30초

---

## 2. OS 상세 (`uid: os-detail`)

**목적:** 호스트별 OS 레벨 상세 메트릭. `$job` 변수로 호스트 선택.

**변수:** `$job` — `node_uname_info`의 `job` 레이블 (mac-node / windows-node)

| 패널명 | 타입 | 설명 |
|--------|------|------|
| OS 정보 | stat | hostname, sysname, kernel release |
| Load Average 1min | stat | `node_load1` |
| 실행 중 프로세스 | stat | `node_procs_running` |
| Load 1/5/15min | timeseries | 부하 추이 |
| CPU 사용률 | stat | 전체 idle 제외 % |
| 메모리 사용률 | stat | used/total % |
| 총 메모리 | stat | `node_memory_MemTotal_bytes` |
| 업타임 | stat | `node_time_seconds - node_boot_time_seconds` |
| CPU 모드별 추이 | timeseries | idle/user/system/iowait 등 |
| 메모리 상세 추이 | timeseries | total/available/cached |
| 디스크 사용량 | table | 마운트 포인트별 % (tmpfs/fuse 제외) |
| 네트워크 트래픽 | timeseries | 수신/송신 bytes/s (lo/docker/veth 제외) |
| Disk I/O | timeseries | 읽기/쓰기 bytes/s |

**갱신:** 30초

---

## 3. 로그 (`uid: logs`)

**목적:** 에러 로그 탐지 및 전체 로그 스트리밍.

**변수:** `$host` (multi), `$container` (multi) — Loki label_values

| 패널명 | 타입 | 쿼리 / 설명 |
|--------|------|------------|
| 24시간 에러 수 | stat | `count_over_time({container=~"$container"} \|~ "error\|fatal\|critical" !~ "^[IW]\\d{4}" [24h])` |
| 에러 로그 | logs | 동일 패턴 실시간 스트림 |
| 전체 로그 | logs | `{container=~"$container"}` 24시간 전체 스트림 |

> glog 형식(`I0325 ...`, `W0325 ...`)은 Promtail pipeline에서 `glog_level` 레이블로 파싱됨.
> `!~ "^[IW]\\d{4}"` 패턴으로 Info/Warning prefix 오탐 방지.

**갱신:** 30초

---

## 4. 서비스 상태 (`uid: service-detail`)

**목적:** 실행 중인 서비스의 상태 + 리소스 사용량 통합 모니터링.

### 웹/앱 서비스 row

| 패널명 | 타입 | 대상 서비스 |
|--------|------|-----------|
| 서비스 상태 | stat (UP/DOWN) | PM2: profile, seobi-chat, storybook / Docker: lotto-oracle, techfeed-api / Blackbox: studiobold / Docker: kis-trader-backend, kis-trader-frontend |
| 서비스별 CPU | bargauge | 위 서비스 전체 |
| 서비스별 메모리 | bargauge | 위 서비스 전체 |
| 재시작 횟수 | stat | PM2 `restarts` + Docker `changes(container_start_time_seconds[24h])` |
| CPU 추이 | timeseries | 시계열 비교 |
| 메모리 추이 | timeseries | 시계열 비교 |

### 서버 리소스 (컨테이너) row

| 패널명 | 타입 | 설명 |
|--------|------|------|
| 컨테이너 목록 | table | 전체 컨테이너 name/image/host |
| 컨테이너별 CPU | bargauge | cAdvisor `container_cpu_usage_seconds_total` |
| 컨테이너별 메모리 | bargauge | cAdvisor `container_memory_usage_bytes` |
| CPU 추이 | timeseries | 시계열 |
| 메모리 추이 | timeseries | 시계열 |
| 네트워크 수신/송신 | timeseries | `container_network_receive/transmit_bytes_total` |

> studiobold(boldgobynd)는 Vercel 배포 — Blackbox HTTP probe로 UP/DOWN만 확인, 리소스 메트릭 없음.

**갱신:** 30초

---

## 5. 사용자 분석 (`uid: user-analytics`)

**목적:** 8개 서비스의 TimescaleDB `user_events` 테이블 기반 사용자 행동 분석.

**변수:** `$service_id` — All / profile / my-ui-lib / seobi-chat / boldgobynd / lotto-oracle / techfeed / kis-trader

**데이터소스:** TimescaleDB (PostgreSQL)

### 전체 KPI row (y=0)

| 패널명 | 타입 | SQL 요약 |
|--------|------|---------|
| 전체 이벤트 | stat | `COUNT(*) WHERE $__timeFilter` |
| 순 방문자 | stat | `COUNT(DISTINCT user_id) WHERE user_id IS NOT NULL` |
| 페이지뷰 | stat | `COUNT(*) WHERE event_type = 'page_view'` |
| 재방문율 | stat | 2회 이상 page_view 유저 비율 (%) |

### 서비스별 현황 row (y=4)

| 패널명 | 타입 | 설명 |
|--------|------|------|
| 서비스별 이벤트 수 | bargauge | GROUP BY service_id |
| {서비스} 페이지뷰 | stat | 각 서비스별 PV (lotto-oracle, seobi-chat, profile, boldgobynd, techfeed, my-ui-lib, kis-trader) |
| {서비스} 순 방문자 | stat | 각 서비스별 UV |

### 시계열 & 분포 row (y=29)

| 패널명 | 타입 | 설명 |
|--------|------|------|
| 시간대별 이벤트 | timeseries | 1시간 버킷, service_id / event_type 조합 |
| 서비스별 이벤트 | table | service_id × event_type × count |
| 유입 경로 Top 20 | table | `metadata->>'referrer'` 기반 |
| 이벤트 타입별 분포 | piechart | event_type별 비율 |
| 서비스별 이벤트 분포 | piechart | service_id별 비율 (도넛) |

### seobi-chat 음성 분석 row (y=54)

| 패널명 | 타입 | 이벤트 |
|--------|------|--------|
| 음성 입력 횟수 | stat | `voice_input` |
| 음성 미인식 횟수 | stat | `no_speech` |
| 음성 인식 성공률 | stat | voice_input / (voice_input + no_speech) × 100 % |
| 시간대별 음성 이벤트 | timeseries | voice_input / no_speech |

### kis-trader 트레이딩 분석 row (y=67)

| 패널명 | 타입 | 이벤트 |
|--------|------|--------|
| 페이지뷰 | stat | `pageview` |
| 로그인 | stat | `login` |
| 백테스트 실행 | stat | `backtest_run` |
| 시뮬레이션 활성화 | stat | `simulation_activate` |
| 시간대별 이벤트 | timeseries | 모든 kis-trader 이벤트 |

### techfeed 앱 이벤트 분석 row (y=80)

| 패널명 | 타입 | 설명 |
|--------|------|------|
| 이벤트 타입별 (24h) | piechart | techfeed 전체 이벤트 분포 |
| 시간별 이벤트 트렌드 | timeseries | 7일간 이벤트 타입별 추이 |
| 오늘 앱 오픈 수 | stat | `app_open` (24h) |
| 오늘 리뷰 수 | stat | `review` (24h) |
| 오늘 로그인 수 | stat | `login` (24h) |
| 오늘 신규 가입 수 | stat | `signup` (24h) |
| 비로그인 vs 로그인 비율 | piechart | user_id IS NULL 여부 (7일) |
| 주요 행동 트렌드 (7일) | timeseries | click/bookmark/share/like/search |
| **이벤트 상세 (기간별)** | | |
| 콘텐츠 읽기 | stat | `read` |
| 콘텐츠 클릭 | stat | `click` |
| 북마크 | stat | `bookmark` |
| 공유 | stat | `share` |
| 좋아요 | stat | `like` |
| 검색 | stat | `search` |
| 필터 적용 | stat | `filter_apply` |
| 탭 방문 | stat | `tab_visit` |
| 알림 허용 | stat | `push_enable` |
| 알림 비허용 | stat | `push_disable` |
| 로그인 유도 노출 | stat | `login_prompt_seen` |

**갱신:** 1분 / 기본 기간: 최근 7일

---

## TimescaleDB 스키마

```sql
CREATE TABLE user_events (
  time        TIMESTAMPTZ NOT NULL,
  user_id     TEXT,
  event_type  TEXT NOT NULL,
  service_id  TEXT NOT NULL,
  metadata    JSONB
);
SELECT create_hypertable('user_events', 'time');
```

## Alert Rules

Prometheus alert rules (`prometheus/rules/`):
- 서버 다운 (Mac / Windows node_exporter)
- 컨테이너 재시작 반복 (`changes(container_start_time_seconds[1h]) > 3`)
- CPU 90% 이상 지속
- 디스크 사용률 85% 이상
- 외부 서비스 HTTP probe 실패 (studiobold)

→ AlertManager가 Slack `#새-워크스페이스-전체` 채널로 전송
