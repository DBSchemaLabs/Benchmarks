# Notes

Ran on the E3 database. Each operation targets the `orders` view and runs in a transaction that is rolled back.

| Test | Operation | Result |
|---|---|---|
| T1 | `INSERT ... ON CONFLICT (id) DO NOTHING` | **Error:** `there is no unique or exclusion constraint matching the ON CONFLICT specification` |
| T2 | `SELECT ... FOR UPDATE` | Works: returned `1 \| paid` |
| T3 | `COPY orders(status) FROM STDIN` (2 rows) | Works: 2 rows copied through the INSTEAD OF trigger |
| T4 | `TRUNCATE orders` | **Error:** `"orders" is not a table` |
| T5 | `ALTER TABLE orders ADD COLUMN note text` | **Error:** `ALTER action ADD COLUMN cannot be performed on relation "orders"` / `This operation is not supported for views` |

- Upserts fail. The primary key lives on `orders_base`, and the view has no unique constraint for `ON CONFLICT` to match.
- Row locks and COPY work. COPY goes through the INSTEAD OF trigger one row at a time.
- TRUNCATE and ALTER TABLE fail, because `orders` is a view now. Later migrations, ORM schema tools and test cleanup that truncates tables all have to know to target `orders_base` instead.
- Not tested: `FOR UPDATE` on a join view probably also locks the matching `order_status` row. Two transactions locking different orders with the same status might block each other.

E3 kept insert, update and select working, but 3 of these 5 common operations fail through the view.
