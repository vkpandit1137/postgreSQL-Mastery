-- ============================================================================
-- 90_bigdata.sql  —  Large synthetic tables for Phase 9 (Days 73–81)
--
-- DO NOT RUN THIS BEFORE DAY 73.
--
-- The 60-row `orders` table is perfect for learning what a query *means*.
-- It is useless for learning what a query *costs*: PostgreSQL will sequential-
-- scan 60 rows faster than it can look anything up in an index, so every
-- performance lesson would be a lie.
--
-- This script builds tables big enough for the planner to have real choices.
--
--     \c shopdb
--     \i 90_bigdata.sql
--
-- Disk: ~1.5 GB.   Time: 3–10 minutes depending on your machine.
-- Reduce the row counts below if you are tight on space; 2 million rows is
-- still enough to feel every lesson in Phase 9.
-- ============================================================================

\timing on

DROP TABLE IF EXISTS big_events   CASCADE;
DROP TABLE IF EXISTS big_orders   CASCADE;
DROP TABLE IF EXISTS big_users    CASCADE;

-- ----------------------------------------------------------------------------
-- big_users : 1,000,000 rows
-- ----------------------------------------------------------------------------
CREATE TABLE big_users (
    user_id     bigint PRIMARY KEY,
    email       text   NOT NULL,
    country     text   NOT NULL,
    signup_at   timestamptz NOT NULL,
    is_active   boolean NOT NULL,
    plan        text   NOT NULL,
    lifetime_value numeric(12,2) NOT NULL
);

INSERT INTO big_users (user_id, email, country, signup_at, is_active, plan, lifetime_value)
SELECT
    g,
    'user' || g || '@example.com',
    (ARRAY['US','DE','IN','BR','GB','JP','FR','CA','AU','NG','ES','IT',
           'MX','KR','SE','PL','NL','ZA','AR','EG'])[1 + (g % 20)],
    timestamptz '2020-01-01 00:00:00+00' + (g % 2100) * interval '1 day'
                                          + (g % 86400) * interval '1 second',
    (g % 17) <> 0,                       -- ~94% active
    (ARRAY['free','free','free','free','pro','pro','enterprise'])[1 + (g % 7)],
    round((random() * 4000)::numeric, 2)
FROM generate_series(1, 1000000) AS g;

-- ----------------------------------------------------------------------------
-- big_orders : 5,000,000 rows  (skewed: a few users order a great deal)
-- ----------------------------------------------------------------------------
CREATE TABLE big_orders (
    order_id    bigint PRIMARY KEY,
    user_id     bigint NOT NULL,
    placed_at   timestamptz NOT NULL,
    status      text   NOT NULL,
    amount      numeric(10,2) NOT NULL,
    currency    char(3) NOT NULL,
    note        text
);

INSERT INTO big_orders (order_id, user_id, placed_at, status, amount, currency, note)
SELECT
    g,
    -- deliberate skew: 20% of orders belong to the first 1,000 users
    CASE WHEN g % 5 = 0 THEN 1 + (g % 1000)
         ELSE 1 + (g % 1000000) END,
    timestamptz '2022-01-01 00:00:00+00' + (g % 1300) * interval '1 day'
                                          + (g % 86400) * interval '1 second',
    (ARRAY['delivered','delivered','delivered','delivered','delivered',
           'delivered','delivered','shipped','pending','cancelled'])[1 + (g % 10)],
    round((random() * 990 + 10)::numeric, 2),
    (ARRAY['USD','EUR','GBP','INR'])[1 + (g % 4)],
    CASE WHEN g % 50 = 0
         THEN repeat('long note for TOAST demonstration ', 80)
         ELSE NULL END
FROM generate_series(1, 5000000) AS g;

-- ----------------------------------------------------------------------------
-- big_events : 10,000,000 rows, append-only, naturally ordered by time
-- (the ideal shape for a BRIN index — you will prove that on Day 79)
-- ----------------------------------------------------------------------------
CREATE TABLE big_events (
    event_id    bigint PRIMARY KEY,
    user_id     bigint NOT NULL,
    event_type  text   NOT NULL,
    occurred_at timestamptz NOT NULL,
    payload     jsonb
);

INSERT INTO big_events (event_id, user_id, event_type, occurred_at, payload)
SELECT
    g,
    1 + (g % 1000000),
    (ARRAY['page_view','click','add_to_cart','checkout','login','logout',
           'search','share'])[1 + (g % 8)],
    timestamptz '2024-01-01 00:00:00+00' + g * interval '3 seconds',
    jsonb_build_object(
        'session', 'S' || (g / 37),
        'device',  (ARRAY['mobile','desktop','tablet'])[1 + (g % 3)],
        'value',   g % 1000
    )
FROM generate_series(1, 10000000) AS g;

-- No indexes beyond the primary keys, on purpose.
-- You will add every index yourself, and measure what it bought you.

ANALYZE big_users;
ANALYZE big_orders;
ANALYZE big_events;

\timing off

SELECT relname AS table_name,
       to_char(reltuples, 'FM999,999,999') AS estimated_rows,
       pg_size_pretty(pg_total_relation_size(oid)) AS total_size
FROM   pg_class
WHERE  relname IN ('big_users','big_orders','big_events')
ORDER  BY relname;

\echo ''
\echo '90_bigdata.sql loaded. You are ready for Day 73.'
