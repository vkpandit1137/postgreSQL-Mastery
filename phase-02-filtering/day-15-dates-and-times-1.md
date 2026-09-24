# Day 15 — Dates and Times, Part 1

> **Phase** 2 · Filtering & Expressions
> **Level** Absolute Beginner
> **Time** 110–140 minutes
> **Prerequisites** Days 01–14
> **New concepts** `date` · `time` · `timestamp` · `timestamptz` · date literals · `current_date`/`now()`/`current_timestamp` · `EXTRACT` · `date_part` · `date_trunc` · day-of-week numbering · date subtraction · why `timestamptz` is the default answer

---

## Why this matters

Dates are where correct-looking code goes wrong. Every reporting bug you will
ever debug is at least 30% likely to be a date bug: the wrong month boundary,
a missing last day, a timezone shift that moved a transaction into the previous
quarter.

Today is the mechanics — types, extraction, truncation. Tomorrow is arithmetic
and time zones. Both days are worth taking slowly.

> 💡 **A note on this practice database.** The seeded orders run from
> **2024-01-08 to 2025-07-07**. Queries in this program therefore use explicit
> date literals rather than `now() - interval '30 days'`, so the results are the
> same for you as for everyone else. In production you'd use relative dates
> constantly; here they'd return nothing.

---

## Part 1 — The four types

| Type | Stores | Example | Bytes |
|---|---|---|---|
| `date` | a calendar day | `2024-03-15` | 4 |
| `time` | a time of day, no date | `14:30:00` | 8 |
| `timestamp` | date + time, **no timezone** | `2024-03-15 14:30:00` | 8 |
| `timestamptz` | date + time, **timezone-aware** | `2024-03-15 14:30:00+00` | 8 |

In `shopdb`:

- `orders.order_date`, `customers.signup_date`, `products.added_on` → `date`
- `payments.paid_at`, `reviews.created_at` → `timestamptz`

That split is deliberate and realistic. A business date ("the order was placed
on the 8th") is a `date`. A machine event ("the payment was captured at this
instant") is a `timestamptz`.

### `timestamp` vs `timestamptz` — the one that matters

The names are misleading, so read this twice:

- **`timestamp`** (a.k.a. `timestamp without time zone`) stores exactly the
  digits you gave it, with **no** timezone information. `2024-03-15 14:30` —
  but 14:30 *where*? The database does not know and cannot tell you.
- **`timestamptz`** (`timestamp with time zone`) stores an **absolute instant**.
  On input it converts from your session's timezone to UTC; on output it
  converts back. It does **not** store a timezone — it stores a point in time.

```sql
SHOW timezone;
SELECT timestamptz '2024-03-15 14:30:00+02' AS as_stored;
```

Set your session to a different zone and the same instant displays differently:

```sql
SET timezone = 'UTC';
SELECT timestamptz '2024-03-15 14:30:00+02';   -- 2024-03-15 12:30:00+00

SET timezone = 'Asia/Kolkata';
SELECT timestamptz '2024-03-15 14:30:00+02';   -- 2024-03-15 18:00:00+05:30

RESET timezone;
```

Same instant. Three renderings. That is exactly what you want for an event log.

> **Rule: use `timestamptz` for anything that records when something happened.**
> Use `timestamp` only for a wall-clock time that is genuinely location-
> independent — a recurring "09:00 local" alarm, say. That case is rarer than
> people think.

🎯 **Interview** — "`timestamp` vs `timestamptz`?" The answer that gets full
marks: `timestamptz` stores an absolute instant (internally UTC) and converts on
input and output using the session timezone; `timestamp` stores naive digits
with no zone and no conversion. Both occupy 8 bytes, so there is no storage
argument for the wrong one. Default to `timestamptz`.

⚠️ Note the asymmetry in the names: `timestamptz` does *not* store a timezone,
despite being called "with time zone". It stores an instant. The name is a
historical wart in the SQL standard.

---

## Part 2 — Writing date literals

```sql
SELECT DATE '2024-03-15',
       TIME '14:30:00',
       TIMESTAMP '2024-03-15 14:30:00',
       TIMESTAMPTZ '2024-03-15 14:30:00+00';
```

Or with a cast — identical:

```sql
SELECT '2024-03-15'::date, '2024-03-15 14:30:00'::timestamptz;
```

Or bare, when the context makes the type clear:

```sql
SELECT * FROM orders WHERE order_date >= '2025-01-01';
```

### ⚠️ Use ISO 8601 — `YYYY-MM-DD` — always

```sql
SELECT '03/04/2024'::date;
```

Is that 3 April or 4 March? It depends on the server's `DateStyle` setting:

```sql
SHOW DateStyle;      -- typically 'ISO, MDY' or 'ISO, DMY'
```

Under `MDY` it is 4 March; under `DMY` it is 3 April. The same SQL file gives
different answers on different servers, silently.

`YYYY-MM-DD` is unambiguous under every setting, sorts correctly as text, and is
the international standard. There is no situation in which another format is
better.

### Special values

```sql
SELECT DATE 'today', DATE 'tomorrow', DATE 'yesterday';
SELECT TIMESTAMPTZ 'infinity', TIMESTAMPTZ '-infinity';
```

`infinity` is genuinely useful: an "end date" of `infinity` for an open-ended
record means every range comparison works without special-casing `NULL`. You'll
use it with range types on Day 70.

---

## Part 3 — "Now"

```sql
SELECT current_date,
       current_time,
       current_timestamp,
       now(),
       localtimestamp;
```

| Function | Returns |
|---|---|
| `current_date` | `date` |
| `current_time` | `timetz` |
| `current_timestamp` | `timestamptz` |
| `now()` | `timestamptz` — same as `current_timestamp` |
| `localtimestamp` | `timestamp` (no zone) |

⚠️ **Trap — `now()` is the transaction start time, not the current instant.**

```sql
BEGIN;
SELECT now();
-- wait ten seconds
SELECT now();       -- identical
COMMIT;
```

Both calls return the same value. `now()` is `STABLE`: it is fixed for the
duration of a transaction, so that every row inserted by one statement gets a
consistent timestamp. That is almost always what you want.

When you genuinely need the wall clock:

```sql
SELECT clock_timestamp();     -- actual current instant, changes within a txn
SELECT statement_timestamp(); -- start of the current statement
```

`clock_timestamp()` is what you use to time something inside a loop.

🎯 **Interview** — "Why do all the rows inserted by a long-running statement
have the same `created_at`?" → `now()`/`current_timestamp` is stable within a
transaction. Use `clock_timestamp()` if you need real elapsed time. This is
asked more often than you'd expect, because it confuses people debugging batch
jobs.

---

## Part 4 — `EXTRACT`: pulling a field out

```sql
SELECT EXTRACT(YEAR   FROM DATE '2024-03-15') AS yr,
       EXTRACT(MONTH  FROM DATE '2024-03-15') AS mo,
       EXTRACT(DAY    FROM DATE '2024-03-15') AS dy,
       EXTRACT(DOW    FROM DATE '2024-03-15') AS day_of_week,
       EXTRACT(DOY    FROM DATE '2024-03-15') AS day_of_year,
       EXTRACT(QUARTER FROM DATE '2024-03-15') AS qtr,
       EXTRACT(WEEK   FROM DATE '2024-03-15') AS iso_week;
```

```
  yr  | mo | dy | day_of_week | day_of_year | qtr | iso_week
------+----+----+-------------+-------------+-----+----------
 2024 |  3 | 15 |           5 |          75 |   1 |       11
```

The fields you'll use:

| Field | Meaning | Range |
|---|---|---|
| `YEAR` `MONTH` `DAY` | the obvious | |
| `HOUR` `MINUTE` `SECOND` | the obvious | |
| `DOW` | day of week | **0 = Sunday** … 6 = Saturday |
| `ISODOW` | day of week, ISO | **1 = Monday** … 7 = Sunday |
| `DOY` | day of year | 1–366 |
| `QUARTER` | quarter | 1–4 |
| `WEEK` | ISO week number | 1–53 |
| `EPOCH` | seconds since 1970-01-01 UTC | |

⚠️ **Trap — `DOW` starts at Sunday=0; `ISODOW` starts at Monday=1.** Picking
the wrong one shifts your entire "weekend orders" report by a day. If you mean
Monday-first (as most of the world does for business weeks), use `ISODOW`.

```sql
SELECT order_id, order_date,
       EXTRACT(DOW    FROM order_date) AS dow,
       EXTRACT(ISODOW FROM order_date) AS isodow
FROM   orders
LIMIT  5;
```

`date_part()` is the function form and is identical:

```sql
SELECT date_part('year', order_date) FROM orders LIMIT 1;
SELECT EXTRACT(YEAR FROM order_date) FROM orders LIMIT 1;
```

💡 `EXTRACT` returns `numeric` in PostgreSQL 14+ (it was `double precision`
before). Cast to `int` when you want a tidy integer:
`EXTRACT(YEAR FROM order_date)::int`.

### Real uses

```sql
-- orders placed in 2025
SELECT order_id, order_date FROM orders
WHERE  EXTRACT(YEAR FROM order_date) = 2025;

-- orders placed in December, any year
SELECT order_id, order_date FROM orders
WHERE  EXTRACT(MONTH FROM order_date) = 12;

-- orders placed at a weekend
SELECT order_id, order_date FROM orders
WHERE  EXTRACT(ISODOW FROM order_date) IN (6, 7);
```

⚠️ **Performance note, which you now expect:** `WHERE EXTRACT(YEAR FROM
order_date) = 2025` wraps the column in a function, so it is **non-sargable** —
no plain B-tree index on `order_date` can be used. The indexable form is a
half-open range:

```sql
WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2026-01-01'
```

Same rows, and an index scan instead of a full scan. **Prefer ranges over
`EXTRACT` in `WHERE`.** Use `EXTRACT` in the `SELECT` list, where it costs
nothing.

---

## Part 5 — `date_trunc`: rounding down to a unit

`EXTRACT` gives you one field as a number. `date_trunc` gives you a **date or
timestamp** with everything below a chosen unit set to zero.

```sql
SELECT date_trunc('month', TIMESTAMPTZ '2024-03-15 14:37:29');
```

```
      date_trunc
------------------------
 2024-03-01 00:00:00+00
```

Units: `microseconds`, `milliseconds`, `second`, `minute`, `hour`, `day`,
`week`, `month`, `quarter`, `year`, `decade`, `century`, `millennium`.

```sql
SELECT date_trunc('day',     TIMESTAMPTZ '2024-03-15 14:37:29'),  -- 2024-03-15 00:00
       date_trunc('hour',    TIMESTAMPTZ '2024-03-15 14:37:29'),  -- 2024-03-15 14:00
       date_trunc('week',    TIMESTAMPTZ '2024-03-15 14:37:29'),  -- 2024-03-11 (Monday)
       date_trunc('quarter', TIMESTAMPTZ '2024-03-15 14:37:29'),  -- 2024-01-01
       date_trunc('year',    TIMESTAMPTZ '2024-03-15 14:37:29');  -- 2024-01-01
```

💡 `date_trunc('week', ...)` truncates to **Monday**, following ISO 8601. If
your business week starts on Sunday you must adjust it yourself.

### Why `date_trunc` matters more than `EXTRACT`

Grouping by month is *the* most common reporting operation, and `date_trunc` is
how you do it:

```sql
SELECT order_id, order_date, date_trunc('month', order_date) AS month
FROM   orders
ORDER  BY order_date
LIMIT  8;
```

```
 order_id | order_date |        month
----------+------------+---------------------
        1 | 2024-01-08 | 2024-01-01 00:00:00
        2 | 2024-01-12 | 2024-01-01 00:00:00
        3 | 2024-01-19 | 2024-01-01 00:00:00
        4 | 2024-01-25 | 2024-01-01 00:00:00
        5 | 2024-02-02 | 2024-02-01 00:00:00
```

Every January order collapses to the same value, so they can be grouped
together — which is Day 20.

**`date_trunc` beats `EXTRACT` for grouping** because it keeps the year. Group
by `EXTRACT(MONTH ...)` and January 2024 merges with January 2025, which is
almost never what you want — and is a reporting bug that survives testing
because it only appears once you have two years of data.

```sql
-- WRONG for multi-year data
GROUP BY EXTRACT(MONTH FROM order_date)          -- Jan 2024 + Jan 2025 merged

-- RIGHT
GROUP BY date_trunc('month', order_date)         -- distinct months
```

Note `date_trunc` on a `date` returns a `timestamp`, so cast if you want a date:

```sql
SELECT date_trunc('month', order_date)::date AS month FROM orders;
```

---

## Part 6 — Date arithmetic, lightly

Full treatment is tomorrow. Two things you need today.

### Subtracting dates gives an integer number of days

```sql
SELECT DATE '2024-03-15' - DATE '2024-01-01';   -- 74
```

An `integer`, not an interval. Useful immediately:

```sql
SELECT order_id, order_date,
       DATE '2025-07-07' - order_date AS days_before_last_order
FROM   orders
ORDER  BY order_date
LIMIT  5;
```

```sql
SELECT first_name, birth_date,
       (DATE '2025-01-01' - birth_date) / 365 AS approx_age
FROM   customers
WHERE  birth_date IS NOT NULL;
```

That `/ 365` is integer division — deliberately, since we want whole years —
but it is also *wrong* about leap years. `age()` does it properly, tomorrow.

### Subtracting timestamps gives an `interval`

```sql
SELECT TIMESTAMPTZ '2024-03-15 14:30' - TIMESTAMPTZ '2024-03-15 09:00';
```

```
 ?column?
----------
 05:30:00
```

An `interval`, not a number. Tomorrow's topic.

### Adding days to a date

```sql
SELECT DATE '2024-03-15' + 30;      -- 2024-04-14
SELECT DATE '2024-03-15' - 30;      -- 2024-02-14
```

Adding a plain integer to a `date` adds **days**. (Adding an integer to a
`timestamp` is an error — you need an interval. Tomorrow.)

---

## Part 7 — Putting it together

```sql
SELECT order_id,
       order_date,
       EXTRACT(YEAR    FROM order_date)::int AS yr,
       EXTRACT(QUARTER FROM order_date)::int AS qtr,
       EXTRACT(ISODOW  FROM order_date)::int AS weekday,
       date_trunc('month', order_date)::date AS month_start,
       status
FROM   orders
WHERE  order_date >= DATE '2024-10-01'
  AND  order_date <  DATE '2025-01-01'
  AND  status = 'delivered'
ORDER  BY order_date;
```

Note the `WHERE` uses a **half-open range**, not `EXTRACT` — indexable, and
correct at both boundaries. The `SELECT` list uses `EXTRACT` freely, where it
costs nothing.

---

## Traps & Gotchas

| # | Trap | What happens |
|---|---|---|
| 1 | Using `timestamp` where you meant `timestamptz` | No zone info; comparisons across regions are meaningless |
| 2 | `'03/04/2024'` | Ambiguous; depends on `DateStyle` |
| 3 | `EXTRACT(DOW ...)` vs `ISODOW` | Sunday=0 vs Monday=1 — reports off by a day |
| 4 | `GROUP BY EXTRACT(MONTH ...)` on multi-year data | January 2024 and 2025 merged |
| 5 | `EXTRACT` in `WHERE` | Non-sargable; no index |
| 6 | `BETWEEN` on a `timestamptz` | Loses the last day (Day 10) |
| 7 | Expecting `now()` to change inside a transaction | It doesn't — use `clock_timestamp()` |
| 8 | `date_trunc('week', ...)` assuming Sunday start | It's Monday (ISO) |
| 9 | `date - date` gives an integer, `ts - ts` gives an interval | Different types, different arithmetic |
| 10 | `(d2 - d1) / 365` for age | Ignores leap years — use `age()` |

---

## Interview angles

- **Junior** — "Orders placed in 2025." → Half-open range, not `EXTRACT`.
- **Junior** — "Get the month from a date." → `EXTRACT(MONTH FROM d)` or
  `date_trunc('month', d)` — and say when each is right.
- **Mid** — "`timestamp` vs `timestamptz`?" → Instant vs naive digits; default
  to `timestamptz`.
- **Mid** — "Why is `WHERE EXTRACT(YEAR FROM created_at) = 2024` slow?" →
  Non-sargable. Rewrite as a range, or add an expression index.
- **Mid** — "Group revenue by month across two years." → `date_trunc('month',
  d)`, never `EXTRACT(MONTH ...)`.
- **Senior** — "Design a schema for a global events table." → `timestamptz`
  for the instant; if the *local* wall-clock time matters to the business (a
  shop's opening hours, a scheduled meeting), store the IANA timezone name
  alongside it in a separate column, because an offset alone cannot survive a
  DST rule change. Never store an offset as the only zone information.
- **Senior** — "What breaks when a country changes its DST rules?" → Stored
  `timestamptz` values are fine (they're absolute). Future *local* times
  computed and stored as absolute instants become wrong. This is why
  recurring appointments store a local time plus a zone name, not a UTC
  instant. Day 16.

---

## Practice

> Available: everything from Days 1–14, plus today's date functions.
> Not yet: `interval` arithmetic, `age()`, `to_char`, `AT TIME ZONE` (Day 16);
> `CASE`/`COALESCE` (Day 17).

### Section A — Drill (new concept only)

1. Today's date.
2. The current timestamp with timezone.
3. `now()` and `clock_timestamp()` in one row.
4. The date literal for 15 March 2024, three different ways.
5. `pg_typeof` of `DATE '2024-01-01'`, `TIMESTAMP '2024-01-01 00:00'` and
   `TIMESTAMPTZ '2024-01-01 00:00+00'`.
6. The year, month and day of `DATE '2024-03-15'`.
7. The quarter and ISO week of `DATE '2024-03-15'`.
8. `DOW` and `ISODOW` of `DATE '2024-03-15'`. Which day of the week is it?
9. The day of year of `DATE '2024-12-31'` and of `DATE '2023-12-31'`. Why do
   they differ?
10. The hour and minute of `TIMESTAMPTZ '2024-03-15 14:37:29+00'`.
11. The epoch seconds of `TIMESTAMPTZ '2024-01-01 00:00:00+00'`.
12. `date_trunc` to month, quarter and year of `DATE '2024-03-15'`.
13. `date_trunc` to day, hour and minute of
    `TIMESTAMPTZ '2024-03-15 14:37:29+00'`.
14. `date_trunc('week', DATE '2024-03-15')` — which day does it land on?
15. `DATE '2024-03-15' - DATE '2024-01-01'`.
16. `DATE '2024-03-15' + 30` and `- 30`.
17. `TIMESTAMPTZ '2024-03-15 14:30+00' - TIMESTAMPTZ '2024-03-15 09:00+00'`.
18. `SHOW timezone;` and `SHOW DateStyle;`.
19. Every order's `order_date` and its year.
20. Every order's `order_date` and its month, as a truncated date.
21. Every order's `order_date` and its ISO weekday number.
22. Every payment's `paid_at` and its hour.
23. Every customer's `signup_date` and its quarter.
24. Every review's `created_at` truncated to the day.
25. Every product's `added_on` and its year.

### Section B — Combination (with Days 01–14)

26. Orders placed in 2025, using a half-open range.
27. Orders placed in 2025, using `EXTRACT`. Which version would use an index?
28. Orders placed in the fourth quarter of 2024, using a range.
29. Orders placed at a weekend (`ISODOW` 6 or 7).
30. Orders placed on a Monday.
31. Customers who signed up in 2024, using a range.
32. Customers who signed up in the first half of any year (`MONTH` ≤ 6).
33. Payments made in December 2024, using a half-open range.
34. Payments made between 09:00 and 17:00, any day (`HOUR` between 9 and 16).
35. Reviews created in 2024, using a range.
36. Products added before 2023, showing `added_on` and its year.
37. Every order's id, date, month start and status, for delivered orders in the
    second half of 2024, oldest first.
38. Every customer's name, `signup_date`, and how many days before 2025-01-01
    they signed up.
39. Every customer's approximate age at 2025-01-01, in whole years, excluding
    those with no birth date.
40. Every order's id and how many days it was before the most recent order
    (2025-07-07).
41. Distinct years present in `orders.order_date`.
42. Distinct month-starts present in `orders.order_date`, sorted.
43. Distinct ISO weekdays on which orders were placed, sorted.
44. The 5 earliest orders.
45. The 5 most recent payments.
46. Orders placed in January of any year.
47. Payments where the hour is before 06:00.
48. The order with the largest gap in days from 2024-01-01.
49. Every employee's `hire_date`, its year, and their years of service at
    2025-01-01 (integer division by 365).
50. Reviews created in the same month as `2024-04-01`, using `date_trunc`.

### Section C — Recall (Days 01–14)

51. Every product's margin percentage to 1 decimal, best first.
52. `10 / 3` as a decimal, two ways.
53. `round(2.5::numeric)` and `round(2.5::float8)`.
54. Every customer's email domain.
55. `concat_ws('-', 'a', NULL, 'b')`.
56. Customers with no loyalty tier.
57. `supplier_id NOT IN (1, 2)` — why isn't it 16 rows?
58. Products whose name contains `laptop`, any case.
59. The most expensive in-stock product per category.
60. Reset the database and verify the counts.

### Section D — Challenge

61. Show that `WHERE EXTRACT(YEAR FROM order_date) = 2025` and
    `WHERE order_date >= '2025-01-01' AND order_date < '2026-01-01'` return the
    same rows, then explain which you would ship and why.
62. Demonstrate that `now()` is stable within a transaction and
    `clock_timestamp()` is not.
63. Explain, with a query over `orders`, why grouping by
    `EXTRACT(MONTH FROM order_date)` would be wrong for this dataset.
    (You cannot `GROUP BY` yet — show the collision using `DISTINCT`.)
64. `date_trunc('week', ...)` starts on Monday. Write an expression that
    truncates to a **Sunday**-starting week instead.
65. Work out the ISO week number of `2025-01-01` and of `2024-12-30`. Explain
    the result. (This is a classic off-by-one-year bug.)
66. Find every order placed on the last day of a month, without hard-coding any
    dates.
67. Find every order placed in the first seven days of a month.
68. `payments.paid_at` is `timestamptz`. Write a query counting payments on
    2024-12-31 that is correct regardless of the session timezone, and explain
    what could go wrong if it weren't.
69. Using `EXTRACT(EPOCH ...)`, compute the number of seconds between
    `2024-01-01 00:00:00+00` and every payment's `paid_at`, for December 2024
    payments only.
70. Design question: an events table records when a user clicked something.
    Someone proposes storing it as `timestamp` plus a separate `timezone` text
    column. Argue for or against, and say what you would store instead.

---

## Solutions

### Section A

**1.** `SELECT current_date;`
**2.** `SELECT current_timestamp;` (or `now()`)
**3.** `SELECT now(), clock_timestamp();`
**4.** `DATE '2024-03-15'`, `'2024-03-15'::date`, `CAST('2024-03-15' AS date)`
**5.** `date`, `timestamp without time zone`, `timestamp with time zone`
**6.** `SELECT EXTRACT(YEAR FROM DATE '2024-03-15'), EXTRACT(MONTH FROM DATE '2024-03-15'), EXTRACT(DAY FROM DATE '2024-03-15');` → 2024, 3, 15
**7.** → quarter 1, ISO week 11
**8.** → `DOW` 5, `ISODOW` 5. Both 5 here — it is a **Friday**. (They only
differ for Sunday, where `DOW` is 0 and `ISODOW` is 7.) That coincidence is
exactly why the bug survives testing: pick a Friday to test and the two agree.
**9.** `2024-12-31` → 366 (leap year); `2023-12-31` → 365.
**10.** `SELECT EXTRACT(HOUR FROM TIMESTAMPTZ '2024-03-15 14:37:29+00'), EXTRACT(MINUTE FROM ...);` → 14, 37
(assuming your session timezone is UTC — otherwise the hour shifts, which is the
point of `timestamptz`).
**11.** `SELECT EXTRACT(EPOCH FROM TIMESTAMPTZ '2024-01-01 00:00:00+00');`
→ 1704067200
**12.** → `2024-03-01`, `2024-01-01`, `2024-01-01`
**13.** → `2024-03-15 00:00`, `2024-03-15 14:00`, `2024-03-15 14:37`
**14.** `2024-03-11` — a **Monday**.
**15.** 74
**16.** `2024-04-14`, `2024-02-14`
**17.** `05:30:00` — an `interval`.
**18.** `SHOW timezone; SHOW DateStyle;`
**19.** `SELECT order_date, EXTRACT(YEAR FROM order_date)::int AS yr FROM orders;`
**20.** `SELECT order_date, date_trunc('month', order_date)::date AS month FROM orders;`
**21.** `SELECT order_date, EXTRACT(ISODOW FROM order_date)::int AS weekday FROM orders;`
**22.** `SELECT paid_at, EXTRACT(HOUR FROM paid_at)::int AS hr FROM payments;`
**23.** `SELECT signup_date, EXTRACT(QUARTER FROM signup_date)::int AS qtr FROM customers;`
**24.** `SELECT created_at, date_trunc('day', created_at) FROM reviews;`
**25.** `SELECT added_on, EXTRACT(YEAR FROM added_on)::int FROM products;`

### Section B

**26.** `WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2026-01-01';` → 8
**27.** `WHERE EXTRACT(YEAR FROM order_date) = 2025;` → same 8 rows. **The range
version can use an index**; the `EXTRACT` version cannot, because the column is
wrapped in a function.
**28.** `WHERE order_date >= DATE '2024-10-01' AND order_date < DATE '2025-01-01';`
**29.** `WHERE EXTRACT(ISODOW FROM order_date) IN (6, 7);`
**30.** `WHERE EXTRACT(ISODOW FROM order_date) = 1;`
**31.** `WHERE signup_date >= DATE '2024-01-01' AND signup_date < DATE '2025-01-01';` → 8
**32.** `WHERE EXTRACT(MONTH FROM signup_date) <= 6;`
**33.** `WHERE paid_at >= '2024-12-01' AND paid_at < '2025-01-01';`
**34.** `WHERE EXTRACT(HOUR FROM paid_at) BETWEEN 9 AND 16;`
**35.** `WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01';`
**36.** `SELECT product_name, added_on, EXTRACT(YEAR FROM added_on)::int FROM products WHERE added_on < DATE '2023-01-01';` → 3
**37.**
```sql
SELECT order_id, order_date, date_trunc('month', order_date)::date AS month, status
FROM   orders
WHERE  status = 'delivered'
  AND  order_date >= DATE '2024-07-01'
  AND  order_date <  DATE '2025-01-01'
ORDER  BY order_date;
```
**38.**
```sql
SELECT concat_ws(' ', first_name, last_name) AS name, signup_date,
       DATE '2025-01-01' - signup_date AS days_before
FROM   customers;
```
**39.**
```sql
SELECT first_name, birth_date,
       (DATE '2025-01-01' - birth_date) / 365 AS approx_age
FROM   customers WHERE birth_date IS NOT NULL;
```
**40.** `SELECT order_id, DATE '2025-07-07' - order_date AS days_ago FROM orders;`
**41.** `SELECT DISTINCT EXTRACT(YEAR FROM order_date)::int AS yr FROM orders ORDER BY yr;` → 2024, 2025
**42.** `SELECT DISTINCT date_trunc('month', order_date)::date AS month FROM orders ORDER BY month;` → 19 rows
**43.** `SELECT DISTINCT EXTRACT(ISODOW FROM order_date)::int AS d FROM orders ORDER BY d;`
**44.** `SELECT * FROM orders ORDER BY order_date LIMIT 5;`
**45.** `SELECT * FROM payments ORDER BY paid_at DESC LIMIT 5;`
**46.** `WHERE EXTRACT(MONTH FROM order_date) = 1;`
**47.** `WHERE EXTRACT(HOUR FROM paid_at) < 6;`
**48.** `SELECT order_id, order_date, order_date - DATE '2024-01-01' AS gap FROM orders ORDER BY gap DESC LIMIT 1;` → order 60.
**49.**
```sql
SELECT first_name, hire_date,
       EXTRACT(YEAR FROM hire_date)::int AS hire_year,
       (DATE '2025-01-01' - hire_date) / 365 AS years_service
FROM   employees ORDER BY years_service DESC;
```
**50.** `SELECT * FROM reviews WHERE date_trunc('month', created_at) = TIMESTAMPTZ '2024-04-01';`

### Section C

**51.** `SELECT product_name, round((price-cost)/price*100, 1) AS pct FROM products ORDER BY pct DESC;`
**52.** `10::numeric / 3` or `10.0 / 3`
**53.** `3` and `2`
**54.** `SELECT split_part(email, '@', 2) FROM customers;`
**55.** `a-b`
**56.** `WHERE loyalty_tier IS NULL;` → 4
**57.** 15, not 16 — `Webcam HD` has `supplier_id IS NULL`, so it satisfies
neither `IN` nor `NOT IN`.
**58.** `WHERE product_name ILIKE '%laptop%';`
**59.** `SELECT DISTINCT ON (category_id) ... ORDER BY category_id, price DESC;`
**60.** `\i 99_reset.sql`

### Section D

**61.**
```sql
SELECT count(*) FROM orders WHERE EXTRACT(YEAR FROM order_date) = 2025;   -- 8
SELECT count(*) FROM orders
WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2026-01-01'; -- 8
```
Ship the **range** version. Identical results, but the range is *sargable*: a
B-tree index on `order_date` can seek directly to the start of 2025 and stop at
the end. The `EXTRACT` version must compute the function for every row in the
table. On 60 rows it makes no measurable difference; on 60 million it is the
difference between 3 milliseconds and 30 seconds. Writing the indexable form by
default costs nothing.

**62.**
```sql
BEGIN;
SELECT now() AS a, clock_timestamp() AS b;
SELECT now() AS a, clock_timestamp() AS b;
COMMIT;
```
`now()` is identical across both statements; `clock_timestamp()` differs.
`now()` is `STABLE` — fixed at transaction start — which is what makes all rows
written by one transaction carry a consistent timestamp.

**63.**
```sql
SELECT DISTINCT EXTRACT(MONTH FROM order_date)::int AS month_only
FROM   orders ORDER BY month_only;                          -- 12 rows

SELECT DISTINCT date_trunc('month', order_date)::date AS month
FROM   orders ORDER BY month;                               -- 19 rows
```
Twelve versus nineteen. The dataset spans January 2024 to July 2025 — nineteen
distinct months — but `EXTRACT(MONTH ...)` knows only 1–12, so January 2024 and
January 2025 collapse into a single bucket. Any revenue report grouped that way
would add two different Januaries together and label the result "January".

The bug is invisible for the first twelve months of a system's life, which is
exactly why it reaches production.

**64.**
```sql
SELECT DATE '2024-03-15' AS d,
       date_trunc('week', DATE '2024-03-15')::date           AS monday_start,
       (date_trunc('week', DATE '2024-03-15' + 1) - 1)::date AS sunday_start;
```
Shift the date forward one day, truncate to the ISO (Monday) week, then shift
back one day. The general trick for an arbitrary week start is to add the offset
before truncating and subtract it after.

**65.**
```sql
SELECT EXTRACT(WEEK FROM DATE '2025-01-01') AS w1,
       EXTRACT(WEEK FROM DATE '2024-12-30') AS w2,
       EXTRACT(ISOYEAR FROM DATE '2024-12-30') AS isoyear;
```
`2025-01-01` is a Wednesday, in **ISO week 1** of 2025. `2024-12-30` is a
Monday — and it is also in **ISO week 1**, but of **ISO year 2025**, because the
ISO week containing the first Thursday of January belongs to that January.

So a report grouped by `EXTRACT(YEAR ...)` and `EXTRACT(WEEK ...)` will file
30 December 2024 under "2024, week 1" — twelve months away from where it
belongs. The correct pairing is always `ISOYEAR` with `WEEK`, never `YEAR` with
`WEEK`. This bug appears in real dashboards every single January.

**66.**
```sql
SELECT order_id, order_date
FROM   orders
WHERE  order_date + 1 = date_trunc('month', order_date + 1)::date;
```
"The next day is the first of a month" is true exactly on the last day of a
month, with no hard-coded dates and no leap-year special cases. (There is a
tidier form using `interval` arithmetic, tomorrow.)

**67.** `WHERE EXTRACT(DAY FROM order_date) <= 7;`

**68.**
```sql
SELECT count(*) FROM payments
WHERE  paid_at >= TIMESTAMPTZ '2024-12-31 00:00:00+00'
  AND  paid_at <  TIMESTAMPTZ '2025-01-01 00:00:00+00';
```
The explicit `+00` offsets pin the boundaries to UTC instants regardless of the
session timezone. Without them — `paid_at >= '2024-12-31'` — the bare literal is
interpreted in the **session's** timezone, so the same query counts a different
set of rows for a user in Tokyo than for one in São Paulo. Reports that
"disagree between offices" are almost always this.

The deeper design question is *whose* 31 December you mean: the company's
reporting timezone, or the customer's local one. Decide it explicitly, write it
down, and apply it consistently — the database cannot guess.

**69.**
```sql
SELECT payment_id, paid_at,
       EXTRACT(EPOCH FROM (paid_at - TIMESTAMPTZ '2024-01-01 00:00:00+00'))::bigint
         AS seconds_since_start
FROM   payments
WHERE  paid_at >= '2024-12-01' AND paid_at < '2025-01-01'
ORDER  BY paid_at;
```
`EXTRACT(EPOCH FROM interval)` converts an interval to total seconds — the
standard way to get a numeric duration you can do arithmetic on.

**70.** **Against the proposal as stated, but the instinct behind it is right.**

`timestamp` + a timezone text column is strictly worse than `timestamptz` for an
*event log*: every comparison, sort and range filter now requires converting
each row individually, no index helps, and two events in different zones cannot
be ordered without a function call. For "when did this happen", `timestamptz`
alone is correct — it is an absolute instant, and rendering it in any zone is a
display concern.

**What I would store:**

```sql
occurred_at  timestamptz NOT NULL      -- the instant. Always.
```

…and, *if and only if* the local wall-clock context is part of the business
meaning, an additional column:

```sql
occurred_tz  text                      -- IANA name, e.g. 'Europe/Berlin'
```

The distinction that makes this a senior-level answer: **an offset is not a
timezone.** `+02:00` tells you nothing about what the offset will be next
winter. If you need to know "what local time was it for that user", or to
schedule something in the future at a local time, you need the IANA zone
*name*, because DST rules change by legislation and your stored offset becomes
wrong retroactively.

So: `timestamptz` for what happened; `timestamptz` **plus** an IANA zone name
when local context matters; and for *future* recurring events, store the local
time and the zone name and compute the instant at read time — because a meeting
at "09:00 Berlin time" must stay at 09:00 even if Germany abolishes DST.

---

## Day 15 Checklist

- [ ] I can name the four date/time types and what each stores
- [ ] **I know `timestamptz` stores an instant, not a timezone, and it is the
      default choice**
- [ ] I write date literals only as `YYYY-MM-DD`
- [ ] I know `now()` is fixed within a transaction and `clock_timestamp()` isn't
- [ ] I can use `EXTRACT` for year, month, day, quarter, week, epoch
- [ ] **I know `DOW` is Sunday-0 and `ISODOW` is Monday-1**
- [ ] I can use `date_trunc` and I know it starts weeks on Monday
- [ ] **I group by `date_trunc('month', ...)`, never `EXTRACT(MONTH ...)`**
- [ ] I know `EXTRACT` in `WHERE` is non-sargable, and I use ranges instead
- [ ] I know `date - date` gives an integer and `ts - ts` gives an interval
- [ ] I know `ISOYEAR` must be paired with `WEEK`, never `YEAR`

---

## What's next

**Day 16 — Dates and times, part 2.** The `interval` type and date arithmetic
done properly, `age()`, formatting with `to_char` and parsing with `to_date`,
and the full timezone story: `AT TIME ZONE`, DST transitions, and how to store
time so that it survives a change in the law.
