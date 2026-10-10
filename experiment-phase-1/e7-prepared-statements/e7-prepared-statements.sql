-- Do prepared statements survive the two schema changes from E1 and E3?
-- Each test prepares a query, changes the schema underneath it, and runs it again.

\echo '--- T1: rename the table and put a view in its place (E3)'
CREATE TABLE orders (id int PRIMARY KEY, status text NOT NULL);
INSERT INTO orders VALUES (1, 'from-old-table');

PREPARE read_order AS SELECT status FROM orders WHERE id = 1;
EXECUTE read_order;

-- The view returns a different value, so the output shows which object was read.
BEGIN;
ALTER TABLE orders RENAME TO orders_old;
CREATE VIEW orders AS SELECT 1 AS id, 'from-new-view'::text AS status;
COMMIT;

EXECUTE read_order;

\echo '--- T2: change the column type in place (E1)'
CREATE TYPE order_status AS ENUM (
    'pending', 'paid', 'shipped', 'cancelled'
);
CREATE TABLE typed_orders (id int PRIMARY KEY, status text NOT NULL);
INSERT INTO typed_orders VALUES (1, 'paid');

PREPARE read_typed AS SELECT status FROM typed_orders WHERE id = 1;
EXECUTE read_typed;

ALTER TABLE typed_orders
ALTER COLUMN status TYPE order_status
    USING status::order_status;

-- Expected to fail: the result type changed under the prepared statement.
EXECUTE read_typed;

\echo '--- T2: prepare the same query again'
DEALLOCATE read_typed;
PREPARE read_typed AS SELECT status FROM typed_orders WHERE id = 1;
EXECUTE read_typed;
