# PostgreSQL: Zero to Senior Database Engineer

A 115-day, example-first, practice-heavy program that takes you from *"I have
never installed a database"* to *"I can pass a senior PostgreSQL interview and
run this thing in production."*

---

## What makes this different

**It is a waterfall, not a reference manual.** Concepts arrive one at a time and
never before they are needed. On Day 5 you will not see a `WHERE` clause,
because `WHERE` is Day 7. On Day 20 you will not see a `JOIN`, because `JOIN` is
Day 27. Every single query you meet is built only from things you already know.

**Every new concept is immediately mixed with the old ones.** Day 34 is not
"joins". Day 34 is "joins + `GROUP BY` + `HAVING` + `CASE` + date functions +
`NULL` handling", because that is what a real query looks like.

**Nothing is abstract.** There are no `foo`/`bar` tables. There is one realistic
e-commerce database — customers, orders, products, payments, reviews, an
employee hierarchy — and you use it for all 115 days, until you know its shape
the way you know your own kitchen.

**Roughly 3,200 practice problems**, every one with a worked solution and an
explanation of *why*.

---

## Start here, in this order

1. **`RULES.md`** — the learning contract. Ten rules for how the material is
   written, ten for how you must work through it. It takes eight minutes to read
   and it is the difference between finishing and drifting.
2. **`STRUCTURE.md`** — the full 115-day tree, phase by phase, with the new
   concepts introduced on each day.
3. **`phase-01-foundations/day-01-install-and-psql.md`** — begin.

---

## The shape of a day

Every day file is self-contained and takes **90–150 minutes**:

```
Why this matters          ← one paragraph on why you should care
Part 1 … Part N           ← concept, example, what happened, the rule, the edge cases
Traps & Gotchas           ← the mistakes that cause production incidents
Interview angles          ← how this gets asked at junior / mid / senior level
Practice
  Section A — Drill       ← the new concept alone
  Section B — Combination ← new concept + everything from previous days
  Section C — Recall      ← older concepts only, so you don't forget them
  Section D — Challenge   ← optional, hard
Solutions                 ← full answers with reasoning
Checklist                 ← can you do these things? tick them off
What's next
```

Every fifth or sixth day is a **Checkpoint**: no new material, only mixed
problems and a score. Below 70%, repeat the phase. This is not optional.

---

## The 13 phases

| Phase | Days | Topic | You finish able to… |
|---|---|---|---|
| 1 | 1–6 | Foundations | read data out of a table |
| 2 | 7–18 | Filtering & expressions | ask precise questions of one table |
| 3 | 19–25 | Aggregation | turn rows into business numbers |
| 4 | 26–35 | Joins & set operations | combine tables correctly |
| 5 | 36–45 | Subqueries & CTEs | compose queries out of queries |
| 6 | 46–52 | Window functions | do per-row analytics over related rows |
| 7 | 53–65 | DDL & data modeling | design and build schemas, not just read them |
| 8 | 66–72 | Advanced types | use JSONB, arrays, ranges, full-text search |
| 9 | 73–81 | Indexing & performance | read a query plan and fix a slow query |
| 10 | 82–88 | Transactions & concurrency | reason about many users at once |
| 11 | 89–95 | Programmability | views, functions, PL/pgSQL, triggers |
| 12 | 96–105 | Operations & production | back up, replicate, partition, monitor, survive incidents |
| 13 | 106–115 | Senior & interview | design systems, avoid anti-patterns, pass the interview |

Full detail: **`STRUCTURE.md`**.

---

## Setup (Day 1 walks you through all of this)

```bash
# macOS
brew install postgresql@16 && brew services start postgresql@16

# Ubuntu / Debian
sudo apt update && sudo apt install postgresql postgresql-contrib

# Windows
# Download the EnterpriseDB installer from postgresql.org/download/windows
```

Then, on Day 3, you build the practice database:

```bash
cd datasets
psql -U postgres -f 00_create_database.sql
psql -U postgres -d shopdb -f 01_schema.sql
psql -U postgres -d shopdb -f 02_data.sql
```

Broke something? `\i 99_reset.sql` puts it all back. Breaking things is
encouraged — that is what a practice database is for.

---

## Four things that decide whether this works for you

1. **Type every query. Never copy-paste.** Typing is how the syntax stops being
   something you look up and starts being something you know.
2. **Predict the result before you press Enter.** Say the row count out loud.
   Being wrong is the learning event; being right is just confirmation.
3. **Attempt every problem before reading the solution.** Twenty minutes of
   being stuck beats twenty solutions read.
4. **Keep `mistakes.md`.** One line per error: what you thought, what was true.
   Re-read it at every checkpoint. By Day 115 it is the single most valuable
   file in this directory, and it is the one you wrote.

---

## Pace

| Pace | Days per session | Calendar time |
|---|---|---|
| Recommended | 1 | ~4 months |
| Employed, evenings | 1 on weekdays | ~5.5 months |
| Intensive / between jobs | 2 | ~2 months |
| Faster than 2/day | — | You are reading, not learning. Don't. |

Short on time? `STRUCTURE.md` has a 45-day fast track and a 16-day interview
sprint. Both are triage, not training.

---

## Directory contents

```
README.md         you are here
RULES.md          the learning contract        ← read before Day 1
STRUCTURE.md      the complete 115-day tree
PROGRESS.md       your tracker
datasets/         the practice database + data dictionary
cheatsheets/      one-page references you will reach for constantly
phase-01 … 13/    the 115 day files
```

---

## Definition of done

You have finished when you can, from memory: model a domain and defend your
denormalizations; read an `EXPLAIN (ANALYZE, BUFFERS)` plan and name the
bottleneck; explain MVCC and autovacuum to a colleague; pick an isolation level
and justify it; design partitioning and indexing for a 500-million-row table;
debug a live lock-contention incident; and sit a 60-minute senior PostgreSQL
interview without hesitating.

Day 115 has the final exam and the rubric.

Good luck. Start with `RULES.md`.
