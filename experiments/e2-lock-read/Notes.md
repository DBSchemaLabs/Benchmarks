# Notes

- The TEXT-to-ENUM conversion took 3.040 seconds and held an AccessExclusiveLock on orders.
- A concurrent primary-key read returning just 9 rows took 2.712 seconds, waiting for the remaining rewrite.
- The same read after ALTER completed took 0.525 ms.

The query still returned the correct result, but the migration blocked reads—even a small indexed query.