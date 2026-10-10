# Experiment 3 — Online Schema Migration Using Expand/Contract

### Setup

- PostgreSQL 16 on macOS, port `5499`, database `schema_labs_e3`.
- Started with 2 million orders storing `status` as TEXT: `pending`, `paid`, `shipped`, or `cancelled`.

### Migration

1. **Expand:** Created a status lookup table, added nullable `status_id SMALLINT`, and installed a synchronization trigger.
2. **Backfill:** Converted existing rows in batches of 100,000 while a concurrent writer performed inserts and updates.
3. **Validate:** Added constraints using `NOT VALID`, validated non-null status IDs and foreign-key references, and ran `ANALYZE`.
4. **Contract:** In one transaction, renamed the table to `orders_base`, dropped the text column, and created an `orders` compatibility view with an `INSTEAD OF` write trigger. Used a short lock timeout for cutover.
5. **Verify:** Checked mapping consistency, row counts, application-facing reads and writes, and query plans.

### Results

| Metric | Result |
|---|---:|
| Initial rows | 2,000,000 |
| Initial data insertion | 4.315 s |
| Add nullable column | 0.103 ms |
| Batched backfill | **5.136 s** |
| Detected mapping inconsistencies | **0** |
| Transactional cutover, client-observed | **36 ms** |
| Concurrent writer iterations | 144 |
| Final rows | 2,000,142 |
| Filtered `COUNT(*)` query | 83.541 ms |
| Table size before migration | 88 MB |
| Table size after migration | **184 MB (~2.1×)** |
| Estimated dead tuples after migration | 0 |

### Observations

- Basic application reads and writes worked through the compatibility view, with no detected mapping inconsistencies.
- The 36 ms cutover does not establish the maximum time application queries were blocked. Writer latency and lock waits were not measured.
- The filtered count used a parallel sequential scan and hash join. PostgreSQL underestimated matching rows: approximately 636 estimated versus 166,701 actual per participant.
- The view adds a lookup join, but its performance overhead cannot be quantified without a pre-migration baseline.
- Table storage grew from **88 MB to 184 MB** following backfill UPDATEs. Dropping the text column did not immediately reclaim space. Zero estimated dead tuples does not imply space was returned to disk. These sizes exclude indexes.

### Conclusion

The experiment changed stored status values from TEXT to SMALLINT while preserving the application-facing schema for the tested operations. Mapping checks passed, but uninterrupted availability, query-performance overhead, and eventual storage savings still need measurement.