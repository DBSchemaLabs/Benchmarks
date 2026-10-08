-- Which common table operations stop working once orders is a view?
-- Run Experiment #3 first. Each test runs in a transaction that is rolled back.

\echo '--- T1: upsert'
BEGIN;
INSERT INTO orders(id, status) VALUES (1, 'paid')
ON CONFLICT (id) DO NOTHING;
ROLLBACK;

\echo '--- T2: row lock'
BEGIN;
SELECT id, status FROM orders WHERE id = 1 FOR UPDATE;
ROLLBACK;

\echo '--- T3: COPY into the view'
BEGIN;
COPY orders(status) FROM STDIN;
paid
shipped
\.
SELECT count(*) AS copied_rows FROM orders WHERE id > (SELECT max(id) - 2 FROM orders_base);
ROLLBACK;

\echo '--- T4: TRUNCATE'
BEGIN;
TRUNCATE orders;
ROLLBACK;

\echo '--- T5: ALTER TABLE, as a later migration or ORM would'
BEGIN;
ALTER TABLE orders ADD COLUMN note text;
ROLLBACK;
