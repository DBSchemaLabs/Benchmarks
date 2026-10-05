-- Is the TEXT-to-ENUM change from E1 really invisible to application SQL?
-- Runs the same queries against a TEXT column and an ENUM column.

CREATE TYPE order_status AS ENUM (
    'pending', 'paid', 'shipped', 'cancelled'
);

CREATE TABLE orders_text (status text NOT NULL);
CREATE TABLE orders_enum (status order_status NOT NULL);

INSERT INTO orders_text VALUES ('pending'), ('paid'), ('shipped'), ('cancelled');
INSERT INTO orders_enum VALUES ('pending'), ('paid'), ('shipped'), ('cancelled');

\echo '--- T1: equality with a string literal'
SELECT count(*) AS text_rows FROM orders_text WHERE status = 'paid';
SELECT count(*) AS enum_rows FROM orders_enum WHERE status = 'paid';

\echo '--- T2: LIKE'
SELECT count(*) AS text_rows FROM orders_text WHERE status LIKE 'p%';
SELECT count(*) AS enum_rows FROM orders_enum WHERE status LIKE 'p%';

\echo '--- T3: comparing with a text expression'
SELECT count(*) AS text_rows FROM orders_text WHERE status = lower('PAID');
SELECT count(*) AS enum_rows FROM orders_enum WHERE status = lower('PAID');

\echo '--- T4: ORDER BY'
SELECT string_agg(status::text, ', ' ORDER BY status) AS text_order FROM orders_text;
SELECT string_agg(status::text, ', ' ORDER BY status) AS enum_order FROM orders_enum;

\echo '--- T5: range comparison'
SELECT string_agg(status::text, ', ' ORDER BY status::text) AS text_after_paid
FROM orders_text WHERE status > 'paid';
SELECT string_agg(status::text, ', ' ORDER BY status::text) AS enum_after_paid
FROM orders_enum WHERE status > 'paid';

\echo '--- T6: a parameter bound as text, the way many drivers send strings'
PREPARE text_count(text) AS SELECT count(*) FROM orders_text WHERE status = $1;
EXECUTE text_count('paid');
PREPARE enum_count(text) AS SELECT count(*) FROM orders_enum WHERE status = $1;

\echo '--- T7: the same parameter left untyped, so Postgres infers it'
PREPARE enum_count_untyped AS SELECT count(*) FROM orders_enum WHERE status = $1;
EXECUTE enum_count_untyped('paid');
