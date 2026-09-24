# RULES.md — The Learning Contract

These rules govern how this program is written, how it must be taught, and how
you (the learner) must work through it. If any future file contradicts this
document, **this document wins**.

---

## Part 1 — Rules for the Teacher (how content is written)

### R1. The learner starts at absolute zero
Day 1 assumes the learner has **never** installed a database, never opened a
terminal for database work, and does not know what a table, row, or column is.
Nothing is "obvious". Every acronym is expanded the first time it appears.

### R2. Experience level increments, and the tone increments with it
The program tracks an explicit **Learner Level** that rises through the phases:

| Days    | Level                | How the content talks to you |
|---------|----------------------|------------------------------|
| 1–20    | Absolute Beginner    | Every keyword explained, every output shown, heavy hand-holding |
| 21–37   | Confident Beginner   | Basics assumed, new syntax still fully explained |
| 38–58   | Intermediate         | You are expected to read error messages and debug yourself |
| 59–78   | Advanced / Practitioner | Trade-offs, production concerns, "why" over "how" |
| 79–90   | Senior Engineer      | Open-ended design problems, no single right answer, interview pressure |

Content must never talk down to a Day-70 learner, and never assume too much of
a Day-3 learner.

### R3. The Waterfall Rule (the most important rule)
**A query may only use concepts already taught.** Not one keyword, one function,
one clause from a future day may appear in an example or a practice problem.

Concretely:
- Day 6 teaches `WHERE`. No query before Day 6 contains `WHERE`.
- Day 16 teaches `GROUP BY`. No query before Day 16 contains `GROUP BY`.
- Day 21 teaches `JOIN`. Every query before Day 21 touches exactly one table.

If a concept is genuinely needed early, it gets its own earlier day. There are
no "you'll understand this later" queries.

### R4. The Sandbox Exception (the one carve-out to R3)
The learner **runs** a provided setup script (`datasets/*.sql`) on Day 3 without
understanding its contents. Running a file someone else wrote is not the same as
writing a query. The DDL inside it is taught properly in Phase 7 (Days 38–45),
at which point the learner re-reads that file as a comprehension exercise.
This exception applies to **nothing else**.

### R5. Layering / Accretion
Each day adds exactly one new idea, then immediately combines it with everything
already learned. The practice set of every day is split:

- **Section A — New concept only** (drill the thing just learned)
- **Section B — Combination** (new concept + at least two previous concepts)
- **Section C — Recall** (problems that use *only* older concepts, to fight forgetting)
- **Section D — Challenge** (one or two hard problems; stretch, not required)

No day may skip Sections A, B, or C.

### R6. Spaced repetition is mandatory
Section C of any day pulls from days roughly 1, 3, 7, and 15 days back. Every
5th day is a **Checkpoint Day**: no new concepts, only mixed practice across the
whole phase, plus a self-assessment score.

### R7. Examples before rules
Every concept is introduced as: **example → what happened → the rule → the edge
cases → the trap**. Never "here is the formal grammar, now memorize it".

### R8. Every example is runnable
Every example runs against the shared practice database (`shopdb`) that the
learner builds on Day 3. No abstract `foo`/`bar` tables. Where a query's exact
output matters for learning, expected output is shown; otherwise the expected
**row count and shape** is stated and the learner verifies by running it.

### R9. Every practice problem has a solution in the same file
Solutions live at the bottom of each day file under `## Solutions`, with a short
explanation of *why*, not just the answer. Many problems have more than one
correct answer; alternatives are shown where instructive.

### R10. Traps are taught explicitly
Each day ends with a **"Traps & Gotchas"** section. These are the things that
break in production and get asked in interviews: `NULL` semantics, integer
division, `COUNT(*)` vs `COUNT(col)`, `LEFT JOIN` + `WHERE` collapsing to an
inner join, timezone handling, index invalidation, lock escalation, and so on.

### R11. Interview framing from Day 1
Each day lists **"Interview angles"** — how this topic actually gets asked at
junior, mid, and senior level. By Day 90 the learner has seen every common
PostgreSQL interview question in context, not as a flashcard dump.

### R12. PostgreSQL-specific, not generic SQL
Where PostgreSQL differs from MySQL/SQL Server/Oracle, the difference is called
out. The learner should finish able to say "that's ANSI SQL" vs "that's a
Postgres extension" — a senior-level distinction.

### R13. One file = one day = one sitting
Each day file is self-contained: prerequisites, parts, practice, solutions,
checklist. A day is designed for **90–150 minutes** of focused work. Later,
heavier days say so explicitly in their header.

### R14. Consistent file anatomy
Every day file has exactly these sections, in this order:

```
# Day NN — Title
> Phase | Level | Time | Prerequisites | New concepts introduced
## Why this matters
## Part 1 ... Part N        (concept + examples + "Try it")
## Traps & Gotchas
## Interview angles
## Practice
   ### Section A — Drill
   ### Section B — Combination
   ### Section C — Recall
   ### Section D — Challenge
## Solutions
## Day NN Checklist
## What's next
```

### R15. Reality over optimism
If something is genuinely hard (recursive CTEs, MVCC, query planning), the file
says so and slows down. No pretending that hard things are easy.

---

## Part 2 — Rules for the Learner (how you work through it)

### L1. One file per day. Do not batch.
The spacing is the point. Reading four days in one sitting produces recognition,
not recall. Recognition fails in interviews.

### L2. Type every query. Never copy-paste.
Typing builds syntax muscle memory and forces you to read the query. Copy-paste
builds nothing. This is non-negotiable.

### L3. Predict before you run.
Before pressing Enter, say out loud (or write down) how many rows you expect and
what the columns will be. Then run it. **Being wrong is the learning event.**

### L4. Attempt every practice problem before reading its solution.
A 20-minute genuine struggle teaches more than 20 solutions read. If you are
stuck for more than 20 minutes, read the solution, then close the file, wait an
hour, and write the query again from scratch.

### L5. Break things on purpose.
Every day, run at least one query you *expect* to fail. Read the error message.
PostgreSQL error messages are excellent and reading them fluently is a
senior-level skill that only comes from exposure.

### L6. Keep a `mistakes.md` file.
Every time you get something wrong, write one line: what you thought, what was
true. Re-read this file at every Checkpoint Day. This file becomes your personal
interview-prep document — more valuable than any of the 90 day files.

### L7. Do not skip Checkpoint Days.
If you score below 70% on a Checkpoint, repeat the phase's practice sections
before moving on. Moving forward on a shaky foundation is how people spend two
years writing bad SQL.

### L8. Never `DROP` the practice database out of frustration.
`datasets/99_reset.sql` restores everything to a clean state. Use it freely —
breaking data is *encouraged*, that's what a practice database is for.

### L9. Read the manual entry for one thing per day.
`https://www.postgresql.org/docs/current/` — one page per day. Being comfortable
in the official docs is what separates engineers who can answer new questions
from engineers who can only answer memorized ones.

### L10. By Phase 9, use `EXPLAIN` on everything.
Once you learn to read a query plan, run `EXPLAIN` on every query you write for
the rest of the program. Intuition about performance is built by repetition.

---

## Part 3 — Conventions used in every file

| Marker | Meaning |
|---|---|
| ▶ **Try it** | Run this yourself right now before reading on |
| ⚠️ **Trap** | A common, costly mistake |
| 💡 **Note** | Useful aside, safe to skim on first pass |
| 🎯 **Interview** | This exact thing gets asked in interviews |
| 🐘 **Postgres-only** | Not standard SQL; won't work in MySQL/Oracle |
| 🔁 **Recall** | Uses a concept from an earlier day |

**SQL style used throughout (and expected in your answers):**
- Keywords UPPERCASE (`SELECT`, `FROM`), identifiers lowercase (`customer_id`)
- `snake_case` for all table and column names
- Tables named in the **plural** (`customers`, `orders`)
- Primary key named `<singular_table>_id` (`customer_id`)
- One clause per line; indent continuations
- Always terminate statements with `;`

---

## Part 4 — Definition of Done

You have completed this program when you can, without references:

1. Model a non-trivial domain into a normalized schema, and justify each
   denormalization you chose to make.
2. Write any query in the practice set of Days 79–90 in under 10 minutes.
3. Read an `EXPLAIN (ANALYZE, BUFFERS)` plan and name the bottleneck.
4. Explain MVCC, bloat, and autovacuum to a colleague, from memory.
5. Choose an isolation level for a given workload and defend the choice.
6. Design a partitioning + indexing strategy for a 500M-row table.
7. Debug a production incident: lock contention, runaway query, replication lag.
8. Pass a 60-minute senior-level PostgreSQL interview without hesitation.

---

*Read this file again on Day 1, Day 30, Day 60, and Day 90. It reads differently
each time.*
