# Reproduce Experiments

## Setup PostgreSQL

Install PostgreSQL 16 if needed and add its tools to your current shell:

```bash
brew install postgresql@16
export PATH="$(brew --prefix postgresql@16)/bin:$PATH"
```

From the `experiments` directory, start the sandbox:

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