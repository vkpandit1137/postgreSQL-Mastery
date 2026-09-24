# STRUCTURE.md — The Complete Program Tree

**PostgreSQL: Zero to Senior Database Engineer**
115 days · 13 phases · 1 practice database · ~3,200 practice problems

> Read `RULES.md` before Day 1. Read this file whenever you want to know where
> you are and what is coming.

---

## The Waterfall

Every concept sits on top of the ones before it. Nothing is used before it is
taught. This is the dependency spine of the whole program:

```
SELECT literals
   └─ SELECT FROM table
        └─ column lists & aliases
             └─ ORDER BY / LIMIT / DISTINCT
                  └─ WHERE
                       └─ AND / OR / NOT
                            └─ NULL logic
                                 └─ IN / BETWEEN / LIKE
                                      └─ functions (string, math, date)
                                           └─ CASE
                                                └─ aggregates
                                                     └─ GROUP BY
                                                          └─ HAVING
                                                               └─ JOIN
                                                                    └─ set operations
                                                                         └─ subqueries
                                                                              └─ CTEs
                                                                                   └─ recursive CTEs
                                                                                        └─ window functions
                                                                                             └─ DDL & constraints
                                                                                                  └─ DML & transactions
                                                                                                       └─ advanced types
                                                                                                            └─ indexes & EXPLAIN
                                                                                                                 └─ MVCC & locking
                                                                                                                      └─ views, functions, triggers
                                                                                                                           └─ operations & scaling
                                                                                                                                └─ senior design & interview
```

---

## Directory Tree

```
postgresql-mastery/
│
├── README.md                          ← start here
├── RULES.md                           ← the learning contract (read first)
├── STRUCTURE.md                       ← this file
├── PROGRESS.md                        ← your tracker (tick days off)
├── mistakes.md                        ← YOU create this on Day 1 (rule L6)
│
├── datasets/
│   ├── 00_create_database.sql         ← creates the `shopdb` database
│   ├── 01_schema.sql                  ← all practice tables (DDL)
│   ├── 02_data.sql                    ← the seed rows
│   ├── 03_extra_tables.sql            ← tables unlocked in later phases
│   ├── 90_bigdata.sql                 ← multi-million-row tables for Phase 9
│   ├── 99_reset.sql                   ← restore everything to clean state
│   └── DATA_DICTIONARY.md             ← every table & column explained
│
├── cheatsheets/
│   ├── psql-meta-commands.md
│   ├── logical-query-processing-order.md
│   ├── join-decision-tree.md
│   ├── index-decision-tree.md
│   ├── explain-plan-reading-guide.md
│   ├── isolation-levels-matrix.md
│   ├── data-type-selection-guide.md
│   └── interview-rapid-reference.md
│
├── phase-01-foundations/              Days 01–06   · Absolute Beginner
├── phase-02-filtering/                Days 07–18   · Absolute Beginner
├── phase-03-aggregation/              Days 19–25   · Absolute Beginner
├── phase-04-joins/                    Days 26–35   · Confident Beginner
├── phase-05-subqueries-ctes/          Days 36–45   · Confident Beginner
├── phase-06-window-functions/         Days 46–52   · Confident Beginner
├── phase-07-ddl-modeling/             Days 53–65   · Intermediate
├── phase-08-advanced-types/           Days 66–72   · Intermediate
├── phase-09-indexing-performance/     Days 73–81   · Intermediate → Advanced
├── phase-10-transactions-concurrency/ Days 82–88   · Advanced
├── phase-11-programmability/          Days 89–95   · Advanced
├── phase-12-operations/               Days 96–105  · Advanced → Senior
└── phase-13-senior-interview/         Days 106–115 · Senior
```

---

## PHASE 1 — Foundations
`phase-01-foundations/` · **Days 1–6** · Level: *Absolute Beginner*

> Goal: get PostgreSQL running, get comfortable in `psql`, and read data out of
> a single table without fear.

| Day | File | New concepts |
|-----|------|--------------|
| 01 | `day-01-install-and-psql.md` | Installing PostgreSQL, server vs client, `psql`, meta-commands (`\l \c \dt \d \q`), your first statement |
| 02 | `day-02-relational-model-and-select.md` | Database/table/row/column, `SELECT` with no table, literals, operators, `::` casts, basic types |
| 03 | `day-03-build-practice-db-and-select-from.md` | Creating `shopdb`, loading the seed, `SELECT * FROM`, reading result sets |
| 04 | `day-04-columns-aliases-expressions.md` | Choosing columns, `AS` aliases, quoted identifiers, computed columns, `\|\|` concatenation |
| 05 | `day-05-order-by-limit-distinct.md` | `ORDER BY` (ASC/DESC, multi-key, NULLS FIRST/LAST), `LIMIT`, `OFFSET`, `FETCH`, `DISTINCT`, `DISTINCT ON` |
| 06 | `day-06-checkpoint-1.md` | ✅ **Checkpoint 1** — 60 mixed problems, self-assessment |

---

## PHASE 2 — Filtering & Expressions
`phase-02-filtering/` · **Days 7–18** · Level: *Absolute Beginner*

> Goal: ask precise questions of one table. This is where most of the day-to-day
> SQL vocabulary lives.

| Day | File | New concepts |
|-----|------|--------------|
| 07 | `day-07-where-comparison.md` | `WHERE`, `= <> < > <= >=`, filtering text/numbers/dates |
| 08 | `day-08-and-or-not-precedence.md` | `AND`, `OR`, `NOT`, parentheses, precedence traps |
| 09 | `day-09-null-and-three-valued-logic.md` | `NULL`, `IS NULL`, `IS NOT NULL`, `IS DISTINCT FROM`, TRUE/FALSE/UNKNOWN |
| 10 | `day-10-in-between-ranges.md` | `IN`, `NOT IN` (+ the NULL trap), `BETWEEN`, half-open ranges |
| 11 | `day-11-like-ilike-patterns.md` | `LIKE`, `ILIKE`, `%` `_`, `ESCAPE`, `SIMILAR TO`, `~` regex intro |
| 12 | `day-12-checkpoint-2.md` | ✅ **Checkpoint 2** — filtering mastery, 70 problems |
| 13 | `day-13-string-functions.md` | `length upper lower trim substring position replace split_part left right lpad format concat_ws` |
| 14 | `day-14-numeric-and-math.md` | `integer` vs `numeric` vs `float`, integer division, `round ceil floor abs mod power random`, money mistakes |
| 15 | `day-15-dates-and-times-1.md` | `date time timestamp timestamptz`, literals, `current_date now()`, `EXTRACT`, `date_trunc` |
| 16 | `day-16-dates-and-times-2.md` | `interval` arithmetic, `age()`, `to_char`/`to_date`, time zones, `AT TIME ZONE`, storing time correctly |
| 17 | `day-17-case-coalesce-nullif.md` | `CASE` (simple & searched), `COALESCE`, `NULLIF`, `GREATEST`, `LEAST`, nested conditionals |
| 18 | `day-18-checkpoint-3.md` | ✅ **Checkpoint 3** — expressions + filtering, 80 problems |

---

## PHASE 3 — Aggregation
`phase-03-aggregation/` · **Days 19–25** · Level: *Absolute Beginner → Confident*

> Goal: turn many rows into one number, then into grouped summaries. This is
> where SQL starts to feel powerful.

| Day | File | New concepts |
|-----|------|--------------|
| 19 | `day-19-aggregate-functions.md` | `COUNT SUM AVG MIN MAX`, `COUNT(*)` vs `COUNT(col)`, NULL handling in aggregates |
| 20 | `day-20-group-by.md` | `GROUP BY`, grouping rules, the "column must appear in GROUP BY" error |
| 21 | `day-21-having-and-query-order.md` | `HAVING`, `WHERE` vs `HAVING`, **logical order of query processing** |
| 22 | `day-22-multi-key-filter-distinct-agg.md` | Grouping by several keys, `FILTER (WHERE ...)`, `COUNT(DISTINCT x)`, conditional aggregation |
| 23 | `day-23-agg-collections-and-stats.md` | `string_agg`, `array_agg`, `bool_and/or`, `percentile_cont`, `mode()`, `stddev`, `variance` |
| 24 | `day-24-grouping-sets-rollup-cube.md` | `GROUPING SETS`, `ROLLUP`, `CUBE`, `GROUPING()`, subtotal reports |
| 25 | `day-25-checkpoint-4.md` | ✅ **Checkpoint 4** — aggregation, 75 problems |

---

## PHASE 4 — Joins & Set Operations
`phase-04-joins/` · **Days 26–35** · Level: *Confident Beginner*

> Goal: combine tables. The single most interviewed topic in SQL.

| Day | File | New concepts |
|-----|------|--------------|
| 26 | `day-26-keys-and-relationships.md` | Primary/foreign keys conceptually, 1:1, 1:N, M:N, reading an ER diagram, our schema map |
| 27 | `day-27-inner-join.md` | `INNER JOIN ... ON`, table aliases, join cardinality, row multiplication |
| 28 | `day-28-left-and-right-join.md` | `LEFT JOIN`, `RIGHT JOIN`, NULL-extended rows, preserving the driving table |
| 29 | `day-29-full-join-and-anti-joins.md` | `FULL OUTER JOIN`, anti-join pattern (`LEFT JOIN ... WHERE x IS NULL`), finding missing data |
| 30 | `day-30-multi-table-joins.md` | 3, 4, 5-table joins, join chains, fan-out and double-counting |
| 31 | `day-31-checkpoint-5.md` | ✅ **Checkpoint 5** — joins, 70 problems |
| 32 | `day-32-self-cross-nonequi-joins.md` | Self joins, `CROSS JOIN`, non-equi joins, `USING` vs `ON`, why `NATURAL JOIN` is a trap |
| 33 | `day-33-set-operations.md` | `UNION`, `UNION ALL`, `INTERSECT`, `EXCEPT`, column compatibility, ordering set results |
| 34 | `day-34-joins-plus-aggregation.md` | Joins + `GROUP BY` + `HAVING` together, the aggregate-before-join pattern |
| 35 | `day-35-checkpoint-6-mini-project.md` | ✅ **Checkpoint 6** + **Mini-project 1**: full business reporting suite |

---

## PHASE 5 — Subqueries & CTEs
`phase-05-subqueries-ctes/` · **Days 36–45** · Level: *Confident Beginner*

> Goal: compose queries out of queries. Where beginners plateau and where
> mid-level engineers separate themselves.

| Day | File | New concepts |
|-----|------|--------------|
| 36 | `day-36-scalar-subqueries.md` | Subquery returning one value, in `SELECT`/`WHERE`, "more than one row returned" error |
| 37 | `day-37-in-any-all-subqueries.md` | `IN (SELECT ...)`, `ANY`/`SOME`, `ALL`, the `NOT IN` + NULL disaster |
| 38 | `day-38-exists-and-correlated.md` | `EXISTS`, `NOT EXISTS`, correlated subqueries, per-row evaluation model |
| 39 | `day-39-derived-tables.md` | Subqueries in `FROM`, mandatory aliases, multi-level aggregation |
| 40 | `day-40-checkpoint-7.md` | ✅ **Checkpoint 7** — subqueries, 70 problems |
| 41 | `day-41-ctes-with.md` | `WITH`, naming steps, multiple CTEs, refactoring nested subqueries, materialization |
| 42 | `day-42-recursive-ctes-1.md` | `WITH RECURSIVE` mechanics, anchor + recursive term, termination, `generate_series` |
| 43 | `day-43-recursive-ctes-2.md` | Category trees, org charts, graph traversal, cycle detection, path building, gap filling |
| 44 | `day-44-lateral.md` | `LATERAL`, `CROSS JOIN LATERAL`, `LEFT JOIN LATERAL`, top-N-per-group |
| 45 | `day-45-checkpoint-8.md` | ✅ **Checkpoint 8** — subqueries + CTEs + joins, 80 problems |

---

## PHASE 6 — Window Functions
`phase-06-window-functions/` · **Days 46–52** · Level: *Confident Beginner → Intermediate*

> Goal: per-row calculations over related rows. The #1 discriminator in
> mid/senior SQL interviews.

| Day | File | New concepts |
|-----|------|--------------|
| 46 | `day-46-window-basics.md` | `OVER ()`, `PARTITION BY`, aggregates as windows, window vs `GROUP BY` |
| 47 | `day-47-ranking-functions.md` | `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `PERCENT_RANK`, `NTILE`, top-N-per-group |
| 48 | `day-48-lag-lead-value-functions.md` | `LAG`, `LEAD`, `FIRST_VALUE`, `LAST_VALUE`, `NTH_VALUE`, period-over-period change |
| 49 | `day-49-window-frames.md` | `ROWS` / `RANGE` / `GROUPS`, `UNBOUNDED PRECEDING`, running totals, moving averages, the `LAST_VALUE` trap |
| 50 | `day-50-named-windows-and-combining.md` | `WINDOW` clause, several windows, windows + CTEs + joins, filtering windowed results |
| 51 | `day-51-checkpoint-9.md` | ✅ **Checkpoint 9** — window functions, 75 problems |
| 52 | `day-52-mini-project-cohort-analysis.md` | **Mini-project 2**: retention cohorts, funnels, RFM segmentation, sessionization |

---

## PHASE 7 — DDL & Data Modeling
`phase-07-ddl-modeling/` · **Days 53–65** · Level: *Intermediate*

> Goal: stop being a consumer of schemas and start being an author of them.
> You now re-read `datasets/01_schema.sql` and understand every line.

| Day | File | New concepts |
|-----|------|--------------|
| 53 | `day-53-create-table-and-types.md` | `CREATE TABLE`, choosing types, `text` vs `varchar`, `numeric` vs `float`, `timestamptz` always |
| 54 | `day-54-defaults-identity-sequences.md` | `DEFAULT`, `GENERATED ... AS IDENTITY`, `serial` (and why it's legacy), sequences, gaps |
| 55 | `day-55-constraints.md` | `NOT NULL`, `UNIQUE`, `CHECK`, named constraints, multi-column uniqueness, NULLs in UNIQUE |
| 56 | `day-56-primary-keys.md` | `PRIMARY KEY`, surrogate vs natural, composite keys, `uuid` vs `bigint`, key design for scale |
| 57 | `day-57-foreign-keys.md` | `REFERENCES`, `ON DELETE` / `ON UPDATE` actions, deferrable constraints, orphan prevention |
| 58 | `day-58-checkpoint-10.md` | ✅ **Checkpoint 10** — build a schema from scratch, 50 problems |
| 59 | `day-59-insert-deep-dive.md` | `INSERT`, multi-row, `INSERT ... SELECT`, `DEFAULT VALUES`, `RETURNING`, `COPY`, bulk loading |
| 60 | `day-60-update-delete.md` | `UPDATE ... FROM`, `DELETE ... USING`, `RETURNING`, safe-delete workflow, `TRUNCATE` vs `DELETE` |
| 61 | `day-61-upsert-and-merge.md` | `ON CONFLICT DO NOTHING/UPDATE`, `EXCLUDED`, conflict targets, `MERGE`, idempotent writes |
| 62 | `day-62-alter-table-migrations.md` | `ALTER TABLE`, adding/dropping columns, type changes, lock implications, zero-downtime migration playbook |
| 63 | `day-63-normalization.md` | Functional dependencies, 1NF → 2NF → 3NF → BCNF, worked normalization of a bad schema |
| 64 | `day-64-modeling-and-denormalization.md` | ER modeling from requirements, when to denormalize, history tables, schemas & namespacing |
| 65 | `day-65-checkpoint-11-design-project.md` | ✅ **Checkpoint 11** + **Mini-project 3**: design & build a ticketing system schema |

---

## PHASE 8 — Advanced Data Types
`phase-08-advanced-types/` · **Days 66–72** · Level: *Intermediate*

> Goal: use the types that make PostgreSQL PostgreSQL.

| Day | File | New concepts |
|-----|------|--------------|
| 66 | `day-66-text-collation-regex.md` | Encoding, collation, `citext`, case-insensitive design, full regex (`~ ~* regexp_replace regexp_matches`) |
| 67 | `day-67-full-text-search.md` | `tsvector`, `tsquery`, `to_tsvector`, `@@`, `ts_rank`, dictionaries, `websearch_to_tsquery`, GIN indexing |
| 68 | `day-68-json-jsonb.md` | `json` vs `jsonb`, `-> ->> #> #>> @> ?`, `jsonb_set`, `jsonb_array_elements`, `jsonb_to_record`, when NOT to use JSON |
| 69 | `day-69-arrays.md` | Array literals, indexing, slicing, `ANY/ALL`, `unnest`, `array_agg` round-trip, `@> && \|\|`, GIN on arrays |
| 70 | `day-70-enums-domains-composites-ranges.md` | `CREATE TYPE ... AS ENUM`, domains, composite types, `int4range`/`tstzrange`, exclusion constraints |
| 71 | `day-71-uuid-generated-bytea-misc.md` | `uuid` & generation strategies, `GENERATED ALWAYS AS ... STORED`, `bytea`, `inet`/`cidr`, `hstore` |
| 72 | `day-72-checkpoint-12.md` | ✅ **Checkpoint 12** — advanced types, 70 problems |

---

## PHASE 9 — Indexing & Performance
`phase-09-indexing-performance/` · **Days 73–81** · Level: *Intermediate → Advanced*

> Goal: make queries fast on purpose instead of by accident. Load
> `datasets/90_bigdata.sql` on Day 73 — you need millions of rows to feel this.

| Day | File | New concepts |
|-----|------|--------------|
| 73 | `day-73-storage-internals.md` | Pages, heap tuples, tuple headers, `ctid`, TOAST, fillfactor, table bloat, row size math |
| 74 | `day-74-btree-indexes.md` | `CREATE INDEX`, B-tree structure, sargability, multi-column order, index-only scans, `INCLUDE` |
| 75 | `day-75-explain-basics.md` | `EXPLAIN`, node types, cost units, estimated vs actual rows, reading a plan tree |
| 76 | `day-76-explain-analyze-deep.md` | `EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)`, loops, timing, buffer hits, spills to disk |
| 77 | `day-77-scans-and-join-algorithms.md` | Seq/Index/Bitmap scans, Nested Loop / Hash Join / Merge Join, when each wins, parallel plans |
| 78 | `day-78-statistics-and-planner.md` | `ANALYZE`, `pg_stats`, selectivity, correlation, extended statistics, planner GUCs, bad-estimate debugging |
| 79 | `day-79-index-types.md` | GIN, GiST, BRIN, Hash, SP-GiST, partial, expression, covering, unique, `CONCURRENTLY`, index bloat |
| 80 | `day-80-query-tuning-workshop.md` | 12 slow queries, diagnosed and rewritten; anti-patterns; `pg_stat_statements` |
| 81 | `day-81-checkpoint-13.md` | ✅ **Checkpoint 13** — performance, 40 diagnosis problems |

---

## PHASE 10 — Transactions & Concurrency
`phase-10-transactions-concurrency/` · **Days 82–88** · Level: *Advanced*

> Goal: reason correctly about what happens when many users hit the database at
> once. Requires two `psql` sessions side by side.

| Day | File | New concepts |
|-----|------|--------------|
| 82 | `day-82-transactions-acid.md` | `BEGIN/COMMIT/ROLLBACK`, ACID, autocommit, `SAVEPOINT`, aborted-transaction state |
| 83 | `day-83-isolation-levels.md` | Dirty/non-repeatable/phantom reads, Read Committed, Repeatable Read, Serializable, serialization failures & retry loops |
| 84 | `day-84-mvcc.md` | Snapshots, `xmin`/`xmax`, visibility rules, why UPDATE is DELETE+INSERT, long transactions as a hazard |
| 85 | `day-85-vacuum-and-bloat.md` | Dead tuples, `VACUUM`, `VACUUM FULL`, autovacuum tuning, freeze & xid wraparound, visibility map |
| 86 | `day-86-locking-and-deadlocks.md` | Row vs table locks, lock modes & conflict matrix, `FOR UPDATE/SHARE`, `NOWAIT`, `SKIP LOCKED`, deadlock anatomy, `pg_locks` |
| 87 | `day-87-concurrency-patterns.md` | Job queues, optimistic locking with version columns, idempotency keys, advisory locks, contention-free counters |
| 88 | `day-88-checkpoint-14.md` | ✅ **Checkpoint 14** — concurrency scenarios, 45 problems |

---

## PHASE 11 — Programmability
`phase-11-programmability/` · **Days 89–95** · Level: *Advanced*

> Goal: put logic inside the database, and know when you shouldn't.

| Day | File | New concepts |
|-----|------|--------------|
| 89 | `day-89-views.md` | `CREATE VIEW`, updatable views, `WITH CHECK OPTION`, view dependency pain |
| 90 | `day-90-materialized-views.md` | `MATERIALIZED VIEW`, `REFRESH ... CONCURRENTLY`, staleness strategies, incremental rollups |
| 91 | `day-91-sql-functions.md` | `CREATE FUNCTION ... LANGUAGE sql`, arguments, `RETURNS TABLE`, `IMMUTABLE/STABLE/VOLATILE`, inlining |
| 92 | `day-92-plpgsql-fundamentals.md` | `DO` blocks, `DECLARE`, control flow, loops, `RETURN QUERY`, `RAISE`, dollar quoting |
| 93 | `day-93-plpgsql-advanced.md` | Exception blocks, `EXECUTE` dynamic SQL, `format()` & injection safety, cursors, PL/pgSQL performance |
| 94 | `day-94-triggers.md` | `BEFORE/AFTER/INSTEAD OF`, row vs statement, `NEW`/`OLD`, audit tables, soft-delete triggers, trigger anti-patterns |
| 95 | `day-95-procedures-notify-checkpoint.md` | `CREATE PROCEDURE`, `CALL`, transaction control in procedures, `LISTEN`/`NOTIFY`, ✅ **Checkpoint 15** |

---

## PHASE 12 — Operations & Production
`phase-12-operations/` · **Days 96–105** · Level: *Advanced → Senior*

> Goal: be the person the team calls when the database is on fire.

| Day | File | New concepts |
|-----|------|--------------|
| 96 | `day-96-roles-and-privileges.md` | Roles vs users, `GRANT`/`REVOKE`, ownership, `DEFAULT PRIVILEGES`, least-privilege app roles, `pg_hba.conf` |
| 97 | `day-97-row-level-security.md` | `ENABLE ROW LEVEL SECURITY`, policies, `USING` vs `WITH CHECK`, multi-tenant isolation, RLS performance |
| 98 | `day-98-configuration-and-memory.md` | `postgresql.conf`, `shared_buffers`, `work_mem`, `maintenance_work_mem`, `effective_cache_size`, WAL settings, `ALTER SYSTEM` |
| 99 | `day-99-connections-and-pooling.md` | Process-per-connection model, connection limits, PgBouncer modes, prepared statements & pooling conflicts |
| 100 | `day-100-backup-and-restore.md` | `pg_dump` formats, `pg_restore`, `pg_dumpall`, `pg_basebackup`, WAL archiving, PITR, restore drills |
| 101 | `day-101-replication-and-ha.md` | WAL, streaming replication, sync vs async, replica lag, failover, logical replication, publications/subscriptions |
| 102 | `day-102-partitioning.md` | Range/list/hash partitioning, partition pruning, attach/detach, indexes on partitions, time-series retention |
| 103 | `day-103-extensions.md` | `CREATE EXTENSION`, `pg_stat_statements`, `pgcrypto`, `postgres_fdw`, `pg_trgm`, `PostGIS`, `TimescaleDB`, `pgvector` |
| 104 | `day-104-monitoring-and-incidents.md` | `pg_stat_activity`, `pg_stat_user_tables`, cache hit ratio, bloat queries, killing queries, incident playbooks |
| 105 | `day-105-upgrades-maintenance-checkpoint.md` | Minor vs major upgrades, `pg_upgrade`, logical-replication upgrades, maintenance calendar, ✅ **Checkpoint 16** |

---

## PHASE 13 — Senior Engineer & Interview
`phase-13-senior-interview/` · **Days 106–115** · Level: *Senior*

> Goal: judgment. There are no single right answers here — there are defensible
> designs and indefensible ones.

| Day | File | New concepts |
|-----|------|--------------|
| 106 | `day-106-schema-design-patterns.md` | Multi-tenancy (3 models), soft deletes, temporal/bitemporal tables, event sourcing, outbox pattern, EAV |
| 107 | `day-107-anti-patterns.md` | 30 anti-patterns with the production incident each one causes |
| 108 | `day-108-scaling-strategies.md` | Vertical limits, read replicas & lag, caching layers, sharding approaches, Citus, CQRS, when to move off Postgres |
| 109 | `day-109-postgres-in-the-real-stack.md` | ORMs & N+1, migrations in CI/CD, testing against real Postgres, observability, cost, Postgres vs MySQL/Mongo/Redis/warehouses |
| 110 | `day-110-case-study-ecommerce.md` | End-to-end: inventory, orders, payments, idempotency, reporting, hot-row contention |
| 111 | `day-111-case-study-multitenant-saas.md` | End-to-end: tenancy, RLS, per-tenant limits, noisy neighbours, migrations across 10k tenants |
| 112 | `day-112-case-study-timeseries-analytics.md` | End-to-end: high-rate ingest, partitioning, rollups, retention, BRIN, compression |
| 113 | `day-113-interview-drill-sql.md` | **90 SQL interview problems** from junior → staff, with model solutions & follow-ups |
| 114 | `day-114-interview-drill-internals-design.md` | **120 verbal questions**: internals, trade-offs, incident scenarios, system design rubric |
| 115 | `day-115-capstone-and-final-assessment.md` | Capstone build + 3-hour final exam + scoring rubric + what to do next |

---

## Checkpoint Map

| Checkpoint | Day | Covers | Pass mark |
|---|---|---|---|
| 1 | 06 | Phase 1 | 70% |
| 2 | 12 | Days 7–11 | 70% |
| 3 | 18 | Phase 2 | 70% |
| 4 | 25 | Phase 3 | 70% |
| 5 | 31 | Days 26–30 | 70% |
| 6 | 35 | Phase 4 | 75% |
| 7 | 40 | Days 36–39 | 75% |
| 8 | 45 | Phase 5 | 75% |
| 9 | 51 | Phase 6 | 75% |
| 10 | 58 | Days 53–57 | 75% |
| 11 | 65 | Phase 7 | 80% |
| 12 | 72 | Phase 8 | 80% |
| 13 | 81 | Phase 9 | 80% |
| 14 | 88 | Phase 10 | 80% |
| 15 | 95 | Phase 11 | 80% |
| 16 | 105 | Phase 12 | 80% |
| Final | 115 | Everything | 85% |

---

## Practice Volume

| Phase | Days | Practice problems (approx.) |
|---|---|---|
| 1 Foundations | 6 | 160 |
| 2 Filtering & Expressions | 12 | 400 |
| 3 Aggregation | 7 | 230 |
| 4 Joins | 10 | 330 |
| 5 Subqueries & CTEs | 10 | 300 |
| 6 Window Functions | 7 | 220 |
| 7 DDL & Modeling | 13 | 330 |
| 8 Advanced Types | 7 | 200 |
| 9 Indexing & Performance | 9 | 180 |
| 10 Transactions & Concurrency | 7 | 140 |
| 11 Programmability | 7 | 150 |
| 12 Operations | 10 | 180 |
| 13 Senior & Interview | 10 | 400 |
| **Total** | **115** | **≈ 3,220** |

---

## If You Have Less Time

**Fast track (45 days)** — for someone who already writes basic SQL:
Days 5, 9, 10, 11, 14, 16, 17, 19–25, 27–35, 36–45, 46–52, 55–57, 61, 62, 63,
68, 73–81, 82–88, 102, 106, 107, 113, 114.

**Interview sprint (16 days)** — the fortnight before an interview:
Days 21, 29, 34, 38, 43, 44, 47, 49, 63, 74, 76, 83, 86, 107, 113, 114.

Neither substitutes for the full path. They are triage, not training.
