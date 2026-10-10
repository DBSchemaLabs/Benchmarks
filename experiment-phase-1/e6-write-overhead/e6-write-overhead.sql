-- What does the E3 write trigger cost per insert?
-- Run Experiment #3 first. Every insert below is rolled back, so the E3 tables are left unchanged.
\timing on

DROP TABLE IF EXISTS plain_orders;
CREATE TABLE plain_orders (
    id bigserial PRIMARY KEY,
    status text NOT NULL
);

\echo '--- 20,000 inserts into a plain TEXT table'
BEGIN;
DO $$ BEGIN
    FOR i IN 1..20000 LOOP
        INSERT INTO plain_orders(status) VALUES ('paid');
    END LOOP;
END $$;
ROLLBACK;

\echo '--- 20,000 inserts into orders_base directly (SMALLINT, no translation)'
BEGIN;
DO $$ BEGIN
    FOR i IN 1..20000 LOOP
        INSERT INTO orders_base(status_id) VALUES (2);
    END LOOP;
END $$;
ROLLBACK;

\echo '--- 20,000 inserts through the orders view (lookup + INSTEAD OF trigger)'
BEGIN;
DO $$ BEGIN
    FOR i IN 1..20000 LOOP
        INSERT INTO orders(status) VALUES ('paid');
    END LOOP;
END $$;
ROLLBACK;

DROP TABLE plain_orders;
