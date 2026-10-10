#!/usr/bin/env bash
# Local PostgreSQL 16 sandbox: port 5499, socket /tmp, database user pg.
set -euo pipefail

PG_BIN="$(brew --prefix postgresql@16)/bin"
DATA_DIR="/tmp/schema-labs-pgdata"
LOG_FILE="/tmp/schema-labs-postgres.log"

# Initialize only on the first run.
if [[ ! -f "$DATA_DIR/PG_VERSION" ]]; then
    "$PG_BIN/initdb" -D "$DATA_DIR" -U pg -A trust
fi

# Start only if this cluster is not already running.
if ! "$PG_BIN/pg_ctl" -D "$DATA_DIR" status >/dev/null 2>&1; then
    "$PG_BIN/pg_ctl" \
        -D "$DATA_DIR" \
        -l "$LOG_FILE" \
        -o "-k /tmp -p 5499 -h localhost" \
        -w start
fi

"$PG_BIN/psql" -h /tmp -p 5499 -U pg -d postgres \
    -c "SELECT version();"