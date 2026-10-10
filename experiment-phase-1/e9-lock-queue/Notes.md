# Notes

A 4-second read transaction holds a lock on `orders` (100,000 rows). Half a second later an `ALTER TABLE orders ADD COLUMN` starts, and half a second after that a small primary-key read.

### T1: ALTER without `lock_timeout`

Lock snapshot while the ALTER waits:

| Session | Lock mode | Granted |
|---|---|---|
| Long read (`count(*)` + `pg_sleep(4)`) | AccessShareLock | **yes** |
| `ALTER TABLE orders ADD COLUMN note text` | AccessExclusiveLock | **no**, waiting for the long read |
| `SELECT status FROM orders WHERE id = 5` | AccessShareLock | **no**, waiting behind the ALTER |

The small read took **2,978.875 ms**.

### T2: ALTER with `lock_timeout = '200ms'`

- The ALTER gave up: `ERROR: canceling statement due to lock timeout`.
- The same small read took **0.740 ms**.

### Observations

- The small read's lock doesn't conflict with the long read's: both are AccessShareLock. It waited anyway, because it queued behind the ALTER, which was itself waiting.
- The ALTER here only adds a nullable column, which is metadata-only. Even an instant change blocks readers if it has to wait for its lock.
- The read waited out the rest of the long transaction, about 3 of its 4 seconds. A longer report or an idle-in-transaction session would make that wait longer.
- With `lock_timeout`, readers weren't blocked, but the ALTER failed and has to be retried.
- E3's cutover used `lock_timeout = '2s'`, so readers could wait up to 2 seconds per attempt.

Any DDL that has to wait for its lock makes every new query on that table wait behind it. `lock_timeout` turns that into a failed ALTER instead of stalled readers.
