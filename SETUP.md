# Setup

Here’s how to set things up to run the Schema Labs experiments on your Mac.

## My setup

I’m using a MacBook Pro with PostgreSQL 16.
```
      Chip: Apple M5 Pro
      Total Number of Cores: 15 (5 Super and 10 Performance)
      Memory: 24 GB
```

The local database uses port `5499`, socket `/tmp`, user `pg`, and database `postgres`.

## Set up on your Mac

Install [Homebrew](https://brew.sh) if needed, then install PostgreSQL:

```bash
brew install postgresql@16
export PATH="$(brew --prefix postgresql@16)/bin:$PATH"
```

From the `experiments` directory, run the macOS version of `start-postgres.sh`:

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
