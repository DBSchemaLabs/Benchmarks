# Reproduce Experiments

## Setup PostgreSQL

Install PostgreSQL 16 if needed and add its tools to your current shell:

```bash
brew install postgresql@16
export PATH="$(brew --prefix postgresql@16)/bin:$PATH"
```

From the `experiment-phase-1` directory, start the sandbox:

```bash
chmod +x start-postgres.sh
./start-postgres.sh
```

Run as your normal Mac user, without `sudo`. The script creates the sandbox on the first run and reuses it afterward.

This sandbox uses passwordless authentication. Its data lives in `/tmp/schema-labs-pgdata`, which macOS may clear.

## Experiment #1: TEXT to ENUM

Create the experiment database:

```bash
createdb -h /tmp -p 5499 -U pg schema_labs_e1
```

Run the experiment and save the output:

```bash
psql -h /tmp -p 5499 -U pg -d schema_labs_e1 \
    -X -q -f e1-enum-alter.sql 2>&1 | tee e1-enum-alter.log
```

This converts 2 million rows from TEXT to ENUM, measures the rewrite, and checks basic SQL compatibility. The final `refunded` insert is expected to fail because the value is not in the enum.

## Experiment #2: Concurrent Read During ALTER

Run Experiment #1 first. This experiment reuses its database and resets the column to TEXT before converting it again.

```bash
chmod +x e2-lock-read.sh
./e2-lock-read.sh 2>&1 | tee e2-lock-read.log
```

It checks the lock held by ALTER and compares a small indexed read during the rewrite with the same read afterward.

## Experiment #3: Expand/Contract Inside the Database

This script creates its own database, `schema_labs_e3`, so it doesn't depend on Experiments #1 or #2. It needs `python3` for timing.

From `e3-traditional-expand-contract/`:

```bash
chmod +x e3-online-expand-contract.sh
./e3-online-expand-contract.sh 2>&1 | tee e3-run-2.log
```

It loads 2 million TEXT orders, adds a SMALLINT `status_id` that a trigger keeps in sync, and backfills it in batches of 100,000 while a second client keeps inserting and updating. Then it validates the constraints and swaps in an `orders` view in one short transaction. The script stops if any row maps to the wrong status.


## Experiment #4: Is the ENUM Really Transparent?

From `e4-enum-semantics/`:

```bash
createdb -h /tmp -p 5499 -U pg schema_labs_e4
psql -h /tmp -p 5499 -U pg -d schema_labs_e4 \
    -X -q -f e4-enum-semantics.sql 2>&1 | tee e4-enum-semantics.log
```

This runs the same queries against a TEXT column and an ENUM column: equality with a literal, `LIKE`, a text expression, `ORDER BY`, a range comparison, and a prepared statement with a text-typed parameter and an untyped one. Errors are part of the result, so the script keeps going after them.

To run it again, drop and recreate `schema_labs_e4` first.

## Experiment #5: Does the View Still Use an Index?

Run Experiment #3 first. This reuses `schema_labs_e3`.

From `e5-view-index/`:

```bash
psql -h /tmp -p 5499 -U pg -d schema_labs_e3 \
    -X -q -f e5-view-index.sql 2>&1 | tee e5-view-index.log
```

It adds a rare `refunded` status (50 rows), indexes `orders_base(status_id)`, and compares the plan and time for finding those rows through the `orders` view and directly on `orders_base`. The rows and index are only added once, so it's safe to rerun.

## Experiment #6: What Does the Write Trigger Cost?

Run Experiment #3 first. This reuses `schema_labs_e3`.

From `e6-write-overhead/`:

```bash
psql -h /tmp -p 5499 -U pg -d schema_labs_e3 \
    -X -q -f e6-write-overhead.sql 2>&1 | tee e6-write-overhead.log
```

It times 20,000 single-row inserts three ways: into a plain TEXT table, into `orders_base` directly with a SMALLINT, and through the `orders` view. The middle case separates the trigger's cost from the cost of `orders_base`'s own constraints and indexes. Every insert is rolled back.

## Experiment #7: Prepared Statements Across Schema Changes

From `e7-prepared-statements/`:

```bash
createdb -h /tmp -p 5499 -U pg schema_labs_e7
psql -h /tmp -p 5499 -U pg -d schema_labs_e7 \
    -X -q -f e7-prepared-statements.sql 2>&1 | tee e7-prepared-statements.log
```

It prepares a query, changes the schema underneath it, and runs the query again: first a table-to-view swap like Experiment #3, then an in-place type change like Experiment #1. The view returns a different value from the table, so the output shows which one was read.

To run it again, drop and recreate `schema_labs_e7` first.

## Experiment #8: What Can't You Do Through the View?

Run Experiment #3 first. This reuses `schema_labs_e3`.

From `e8-view-limits/`:

```bash
psql -h /tmp -p 5499 -U pg -d schema_labs_e3 \
    -X -q -f e8-view-limits.sql 2>&1 | tee e8-view-limits.log
```

It tries an upsert, `SELECT ... FOR UPDATE`, `COPY`, `TRUNCATE`, and `ALTER TABLE` against the `orders` view. Each one runs in a transaction that is rolled back.

## Experiment #9: Readers Queued Behind a Waiting ALTER

This script recreates its own database, `schema_labs_e9`.

From `e9-lock-queue/`:

```bash
chmod +x e9-lock-queue.sh
./e9-lock-queue.sh 2>&1 | tee e9-lock-queue.log
```

It holds a 4-second read on `orders`, starts an `ALTER TABLE` behind it, then times a small primary-key read and prints `pg_locks` while the ALTER waits. Then it repeats the test with `lock_timeout = '200ms'` on the ALTER.

## Other Commands

### Connect Manually

```bash
psql -h /tmp -p 5499 -U pg -d schema_labs_e1
```

### Reset the Experiments

Close connections to the experiment database, then delete and recreate it:

```bash
dropdb -h /tmp -p 5499 -U pg schema_labs_e1
createdb -h /tmp -p 5499 -U pg schema_labs_e1
```

Run Experiment #1 again before Experiment #2.

### Stop PostgreSQL

```bash
pg_ctl -D /tmp/schema-labs-pgdata -m fast -w stop
```
