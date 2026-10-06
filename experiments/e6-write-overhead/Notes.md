# Notes

Ran on the E3 database after E5. Each case inserts 20,000 rows one at a time inside a PL/pgSQL loop, then rolls back.

| Target | Time | Per insert | vs plain table |
|---|---:|---:|---:|
| Plain TEXT table (new, empty) | 34.892 ms | 1.7 µs | 1.0× |
| `orders_base` directly (SMALLINT) | 134.606 ms | 6.7 µs | 3.9× |
| `orders` view (lookup + INSTEAD OF trigger) | **176.268 ms** | 8.8 µs | **5.1×** |

- Through the view, inserts were about 5× slower than into a plain table.
- Most of that gap isn't the trigger. Going to `orders_base` directly already costs 3.9×. The trigger adds the last 41.662 ms of the 141.376 ms gap, about 30%.
- `orders_base` differs from the plain table in several ways: about 2 million existing rows, a foreign key to `order_status`, a CHECK constraint, and a second index (on `status_id`, from E5). This run doesn't separate those costs.
- The loop runs inside the server, so there are no network round trips. A real app pays one per insert, which would likely dwarf the 2.1 µs the trigger adds per row.
- One run, no repeats.

The view does add write cost, but most of the measured 5× comes from the table underneath, not from the translation.
