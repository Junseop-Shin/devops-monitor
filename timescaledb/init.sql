-- User analytics events hypertable
CREATE TABLE IF NOT EXISTS user_events (
    time        TIMESTAMPTZ NOT NULL,
    user_id     UUID,
    event_type  VARCHAR(50),
    service_id  VARCHAR(50),
    metadata    JSONB,
    ip_address  INET
);

SELECT create_hypertable('user_events', 'time', if_not_exists => TRUE);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_user_events_service ON user_events (service_id, time DESC);
CREATE INDEX IF NOT EXISTS idx_user_events_type ON user_events (event_type, time DESC);
