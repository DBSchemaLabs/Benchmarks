-- Can a selective read through the E3 compatibility view still use an index?
-- Run Experiment #3 first. This adds a rare 'refunded' status and an index on orders_base(status_id).
\timing on

INSERT INTO order_status(id, name) VALUES (5, 'refunded')
ON CONFLICT (id) DO NOTHING;

-- Add 50 refunded orders through the view, only on the first run.
INSERT INTO orders(status)
SELECT 'refunded' FROM generate_series(1, 50)
WHERE NOT EXISTS (SELECT 1 FROM orders_base WHERE status_id = 5);

CREATE INDEX IF NOT EXISTS orders_base_status_id_idx ON orders_base(status_id);
ANALYZE orders_base;

SELECT count(*) AS refunded_rows FROM orders_base WHERE status_id = 5;

\echo '--- Through the orders view'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE status = 'refunded';

\echo '--- Directly on orders_base'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders_base WHERE status_id = 5;
