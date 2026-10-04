# Reproduce Experiments

#### Setup Postgres

Run `start-postgres.sh`:

```bash
chmod +x start-postgres.sh
./start-postgres.sh
```

Run it as your normal Mac user, without `sudo`. It creates the sandbox on the first run and reuses it afterward.

To connect:

```bash
psql -h /tmp -p 5499 -U pg -d postgres
```

To stop:

```bash
pg_ctl -D /tmp/schema-labs-pgdata -m fast -w stop
```

This is a local sandbox with passwordless authentication. Its data lives in `/tmp/schema-labs-pgdata`, which macOS may clear.

### Experiment #1

Step 1: Run and setup pgsql (Steps above)

Step 2: Create separate database for the experiment
```
createdb -h /tmp -p 5499 -U pg schema_labs_e1
```

Step 3: Run the file
```
psql -h /tmp -p 5499 -U pg -d schema_labs_e1 \
    -X -q -f e1-enum-alter.sql
```

To clear
```
dropdb -h /tmp -p 5499 -U pg schema_labs_e1
```