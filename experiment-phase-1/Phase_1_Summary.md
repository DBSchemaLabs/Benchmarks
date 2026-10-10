# Phase 1 Summary: Experiments on PostgreSQL alone

Goal: store `orders.status` (`pending`, `paid`, `shipped`, `cancelled`) as integers instead of text, keeping the database live and the application's SQL unchanged, using only what PostgreSQL 16 provides.

All runs: PostgreSQL 16 on macOS (Apple M5 Pro, 24 GB), the sandbox from `start-postgres.sh`. Most use 2 million rows; E4 and E7 use small tables, E9 uses 100,000 rows. Each folder has the script, the log from the run, and `Notes.md`.

## Results

| # | Experiment | Headline result |
|---|---|---|
| E1 | [In-place TEXT → ENUM](e1-enum-alter/) | Full table rewrite in 2.214 s (filenode changed). 88 MB → 85 MB. String-literal queries still worked |
| E2 | [Read during the ALTER](e2-lock-read/) | ALTER held AccessExclusiveLock for 3.040 s. A 9-row primary-key read waited 2.712 s (0.525 ms afterward) |
| E3 | [Expand/contract inside the DB](e3-traditional-expand-contract/) | Backfill 5.136 s under live writes, 0 mapping inconsistencies, 36 ms cutover to an `orders` view. Table grew 88 MB → 184 MB |
| E4 | [ENUM semantics](e4-enum-semantics/) | Only string literals behave like TEXT. `LIKE` and `lower()` error. `ORDER BY` and `>` silently change results. A `text`-typed parameter fails at PREPARE |
| E5 | [View vs index](e5-view-index/) | 50 rare rows: 70.423 ms through the view (parallel seq scan) vs 0.015 ms directly on `orders_base` (index scan) |
| E6 | [Write trigger cost](e6-write-overhead/) | 20k inserts: plain table 34.892 ms, `orders_base` 134.606 ms, view 176.268 ms. The trigger is ~30% of the gap |
| E7 | [Prepared statements](e7-prepared-statements/) | Followed the table-to-view swap silently. Failed after the in-place type change (`cached plan must not change result type`) until re-prepared |
| E8 | [View limits](e8-view-limits/) | Through the view, `ON CONFLICT`, `TRUNCATE` and `ALTER TABLE` fail. `FOR UPDATE` and `COPY` work |
| E9 | [Lock queue](e9-lock-queue/) | A metadata-only ALTER waiting behind a 4 s read made a 1-row read wait 2,979 ms. With `lock_timeout = '200ms'`: 0.740 ms, but the ALTER failed |

## Two approaches, side by side

| | In-place ENUM (E1, E2, E4, E7) | View over new storage (E3, E5–E8) |
|---|---|---|
| Online? | No, blocks reads for the whole rewrite | Yes, except a brief cutover lock |
| Old SQL keeps working | Literals only | Insert, update, select, COPY, FOR UPDATE |
| Breaks loudly | LIKE, `lower()`, text-typed params, cached plans | ON CONFLICT, TRUNCATE, ALTER |
| Breaks silently | ORDER BY, range comparisons | Selective reads lose the index |
| Extra cost | — | ~2.1× table size after backfill; slower writes |
| Shared risk | Any DDL waiting for its lock stalls every reader behind it (E9) | |

## Reproducing

See [README.md](README.md). E5, E6 and E8 reuse the E3 database, so run E3 first.
