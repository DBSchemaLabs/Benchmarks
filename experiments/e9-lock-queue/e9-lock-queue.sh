#!/usr/bin/env bash
# A waiting ALTER makes new readers wait behind it. Does lock_timeout prevent that?
# macOS + PostgreSQL 16. WARNING: recreates the dedicated schema_labs_e9 database.
set -euo pipefail

export PATH="$(brew --prefix postgresql@16)/bin:$PATH"
export PGHOST=/tmp PGPORT=5499 PGUSER=pg

DB=schema_labs_e9
P=(psql -d "$DB" -X -q -v ON_ERROR_STOP=1)

echo "Recreating dedicated experiment database: $DB"
dropdb --if-exists "$DB"
createdb "$DB"

"${P[@]}" -c "
    CREATE TABLE orders (id bigint PRIMARY KEY, status text NOT NULL);
    INSERT INTO orders
    SELECT g, (ARRAY['pending', 'paid', 'shipped', 'cancelled'])[1 + (g % 4)]
    FROM generate_series(1, 100000) AS g;
    ANALYZE orders;
"

# A reader that keeps its lock on orders for 4 seconds, like a slow report.
long_reader() {
    "${P[@]}" -c "BEGIN; SELECT count(*) FROM orders; SELECT pg_sleep(4); COMMIT;" >/dev/null
}

show_locks() {
    "${P[@]}" -c "
        SELECT a.pid, l.mode, l.granted, left(a.query, 45) AS query
        FROM pg_locks l JOIN pg_stat_activity a USING (pid)
        WHERE l.relation = 'orders'::regclass
        ORDER BY l.granted DESC, a.pid;
    "
}

echo "--- T1: ALTER without lock_timeout"
long_reader &
READER_PID=$!
sleep 0.5

"${P[@]}" -c "ALTER TABLE orders ADD COLUMN note text;" &
ALTER_PID=$!
sleep 0.5

# Start a small read once the ALTER is waiting.
"${P[@]}" -c '\timing on' -c "SELECT status FROM orders WHERE id = 5;" &
SMALL_READ_PID=$!
sleep 0.5

echo "Locks while the ALTER waits:"
show_locks

wait "$SMALL_READ_PID" "$ALTER_PID" "$READER_PID"

echo "--- T2: ALTER with lock_timeout = 200ms"
long_reader &
READER_PID=$!
sleep 0.5

"${P[@]}" -v ON_ERROR_STOP=0 \
    -c "SET lock_timeout = '200ms';" \
    -c "ALTER TABLE orders ADD COLUMN note2 text;" 2>&1 || true

"${P[@]}" -c '\timing on' -c "SELECT status FROM orders WHERE id = 5;"

wait "$READER_PID"
