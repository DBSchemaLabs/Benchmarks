#!/usr/bin/env bash
# Watch a primary-key read wait while ALTER rewrites the table.
set -euo pipefail

export PATH="$(brew --prefix postgresql@16)/bin:$PATH"

P=(psql -h /tmp -p 5499 -U pg -d schema_labs_e1
   -X -q -v ON_ERROR_STOP=1)

# Restore TEXT before testing the conversion again.
"${P[@]}" -c \
    "ALTER TABLE orders ALTER COLUMN status TYPE text;"

# Start the conversion in the background.
"${P[@]}" \
    -c '\timing on' \
    -c "ALTER TABLE orders ALTER COLUMN status TYPE order_status
        USING status::order_status;" \
    > /tmp/alter.out 2>&1 &

ALTER_PID=$!
sleep 0.3

# Check whether ALTER holds its exclusive lock.
"${P[@]}" -c "
    SELECT pid, mode, granted
    FROM pg_locks
    WHERE relation = 'orders'::regclass;
"

# Time a small read while the conversion is running.
"${P[@]}" \
    -c '\timing on' \
    -c "SELECT count(*) FROM orders WHERE id < 10;"

wait "$ALTER_PID"

echo "ALTER output:"
cat /tmp/alter.out

# Compare the same read after the conversion.
echo "Read after ALTER:"
"${P[@]}" \
    -c '\timing on' \
    -c "SELECT count(*) FROM orders WHERE id < 10;"