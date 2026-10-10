# Notes

Ran the same queries against a TEXT column and an ENUM column, each holding the four status values once.

| Test | Query | TEXT | ENUM |
|---|---|---|---|
| T1 | `status = 'paid'` | 1 row | 1 row |
| T2 | `status LIKE 'p%'` | 2 rows | **Error:** `operator does not exist: order_status ~~ unknown` |
| T3 | `status = lower('PAID')` | 1 row | **Error:** `operator does not exist: order_status = text` |
| T4 | `ORDER BY status` | cancelled, paid, pending, shipped | **pending, paid, shipped, cancelled** |
| T5 | `status > 'paid'` | pending, shipped | **cancelled, shipped** |
| T6 | Prepared with a `text` parameter | 1 row | **Error** at PREPARE: `operator does not exist: order_status = text` |
| T7 | Prepared with an untyped parameter | — | 1 row |

- Only a plain string literal (T1) works the same on both types.
- T2 and T3 fail loudly. Anything that produces a TEXT value — LIKE, `lower()`, a text expression — has no operator against the enum.
- T4 and T5 fail silently. ORDER BY follows the enum's declaration order instead of alphabetical, and `> 'paid'` returns a different set of rows. There's no error, so the app just gets different results.
- T6 vs T7: the outcome depends on how the parameter is typed. A statement prepared with a `text` parameter can't even be prepared against the enum. Left untyped, Postgres infers the enum and it works. So whether the app survives depends on how its driver binds strings.

E1's "the basic queries still worked" only holds for string literals. The enum is not a drop-in replacement for TEXT.
