-- Convert a TEXT column to ENUM on 2 million rows.
\timing on

CREATE TABLE orders (
    id bigserial PRIMARY KEY,
    status text NOT NULL
);

INSERT INTO orders(status)
SELECT (ARRAY['pending', 'paid', 'shipped', 'cancelled'])[1 + (g % 4)]
FROM generate_series(1, 2000000) AS g;

SELECT
    pg_size_pretty(pg_relation_size('orders')) AS size_text,
    pg_relation_filenode('orders') AS filenode_before;

CREATE TYPE order_status AS ENUM (
    'pending', 'paid', 'shipped', 'cancelled'
);

ALTER TABLE orders
ALTER COLUMN status TYPE order_status
    USING status::order_status;

SELECT
    pg_size_pretty(pg_relation_size('orders')) AS size_enum,
    pg_relation_filenode('orders') AS filenode_after;

-- Check SQL using string literals.
SELECT count(*) FROM orders WHERE status = 'paid';

INSERT INTO orders(status) VALUES ('pending');

UPDATE orders SET status = 'shipped' WHERE id = 1;

SELECT status, status || '_x' AS concat_test
FROM orders WHERE id = 1;

-- Deliberate failure: this value is not in the enum.
INSERT INTO orders(status) VALUES ('refunded');