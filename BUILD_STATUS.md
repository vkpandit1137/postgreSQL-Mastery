# BUILD_STATUS.md — what exists so far

This program is being written in order, one phase at a time, because every day
file must obey the Waterfall Rule (`RULES.md` → R3): it may only use concepts
introduced on earlier days. Writing them out of order would break that guarantee.

This file tracks which day files exist. Delete it once the program is complete.

---

## ✅ Complete and ready to use

### Program scaffolding
| File | Status |
|---|---|
| `README.md` | ✅ |
| `RULES.md` | ✅ the teaching contract, 20 rules |
| `STRUCTURE.md` | ✅ full 115-day tree, all phases specified |
| `PROGRESS.md` | ✅ tracker with every day and checkpoint |

### Practice database — everything the 115 days run against
| File | Status |
|---|---|
| `datasets/00_create_database.sql` | ✅ |
| `datasets/01_schema.sql` | ✅ 9 tables |
| `datasets/02_data.sql` | ✅ 334 seed rows |
| `datasets/99_reset.sql` | ✅ |
| `datasets/90_bigdata.sql` | ✅ 16M rows for Phase 9 |
| `datasets/DATA_DICTIONARY.md` | ✅ every table and column documented |

### Phase 1 — Foundations (Days 1–6) — **complete**
| Day | File | Status |
|---|---|---|
| 01 | `phase-01-foundations/day-01-install-and-psql.md` | ✅ |
| 02 | `phase-01-foundations/day-02-relational-model-and-select.md` | ✅ |
| 03 | `phase-01-foundations/day-03-build-practice-db-and-select-from.md` | ✅ |
| 04 | `phase-01-foundations/day-04-columns-aliases-expressions.md` | ✅ |
| 05 | `phase-01-foundations/day-05-order-by-limit-distinct.md` | ✅ |
| 06 | `phase-01-foundations/day-06-checkpoint-1.md` | ✅ 60-problem checkpoint |

### Phase 2 — Filtering & Expressions (Days 7–18) — **complete**
| Day | File | Status |
|---|---|---|
| 07 | `phase-02-filtering/day-07-where-comparison.md` | ✅ |
| 08 | `phase-02-filtering/day-08-and-or-not-precedence.md` | ✅ |
| 09 | `phase-02-filtering/day-09-null-and-three-valued-logic.md` | ✅ the keystone day |
| 10 | `phase-02-filtering/day-10-in-between-ranges.md` | ✅ |
| 11 | `phase-02-filtering/day-11-like-ilike-patterns.md` | ✅ |
| 12 | `phase-02-filtering/day-12-checkpoint-2.md` | ✅ 70-problem checkpoint |
| 13 | `phase-02-filtering/day-13-string-functions.md` | ✅ |
| 14 | `phase-02-filtering/day-14-numeric-and-math.md` | ✅ |
| 15 | `phase-02-filtering/day-15-dates-and-times-1.md` | ✅ |
| 16 | `phase-02-filtering/day-16-dates-and-times-2.md` | ✅ |
| 17 | `phase-02-filtering/day-17-case-coalesce-nullif.md` | ✅ |
| 18 | `phase-02-filtering/day-18-checkpoint-3.md` | ✅ 80-problem checkpoint |

### Phase 3 — Aggregation (Days 19–25) — **partially written**
> ⚠️ Written ahead of schedule by mistake. Content is correct and follows the
> waterfall, but Days 24–25 are missing, so the phase is incomplete.

| Day | File | Status |
|---|---|---|
| 19 | `phase-03-aggregation/day-19-aggregate-functions.md` | ✅ |
| 20 | `phase-03-aggregation/day-20-group-by.md` | ✅ |
| 21 | `phase-03-aggregation/day-21-having-and-query-order.md` | ✅ |
| 22 | `phase-03-aggregation/day-22-multi-key-filter-distinct-agg.md` | ✅ |
| 23 | `phase-03-aggregation/day-23-agg-collections-and-stats.md` | ✅ |
| 24 | `phase-03-aggregation/day-24-grouping-sets-rollup-cube.md` | ❌ not written |
| 25 | `phase-03-aggregation/day-25-checkpoint-4.md` | ❌ not written |

### Cheatsheets
| File | Status |
|---|---|
| `cheatsheets/psql-meta-commands.md` | ✅ |

---

## ⏳ Specified but not yet written

Days **19–115** are fully specified in `STRUCTURE.md` — every day has its file
name, its position in the waterfall, and the exact list of concepts it
introduces. The content of those files has not been written yet.

| Phase | Days | Files written | Status |
|---|---|---|---|
| 3 — Aggregation | 19–25 | 5 / 7 | ⚠️ incomplete — see above |
| 4 — Joins & Set Operations | 26–35 | 0 / 10 | ⏳ |
| 5 — Subqueries & CTEs | 36–45 | 0 / 10 | ⏳ |
| 6 — Window Functions | 46–52 | 0 / 7 | ⏳ |
| 7 — DDL & Data Modeling | 53–65 | 0 / 13 | ⏳ |
| 8 — Advanced Types | 66–72 | 0 / 7 | ⏳ |
| 9 — Indexing & Performance | 73–81 | 0 / 9 | ⏳ |
| 10 — Transactions & Concurrency | 82–88 | 0 / 7 | ⏳ |
| 11 — Programmability | 89–95 | 0 / 7 | ⏳ |
| 12 — Operations & Production | 96–105 | 0 / 10 | ⏳ |
| 13 — Senior & Interview | 106–115 | 0 / 10 | ⏳ |

Remaining cheatsheets: `logical-query-processing-order.md`,
`join-decision-tree.md`, `index-decision-tree.md`,
`explain-plan-reading-guide.md`, `isolation-levels-matrix.md`,
`data-type-selection-guide.md`, `interview-rapid-reference.md`.

---

## You can start today

**Days 1–18 are complete** — about three and a half weeks of work, roughly 560
practice problems, all self-contained and correct. Set up the database and begin
Day 1 now; the later phases will be written well before you reach them.

By the end of Day 18 you can take any single table and ask an arbitrarily
precise question of it: filter it, transform it, label it, sort it, and handle
missing data deliberately. Phase 3 (Day 19) is where rows start collapsing into
summaries.

---

## The template every remaining day follows

Established by Days 1–6, and fixed by `RULES.md` → R14:

```
# Day NN — Title
> Phase | Level | Time | Prerequisites | New concepts
## Why this matters
## Part 1 … Part N      concept → example → what happened → the rule → edge cases → the trap
## Traps & Gotchas      table of the mistakes that cause real incidents
## Interview angles     junior / mid / senior framing of the same topic
## Practice
   ### Section A — Drill        (new concept alone, ~25 problems)
   ### Section B — Combination  (new + all previous concepts, ~20 problems)
   ### Section C — Recall       (older concepts only — spaced repetition, ~10)
   ### Section D — Challenge    (hard, optional, ~6)
## Solutions            every problem, with the reasoning
## Day NN Checklist
## What's next
```
