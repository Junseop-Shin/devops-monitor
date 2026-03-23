# Service Integration Guide

기존 서비스에 Prometheus 메트릭과 유저 이벤트 수집을 연동하는 방법.

---

## 1. Node.js / Express — /metrics 엔드포인트

```bash
npm install prom-client
```

```js
// metrics.js
const promClient = require('prom-client');

// 기본 메트릭 (CPU, 메모리, GC 등) 자동 수집
promClient.collectDefaultMetrics({ prefix: 'myapp_' });

// 커스텀 HTTP 메트릭
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.1, 0.3, 0.5, 1, 2, 5],
});

const httpRequestTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
});

module.exports = { promClient, httpRequestDuration, httpRequestTotal };
```

```js
// app.js
const { promClient, httpRequestDuration, httpRequestTotal } = require('./metrics');

// 미들웨어 — 모든 요청 측정
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    const labels = { method: req.method, route: req.route?.path || req.path, status: res.statusCode };
    end(labels);
    httpRequestTotal.inc(labels);
  });
  next();
});

// 메트릭 엔드포인트
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', promClient.register.contentType);
  res.end(await promClient.register.metrics());
});
```

---

## 2. NestJS — /metrics 엔드포인트

```bash
npm install @willsoto/nestjs-prometheus prom-client
```

```ts
// app.module.ts
import { PrometheusModule } from '@willsoto/nestjs-prometheus';

@Module({
  imports: [
    PrometheusModule.register({ defaultMetrics: { enabled: true } }),
  ],
})
export class AppModule {}
```

---

## 3. PM2 서비스 — 메트릭 노출

PM2로 돌리는 서비스는 위의 Express 방법과 동일. `/metrics` 라우트만 추가하면 됨.

PM2 프로세스 자체 메트릭이 필요하다면:
```bash
# PM2 내장 메트릭 (pm2 monit 데이터)
pm2 install pm2-metrics
```

---

## 4. prometheus.yml에 서비스 추가

```yaml
# prometheus/prometheus.yml에 추가
scrape_configs:
  - job_name: 'my-service'
    static_configs:
      - targets: ['host.docker.internal:3001']  # 로컬 서비스
        labels:
          host: 'mac-mini'
          service: 'my-service'
```

> 맥OS Docker에서 호스트 서비스 접근 시 `host.docker.internal` 사용.

설정 변경 후 reload:
```bash
make reload-prometheus
```

---

## 5. 유저 이벤트 수집 — Event Ingestor API

서비스 프론트/백엔드에서 이벤트 발생 시 Ingestor API 호출.

### 백엔드 (Node.js)

```js
const INGESTOR_URL = process.env.INGESTOR_URL || 'http://localhost:4000';

async function trackEvent(eventType, serviceId, metadata = {}, userId = null) {
  try {
    await fetch(`${INGESTOR_URL}/v1/events`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ event_type: eventType, service_id: serviceId, metadata, user_id: userId }),
    });
  } catch (err) {
    // 이벤트 수집 실패는 서비스에 영향 없도록 무시
    console.error('Event tracking failed:', err.message);
  }
}

// 사용 예
app.get('/about', async (req, res) => {
  await trackEvent('page_view', 'profile', {
    referrer: req.headers.referer,
    utm_source: req.query.utm_source,
    page: '/about',
  });
  res.render('about');
});
```

### 프론트엔드 (React/Next.js)

```js
// lib/analytics.js
export function trackEvent(eventType, metadata = {}) {
  fetch('/api/track', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ event_type: eventType, metadata }),
  }).catch(() => {}); // fire and forget
}

// 사용 예
trackEvent('page_view', { page: '/about', referrer: document.referrer });
trackEvent('button_click', { button: 'cta-contact' });
```

### 배치 전송 (트래픽 많을 때)

```js
// POST /v1/events — 배열도 허용
await fetch(`${INGESTOR_URL}/v1/events`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify([
    { event_type: 'page_view', service_id: 'profile', metadata: { page: '/' } },
    { event_type: 'scroll', service_id: 'profile', metadata: { depth: 80 } },
  ]),
});
```

---

## 6. Cloudflare Tunnel — 배포 PC 에이전트 연결

배포 PC에서 실행:

```bash
# cloudflared 설치 (Linux)
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared

# 터널 생성 (최초 1회)
./cloudflared tunnel login
./cloudflared tunnel create remote-pc

# node_exporter 포트를 터널로 노출
./cloudflared tunnel route dns remote-pc node-exporter.your-domain.com
```

`prometheus.yml`의 `REMOTE_PC_HOST`를 `node-exporter.your-domain.com`으로 설정.
