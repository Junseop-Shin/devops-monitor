const express = require('express');
const { Pool } = require('pg');

const app = express();
app.use(express.json({ limit: '1mb' }));

const pool = new Pool({
  host: process.env.DB_HOST || 'timescaledb',
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME || 'analytics',
  user: process.env.DB_USER || 'monitor',
  password: process.env.DB_PASSWORD,
});

// Batch queue — flush every 5 seconds or when 100 events accumulate
let queue = [];
let flushTimer = null;

function scheduleFlush() {
  if (flushTimer) return;
  flushTimer = setTimeout(flush, 5000);
}

async function flush() {
  flushTimer = null;
  if (queue.length === 0) return;

  const batch = queue.splice(0, queue.length);
  const values = batch.map((e, i) => {
    const base = i * 5;
    return `($${base + 1}, $${base + 2}, $${base + 3}, $${base + 4}, $${base + 5})`;
  });
  const params = batch.flatMap(e => [
    e.time,
    e.user_id || null,
    e.event_type,
    e.service_id,
    JSON.stringify(e.metadata || {}),
  ]);

  try {
    await pool.query(
      `INSERT INTO user_events (time, user_id, event_type, service_id, metadata)
       VALUES ${values.join(', ')}`,
      params
    );
    console.log(`Flushed ${batch.length} events`);
  } catch (err) {
    console.error('Flush error:', err.message);
    // Re-queue on failure
    queue.unshift(...batch);
  }
}

// POST /v1/events  — single event
// POST /v1/events/batch  — array of events
app.post('/v1/events', (req, res) => {
  const body = req.body;
  const events = Array.isArray(body) ? body : [body];

  for (const e of events) {
    if (!e.event_type || !e.service_id) {
      return res.status(400).json({ error: 'event_type and service_id are required' });
    }
    queue.push({ ...e, time: e.time || new Date().toISOString() });
  }

  if (queue.length >= 100) flush();
  else scheduleFlush();

  res.status(202).json({ queued: events.length });
});

app.get('/health', (req, res) => res.json({ status: 'ok', queued: queue.length }));

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => console.log(`Event ingestor listening on :${PORT}`));

process.on('SIGTERM', async () => {
  await flush();
  process.exit(0);
});
