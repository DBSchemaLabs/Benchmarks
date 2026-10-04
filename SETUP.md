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

## Set Pre-reqs on your Mac

Install [Homebrew](https://brew.sh) if needed, then install PostgreSQL:

```bash
brew install postgresql@16
export PATH="$(brew --prefix postgresql@16)/bin:$PATH"
```
