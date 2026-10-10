# Notes

Ran on the E3 database after a fresh E3 run. Added a rare `refunded` status (50 rows out of about 2 million) and an index on `orders_base(status_id)`, then fetched those 50 rows two ways.

| Measurement | Through the `orders` view | Directly on `orders_base` |
|---|---:|---:|
| Plan | Parallel Seq Scan + Hash Join | Index Scan on `orders_base_status_id_idx` |
| Rows scanned | ~2 million (666,736 per process × 3) | 50 |
| Buffers touched | 23,109 (12,992 hit, 10,117 read) | 5 |
| Estimated rows | 1,527 | 1 |
| Actual rows | 50 | 50 |
| Execution time | **70.423 ms** | **0.015 ms** |

Setup: creating the index took 489.135 ms, and ANALYZE took 56.243 ms.

- Same 50 rows, about 4,700× slower through the view.
- The index exists and works: the direct query uses it. Through the view, the planner scanned the whole table instead.
- The view filters on the status name, so the planner doesn't know at plan time which `status_id` `'refunded'` maps to. It estimated 1,527 rows and chose a parallel sequential scan with a hash join.
- The direct query's estimate was off the other way: 1 row versus 50 actual. The value is too rare to show up in the ANALYZE sample, but an index scan is the right plan either way.

The view keeps the old queries working, but a selective read on status loses the index.
