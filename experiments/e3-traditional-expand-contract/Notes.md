# Experiment 3 — Online Schema Migration Using Expand/Contract

### Setup
- PostgreSQL 16 running locally on macOS, port `5499`.
- Dedicated database: `schema_labs_e3`.
- Created 2 million orders with `status TEXT` containing `pending`, `paid`, `shipped`, or `cancelled`.

### Migration

**Step 1 — Expand**
- Created an `order_status` lookup table mapping status names to `SMALLINT` IDs.
- Added a nullable `status_id` column (metadata-only change).
- Added a synchronization trigger to populate `status_id` on inserts and status updates.

**Step 2 — Backfill**
- Converted existing rows in batches of 100,000.
- Ran a concurrent writer performing inserts and updates.
- Verified that the original and new status representations remained consistent.

**Step 3 — Validate**
- Added and validated a `CHECK (status_id IS NOT NULL)` constraint using `NOT VALID`.
- Added and validated a foreign key referencing `order_status`.
- Refreshed table statistics using `ANALYZE`.

**Step 4 — Contract**
- Renamed `orders` to `orders_base` and dropped the original text column.
- Created an `orders` view exposing the original `id` and `status` fields through a lookup join.
- Added an `INSTEAD OF` trigger to translate writes on the view into operations on `orders_base`.
- Performed the cutover in a single transaction with a short lock timeout.

**Step 5 — Verify**
- Tested application-facing inserts, updates, and reads after migration.
- Verified row counts and inspected query performance with `EXPLAIN (ANALYZE, BUFFERS)`.

### Results

| Metric | Result |
|---|---:|
| Initial rows | 2,000,000 |
| Initial data insertion | 4.315 s |
| Add nullable column | 0.103 ms |
| Batched backfill | **5.136 s** |
| Inconsistent rows | **0** |
| Transactional cutover | **36 ms** |
| Concurrent writer iterations | 144 |
| Final rows | 2,000,142 |
| Filtered `COUNT(*)` query | 83.541 ms |

### Observations
- Schema expansion was inexpensive, and the backfill completed in approximately 5.1 seconds.
- The synchronization trigger maintained consistent mappings during concurrent writes.
- The final cutover took 36 ms (client-observed), but this does not establish the maximum time application queries were blocked.
- Basic application SQL continued working through the compatibility view.
- The filtered count query used a parallel sequential scan and hash join. PostgreSQL substantially underestimated matching rows (~636 estimated vs ~166,701 actual per participant).
- The compatibility view introduces an additional lookup join, potentially affecting query performance.
- Dropping the original text column does not immediately reclaim physical storage.
- Writer latency, lock waits, and pre-migration query performance were not measured.

### Conclusion
- Successfully changed the stored status representation from `TEXT` to `SMALLINT` while preserving the original application-facing schema for tested operations.
- The migration completed with **zero detected mapping inconsistencies**, a **5.136-second backfill**, and a **36 ms cutover**.
- Further measurements are needed to evaluate write availability, query-performance overhead, and storage savings.