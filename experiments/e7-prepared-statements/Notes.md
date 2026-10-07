# Notes

Each test prepares `SELECT status ... WHERE id = 1`, runs it, changes the schema underneath, and runs the same prepared statement again.

| Test | Schema change | Before | After the change | After re-preparing |
|---|---|---|---|---|
| T1 | Rename `orders`, create a view named `orders` (E3) | `from-old-table` | **`from-new-view`** | — |
| T2 | `ALTER COLUMN status TYPE order_status` (E1) | `paid` | **Error:** `cached plan must not change result type` | `paid` |

- T1: the prepared statement followed the name. After the swap it read the new view, not the renamed table, with no error. Postgres re-planned it and looked `orders` up again.
- T2: the same kind of statement broke after the in-place type change. The result column went from TEXT to the enum, and Postgres refuses to run a cached plan whose result type changed.
- Re-preparing fixed T2. So the failure is one error per session that had already prepared the statement, not a permanent break.
- With a connection pool, every connection holding that prepared statement would hit the error once after the ALTER.

E3's view swap is invisible to prepared statements, as long as the view keeps the same column types. E1's type change is not.
