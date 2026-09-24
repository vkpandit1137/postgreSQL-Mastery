# Day 16 — Dates and Times, Part 2: Intervals, Formatting & Time Zones

> **Phase** 2 · Filtering & Expressions
> **Level** Absolute Beginner
> **Time** 120–150 minutes
> **Prerequisites** Days 01–15
> **New concepts** `interval` · interval arithmetic · `age()` · `justify_interval` · `to_char` for dates · `to_date`/`to_timestamp` · `make_date`/`make_interval` · `AT TIME ZONE` · DST · `overlaps` · month-end arithmetic pitfalls

---

## Why this matters

Yesterday you could read dates. Today you can do arithmetic with them — "thirty
days from now", "how old is this customer", "the last day of the month" — and
you learn the two things that make date arithmetic genuinely hard:

1. **Intervals are not durations.** `interval '1 month'` has no fixed length.
   Adding it to 31 January does not give 31 February, and adding it to
   28 February does not undo adding it to 31 January.
2. **Time zones are not offsets.** `+02:00` is a fact about one instant;
   `Europe/Berlin` is a rule that changes twice a year and occasionally by act
   of parliament.

Get these two right and you will avoid most date bugs for the rest of your
career.

---

## Part 1 — The `interval` type

An `interval` is a length of time.

```sql
SELECT INTERVAL '1 day',
       INTERVAL '3 hours',
       INTERVAL '2 weeks',
       INTERVAL '1 year 2 months',
       INTERVAL '1 day 03:30:00';
```

```
 interval | interval | interval |    interval    |    interval
----------+----------+----------+----------------+-----------------
 1 day    | 03:00:00 | 14 days  | 1 year 2 mons  | 1 day 03:30:00
```

Notice `2 weeks` became `14 days`. PostgreSQL stores an interval as **three
independent fields**:

```
months | days | microseconds
```

Weeks are converted to days; years to months. But months, days and
microseconds are kept **separate and are never converted into each other**,
because the conversion rate is not constant: a month is 28–31 days, and a day is
23–25 hours when DST is involved.

```sql
SELECT INTERVAL '1 month' = INTERVAL '30 days';   -- false
SELECT INTERVAL '1 day'   = INTERVAL '24 hours';  -- true (but see Part 6)
```

That first one surprises people. It is also the single most important fact about
intervals.

### Building intervals

```sql
SELECT INTERVAL '30 days',
       30 * INTERVAL '1 day',
       make_interval(days => 30),
       make_interval(years => 1, months => 6);
```

`make_interval` is the one to use when the number is a variable rather than a
literal — you cannot write `INTERVAL '$1 days'`, but you can write
`make_interval(days => $1)`.

---

## Part 2 — Date and interval arithmetic

```sql
SELECT DATE '2024-03-15' + INTERVAL '1 month',      -- 2024-04-15 00:00:00
       DATE '2024-03-15' - INTERVAL '10 days',      -- 2024-03-05 00:00:00
       TIMESTAMPTZ '2024-03-15 14:00+00' + INTERVAL '90 minutes';
```

⚠️ **Trap** — `date + interval` returns a **`timestamp`**, not a `date`:

```sql
SELECT pg_typeof(DATE '2024-03-15' + INTERVAL '1 month');
```

```
 timestamp without time zone
```

Cast back if you wanted a date:

```sql
SELECT (DATE '2024-03-15' + INTERVAL '1 month')::date;   -- 2024-04-15
```

Adding a plain **integer** to a date keeps it a date (Day 15):

```sql
SELECT pg_typeof(DATE '2024-03-15' + 30);   -- date
```

So `d + 30` and `d + interval '30 days'` give the same calendar day but
different types. Know which you want.

### The rules, in one table

| Operation | Result type |
|---|---|
| `date + integer` | `date` |
| `date - date` | `integer` (days) |
| `date + interval` | `timestamp` |
| `timestamp + interval` | `timestamp` |
| `timestamptz + interval` | `timestamptz` |
| `timestamp - timestamp` | `interval` |
| `interval + interval` | `interval` |
| `interval * number` | `interval` |
| `EXTRACT(EPOCH FROM interval)` | `numeric` seconds |

### ⚠️ Month arithmetic is not reversible

```sql
SELECT DATE '2024-01-31' + INTERVAL '1 month';   -- 2024-02-29
SELECT DATE '2024-02-29' - INTERVAL '1 month';   -- 2024-01-29
```

Add a month to 31 January and you get 29 February (clamped to the month's last
day). Subtract a month and you get 29 **January**, not 31. **`(d + 1 month) -
1 month` is not always `d`.**

```sql
SELECT DATE '2024-01-31' + INTERVAL '1 month' + INTERVAL '1 month';  -- 2024-03-29
SELECT DATE '2024-01-31' + INTERVAL '2 months';                      -- 2024-03-31
```

Adding one month twice is **not** the same as adding two months. This is not a
PostgreSQL quirk — it is inherent to calendars, and every date library on earth
has the same behaviour. It matters for subscription billing, where "monthly on
the 31st" has to be defined by a human before it can be implemented.

🎯 **Interview** — "A customer subscribes on 31 January. When is their next
billing date?" There is no technically correct answer; there is a *product*
decision (last day of month? the 28th? the 1st of the next month?) that must be
made and then implemented deliberately. Candidates who answer "29 February,
because that's what `+ 1 month` gives" have missed that the question is a
requirements question. Saying so is the senior answer.

### Month ends, done properly

```sql
-- first day of this month
SELECT date_trunc('month', DATE '2024-03-15')::date;              -- 2024-03-01

-- last day of this month
SELECT (date_trunc('month', DATE '2024-03-15')
        + INTERVAL '1 month - 1 day')::date;                      -- 2024-03-31

-- first day of next month
SELECT (date_trunc('month', DATE '2024-03-15')
        + INTERVAL '1 month')::date;                              -- 2024-04-01
```

That middle one is the idiom to memorise: truncate to the month, add a month,
subtract a day. It is correct for February, for leap years, for everything.

---

## Part 3 — `age()`

```sql
SELECT age(DATE '2025-01-01', DATE '1988-03-22');
```

```
        age
---------------------
 36 years 9 mons 10 days
```

`age(later, earlier)` gives a **calendar-aware** interval — real years, months
and days, accounting for varying month lengths and leap years.

With one argument it compares to today:

```sql
SELECT age(DATE '1988-03-22');    -- age as of current_date
```

### `age()` versus subtraction

```sql
SELECT DATE '2025-01-01' - DATE '1988-03-22'        AS days,
       age(DATE '2025-01-01', DATE '1988-03-22')    AS calendar_age;
```

```
 days  |     calendar_age
-------+-------------------------
 13434 | 36 years 9 mons 10 days
```

Subtraction gives an exact day count. `age()` gives the human answer. For
"how old is this person", you want `age()`:

```sql
SELECT first_name,
       birth_date,
       EXTRACT(YEAR FROM age(DATE '2025-01-01', birth_date))::int AS age_years
FROM   customers
WHERE  birth_date IS NOT NULL
ORDER  BY age_years DESC;
```

That is correct — unlike Day 15's `(d2 - d1) / 365`, which drifts by a day
every four years and eventually gets someone's age wrong on their birthday.

💡 `justify_interval`, `justify_days` and `justify_hours` normalise an interval
(30 days → 1 month, 24 hours → 1 day). Occasionally useful for display; never
for arithmetic, because the normalisation is exactly the assumption intervals
deliberately avoid.

---

## Part 4 — Formatting with `to_char`

```sql
SELECT to_char(DATE '2024-03-15', 'YYYY-MM-DD'),          -- 2024-03-15
       to_char(DATE '2024-03-15', 'DD/MM/YYYY'),          -- 15/03/2024
       to_char(DATE '2024-03-15', 'FMDay, DDth FMMonth YYYY'),
       to_char(DATE '2024-03-15', 'Mon YYYY'),            -- Mar 2024
       to_char(TIMESTAMPTZ '2024-03-15 14:30+00', 'HH24:MI:SS');
```

The patterns you'll actually use:

| Pattern | Gives |
|---|---|
| `YYYY` | 2024 |
| `MM` | 03 |
| `DD` | 15 |
| `Mon` / `Month` | Mar / March |
| `Dy` / `Day` | Fri / Friday |
| `HH24` | 14 (24-hour) |
| `HH12` / `AM` | 02 / PM |
| `MI` | minutes |
| `SS` | seconds |
| `Q` | quarter |
| `WW` / `IW` | week / ISO week |
| `TZ` / `OF` | timezone name / offset |
| `FM` | suppress padding |
| `th` | ordinal suffix (1st, 2nd) |

⚠️ **Trap** — `Month` and `Day` are **blank-padded to 9 characters**:

```sql
SELECT '[' || to_char(DATE '2024-03-15', 'Month') || ']';   -- [March    ]
SELECT '[' || to_char(DATE '2024-03-15', 'FMMonth') || ']'; -- [March]
```

`FM` is why your report has mysterious trailing spaces. Same lesson as `to_char`
for numbers on Day 14.

⚠️ **Trap** — `MM` is month, `MI` is minutes. `HH:MM` gives you the hour and the
*month*. It is a classic, and it produces output that looks almost right.

```sql
SELECT to_char(TIMESTAMPTZ '2024-03-15 14:30+00', 'HH24:MM');  -- 14:03  ← wrong
SELECT to_char(TIMESTAMPTZ '2024-03-15 14:30+00', 'HH24:MI');  -- 14:30  ← right
```

### Parsing: `to_date` and `to_timestamp`

```sql
SELECT to_date('15/03/2024', 'DD/MM/YYYY');            -- 2024-03-15
SELECT to_timestamp('15-03-2024 14:30', 'DD-MM-YYYY HH24:MI');
SELECT to_timestamp(1704067200);                       -- from epoch seconds
```

⚠️ `to_date` is **permissive to a fault**. It will happily accept nonsense:

```sql
SELECT to_date('2024-13-45', 'YYYY-MM-DD');   -- 2025-02-14  (!)
```

It rolled month 13 into the next year and day 45 into the next month, silently.
For validating user input, cast instead — `'2024-13-45'::date` raises an error,
which is what you want.

> **Rule: use `::date` for trusted ISO strings and for validation; use
> `to_date` only when you must parse a genuinely non-ISO format.**

### `make_date` and friends

```sql
SELECT make_date(2024, 3, 15),
       make_time(14, 30, 0),
       make_timestamptz(2024, 3, 15, 14, 30, 0, 'Europe/Berlin');
```

These take integers, so they're the right tool when year/month/day arrive as
separate values — no string building, and they validate properly:

```sql
SELECT make_date(2024, 13, 1);
```

```
ERROR:  date field value out of range
```

---

## Part 5 — Time zones

### `AT TIME ZONE` does two different things

This is the part everyone finds confusing, and the confusion is entirely
reasonable, because the operator is overloaded:

```sql
-- timestamptz  AT TIME ZONE zone  →  timestamp   ("render this instant there")
SELECT TIMESTAMPTZ '2024-03-15 14:30:00+00' AT TIME ZONE 'Asia/Kolkata';
-- 2024-03-15 20:00:00

-- timestamp    AT TIME ZONE zone  →  timestamptz ("these digits mean that zone")
SELECT TIMESTAMP '2024-03-15 14:30:00' AT TIME ZONE 'Asia/Kolkata';
-- 2024-03-15 09:00:00+00
```

| Input type | Meaning | Output type |
|---|---|---|
| `timestamptz` | "show me this instant as local wall-clock time in *zone*" | `timestamp` |
| `timestamp` | "these naive digits are local time in *zone*; give me the instant" | `timestamptz` |

Read it as: **it converts *to* the type you don't have.**

Applied:

```sql
SELECT payment_id,
       paid_at                                   AS utc_instant,
       paid_at AT TIME ZONE 'Europe/Berlin'      AS berlin_local,
       paid_at AT TIME ZONE 'America/New_York'   AS new_york_local
FROM   payments
ORDER  BY paid_at
LIMIT  5;
```

One stored instant, three renderings. Nothing about the stored data changes.

### Always use IANA names, never offsets

```sql
SELECT TIMESTAMPTZ '2024-01-15 12:00+00' AT TIME ZONE 'Europe/Berlin',  -- 13:00 (CET)
       TIMESTAMPTZ '2024-07-15 12:00+00' AT TIME ZONE 'Europe/Berlin';  -- 14:00 (CEST)
```

The same zone name gives a different offset in January and July, because
`Europe/Berlin` is a **rule**, not a number. `'+01:00'` is a fact about one
moment and will be wrong for half the year.

Browse what's available:

```sql
SELECT * FROM pg_timezone_names LIMIT 10;
SELECT * FROM pg_timezone_names WHERE name LIKE 'Europe/%';
```

⚠️ **Avoid the three-letter abbreviations.** `'EST'`, `'IST'` and friends are
ambiguous — `IST` is Indian, Irish *and* Israeli Standard Time depending on who
you ask — and they don't follow DST. `'America/New_York'` is unambiguous and
correct all year.

### Session timezone

```sql
SHOW timezone;
SET timezone = 'Europe/Berlin';
SELECT now();
RESET timezone;
```

`SET timezone` changes only how `timestamptz` values are **displayed and
parsed** for your session. It changes nothing on disk. Two users in different
zones querying the same row see different text and the same instant — which is
the whole point.

### DST: the hours that don't exist and the hours that happen twice

```sql
-- Germany springs forward 2024-03-31 02:00 → 03:00
SELECT TIMESTAMP '2024-03-31 02:30:00' AT TIME ZONE 'Europe/Berlin';
```

That local time never happened. PostgreSQL resolves it rather than erroring, but
any application logic assuming "every local time exists" is wrong twice a year.

Autumn is worse: when clocks go back, 02:30 local happens **twice**, and a naive
`timestamp` cannot distinguish them. A `timestamptz` can, because it stores the
instant. This is the strongest practical argument for `timestamptz` that exists:
*some local times are not unique*.

🎯 **Interview** — "Why not store local time plus an offset?" → An offset
cannot express a rule. Future local times computed to an offset break when the
DST rules change (and they do: Morocco, Chile, Mexico and the EU have all
changed rules in the last decade). Store `timestamptz` for past events; store
local time + IANA zone name for future local commitments; never store a bare
offset as your only zone information.

---

## Part 6 — One more interval subtlety

```sql
SET timezone = 'Europe/Berlin';
SELECT TIMESTAMPTZ '2024-03-30 12:00+01' + INTERVAL '1 day'   AS plus_one_day,
       TIMESTAMPTZ '2024-03-30 12:00+01' + INTERVAL '24 hours' AS plus_24_hours;
RESET timezone;
```

Across the spring DST boundary these give **different instants**. `1 day` means
"the same wall-clock time tomorrow" and `24 hours` means "86,400 seconds
later". On 30 March in Berlin, tomorrow's noon is only 23 hours away.

This is why PostgreSQL keeps months, days and microseconds as separate fields
in an interval: `days` is calendar-aware, `hours` is absolute. Choosing the
wrong one puts an event an hour off, twice a year, in a way that is very hard to
reproduce.

### `OVERLAPS`

```sql
SELECT (DATE '2024-01-01', DATE '2024-06-30')
    OVERLAPS (DATE '2024-05-01', DATE '2024-12-31');   -- true
```

A tidy way to test whether two periods intersect. Note it treats ranges as
**half-open** — `[start, end)` — which is the same convention you adopted on
Day 10 and for the same reasons. Range types (Day 70) generalise this properly.

---

## Traps & Gotchas

| # | Trap | What happens |
|---|---|---|
| 1 | `interval '1 month' = interval '30 days'` | False. Months are not fixed. |
| 2 | `(d + 1 month) - 1 month <> d` | 31 Jan → 29 Feb → 29 Jan |
| 3 | `+ 1 month + 1 month <> + 2 months` | Clamping happens at each step |
| 4 | `date + interval` returns `timestamp` | Cast back with `::date` |
| 5 | `HH24:MM` in `to_char` | `MM` is month; you want `MI` |
| 6 | `to_char(d, 'Month')` | Padded to 9 chars — use `FMMonth` |
| 7 | `to_date('2024-13-45', ...)` | Silently rolls over; use `::date` to validate |
| 8 | `(d2 - d1) / 365` for age | Leap years — use `age()` |
| 9 | Timezone abbreviations like `'IST'` | Ambiguous; use IANA names |
| 10 | Storing an offset instead of a zone name | Breaks when DST rules change |
| 11 | `+ 1 day` vs `+ 24 hours` across DST | Different instants |
| 12 | Assuming every local time exists | Spring-forward hour doesn't |
| 13 | Assuming local times are unique | Autumn hour occurs twice |

---

## Interview angles

- **Junior** — "30 days from today." → `current_date + INTERVAL '30 days'`
- **Junior** — "How old is this customer?" →
  `EXTRACT(YEAR FROM age(birth_date))`
- **Mid** — "Last day of the month for any date." →
  `(date_trunc('month', d) + INTERVAL '1 month - 1 day')::date`
- **Mid** — "Why isn't `interval '1 month'` 30 days?" → Months vary; intervals
  store months, days and microseconds separately.
- **Mid** — "Show a UTC timestamp in the user's local time." →
  `ts AT TIME ZONE 'Europe/Berlin'`, with an IANA name.
- **Senior** — "Design recurring monthly billing." → Requires a product
  decision for months with fewer days. Common approaches: bill on
  `least(anchor_day, days_in_month)`; or normalise every subscription to a safe
  day (≤28); or bill on the last day when the anchor is the last day. Store the
  anchor, compute the date, never just add a month blindly.
- **Senior** — "A cron job runs at 02:30 local and skipped a day in March." →
  DST spring-forward; that local time did not exist. Schedule in UTC, or use a
  scheduler that understands zones, and make the job idempotent so a double run
  in autumn is harmless.

---

## Practice

> Available: everything from Days 1–15 plus today's interval, formatting and
> timezone tools.

### Section A — Drill (new concept only)

1. `INTERVAL '1 day'`, `'3 hours'`, `'2 weeks'`, `'1 year 2 months'` in one row.
2. `INTERVAL '1 month' = INTERVAL '30 days'` — what and why?
3. `make_interval(days => 45)` and `make_interval(years => 2, months => 3)`.
4. `DATE '2024-03-15' + INTERVAL '1 month'`, and its type.
5. The same, cast back to a `date`.
6. `DATE '2024-03-15' + 30` and its type. Compare with 4.
7. `DATE '2024-01-31' + INTERVAL '1 month'`.
8. `DATE '2024-02-29' - INTERVAL '1 month'`.
9. `DATE '2024-01-31' + INTERVAL '1 month' + INTERVAL '1 month'` versus
   `DATE '2024-01-31' + INTERVAL '2 months'`.
10. The first day of the month containing `2024-03-15`.
11. The last day of that month.
12. The first day of the following month.
13. `age(DATE '2025-01-01', DATE '1988-03-22')`.
14. The same as a whole number of years.
15. `DATE '2025-01-01' - DATE '1988-03-22'` — compare with 13.
16. `to_char(DATE '2024-03-15', 'DD/MM/YYYY')`.
17. `to_char(DATE '2024-03-15', 'FMDay, DDth FMMonth YYYY')`.
18. `to_char(DATE '2024-03-15', 'Month')` bracketed, then with `FM`.
19. `to_char(TIMESTAMPTZ '2024-03-15 14:30+00', 'HH24:MI')` and the same with
    `'HH24:MM'`. Explain.
20. `to_date('15/03/2024', 'DD/MM/YYYY')`.
21. `to_date('2024-13-45', 'YYYY-MM-DD')` — what do you get?
22. `'2024-13-45'::date` — what happens? Which is safer?
23. `make_date(2024, 3, 15)` and `make_date(2024, 13, 1)`.
24. `TIMESTAMPTZ '2024-03-15 14:30:00+00' AT TIME ZONE 'Asia/Kolkata'`.
25. `TIMESTAMP '2024-03-15 14:30:00' AT TIME ZONE 'Asia/Kolkata'`. Compare
    types with 24.
26. `TIMESTAMPTZ '2024-01-15 12:00+00' AT TIME ZONE 'Europe/Berlin'` and the
    same for July. Why do they differ?
27. `SHOW timezone;` then set it to `'Asia/Tokyo'`, run `SELECT now();`, then
    reset.
28. Ten rows from `pg_timezone_names`.
29. `(DATE '2024-01-01', DATE '2024-06-30') OVERLAPS (DATE '2024-05-01', DATE '2024-12-31')`.
30. `EXTRACT(EPOCH FROM INTERVAL '1 day 3 hours')`.

### Section B — Combination (with Days 01–15)

31. Every customer's age in whole years at 2025-01-01, oldest first, excluding
    those with no birth date.
32. Every employee's length of service at 2025-01-01 as a calendar interval.
33. Every employee's whole years of service at 2025-01-01, longest first.
34. Every order's date and the date 30 days later.
35. Every order's date and the first day of its month, as a `date`.
36. Every order's date and the last day of its month, as a `date`.
37. Every order's date formatted as `15 March 2024`.
38. Every order's date formatted as `Fri 15/03/2024`.
39. Every payment's `paid_at` shown in `Europe/Berlin` local time.
40. Every payment's `paid_at` shown in both Berlin and New York local time.
41. Every payment's `paid_at` formatted as `YYYY-MM-DD HH24:MI`.
42. Every review's `created_at` and its age relative to 2025-07-07, as an
    interval.
43. Orders placed in the last 90 days before 2025-07-07.
44. Customers who signed up more than 2 years before 2025-01-01.
45. Products added more than 18 months before 2025-01-01.
46. Payments made in the first 7 days of any month.
47. Employees hired in the first quarter of any year, formatted as
    `Mon YYYY`.
48. Every order placed on the last day of its month.
49. Every customer's signup date and the anniversary of it in 2025.
50. Every order's date and the number of whole weeks between it and
    2025-07-07.
51. Distinct month names present in `orders.order_date`, formatted with
    `FMMonth`.
52. Orders whose date, plus 45 days, falls in 2025.
53. Every payment's `paid_at`, its UTC hour, and its Berlin-local hour.
54. Reviews created in the same calendar month as `2024-04-15`, using
    `date_trunc`.
55. Every employee's hire date and their 10-year anniversary date.

### Section C — Recall (Days 01–15)

56. Orders placed in 2025, using a half-open range.
57. `EXTRACT(ISODOW FROM DATE '2024-03-17')` — which day is it?
58. Group-ready month values for `orders` using `date_trunc`.
59. Every product's margin percentage to 1 decimal.
60. `round(2.5::numeric)` versus `round(2.5::float8)`.
61. Every customer's email domain.
62. `concat_ws('-', 'a', NULL, 'b')` versus `'a' || NULL || 'b'`.
63. Products whose name contains `laptop`, any case.
64. `supplier_id NOT IN (1,2)` — why 15 and not 16?
65. Reset the database and verify the counts.

### Section D — Challenge

66. Prove that `(DATE '2024-01-31' + INTERVAL '1 month') - INTERVAL '1 month'`
    is not `2024-01-31`, and explain in one sentence why no date library can
    avoid this.
67. Write an expression for the last day of the month of **any** date, and
    verify it for January, February 2024, February 2023 and December.
68. Write an expression for the number of days in the month of any date.
69. Find every order placed on the last day of its month, and check your answer
    against Day 15's version of the same problem.
70. Compute each customer's age in years, months and days at 2025-01-01, as
    three separate integer columns.
71. Show that `+ INTERVAL '1 day'` and `+ INTERVAL '24 hours'` can differ.
    (Set `timezone = 'Europe/Berlin'` and use 2024-03-30.)
72. `to_char(ts, 'HH24:MM')` is a classic bug. Write a query over `payments`
    that shows the wrong and the right output side by side, and explain what
    `MM` produced.
73. Write a query listing every payment with: the instant, the Berlin local
    time, the New York local time, and the difference in hours between the two
    local renderings. Is that difference constant across the year? Check
    January and July.
74. `to_date('2024-02-30', 'YYYY-MM-DD')` succeeds. Show what it returns, show
    what `'2024-02-30'::date` does instead, and state which you would use to
    validate a CSV import.
75. Design question: a SaaS product bills monthly. A customer signs up on
    31 January. Specify the billing-date rule you would implement, write the SQL
    expression that computes the next billing date from an anchor date, and name
    one case where your rule will still annoy a customer.

---

## Solutions

### Section A

**1.** `SELECT INTERVAL '1 day', INTERVAL '3 hours', INTERVAL '2 weeks', INTERVAL '1 year 2 months';`
→ `1 day`, `03:00:00`, `14 days`, `1 year 2 mons`
**2.** `false`. Intervals store months and days separately because a month has
no fixed number of days.
**3.** `45 days`, `2 years 3 mons`
**4.** `2024-04-15 00:00:00`, type `timestamp without time zone`
**5.** `SELECT (DATE '2024-03-15' + INTERVAL '1 month')::date;` → `2024-04-15`
**6.** `2024-04-14`, type `date`. Adding an integer adds days and keeps the
type; adding an interval promotes to `timestamp`.
**7.** `2024-02-29` — clamped to the last day of February in a leap year.
**8.** `2024-01-29` — **not** 31 January.
**9.** `2024-03-29` versus `2024-03-31`. Clamping applies at each step, so
adding one month twice loses two days.
**10.** `SELECT date_trunc('month', DATE '2024-03-15')::date;` → `2024-03-01`
**11.** `SELECT (date_trunc('month', DATE '2024-03-15') + INTERVAL '1 month - 1 day')::date;` → `2024-03-31`
**12.** `SELECT (date_trunc('month', DATE '2024-03-15') + INTERVAL '1 month')::date;` → `2024-04-01`
**13.** `36 years 9 mons 10 days`
**14.** `SELECT EXTRACT(YEAR FROM age(DATE '2025-01-01', DATE '1988-03-22'))::int;` → 36
**15.** `13434` days — an exact count, versus `age()`'s human calendar answer.
**16.** `15/03/2024`
**17.** `Friday, 15th March 2024`
**18.** `[March    ]` then `[March]`. `Month` pads to nine characters.
**19.** `14:30` and `14:03`. `MM` is **month**; minutes are `MI`.
**20.** `2024-03-15`
**21.** `2025-02-14`. Month 13 rolled into the next year; day 45 rolled into the
next month. Silently.
**22.** `ERROR: date/time field value out of range`. The cast is **safer** — it
refuses invalid input instead of inventing a date.
**23.** `2024-03-15`; the second raises `date field value out of range`.
**24.** `2024-03-15 20:00:00`, type `timestamp` (no zone).
**25.** `2024-03-15 09:00:00+00`, type `timestamptz`. The operator converts
*to* the type you don't have.
**26.** `13:00:00` and `14:00:00`. Berlin is UTC+1 in winter (CET) and UTC+2 in
summer (CEST). The zone is a rule, not an offset.
**27.** `SHOW timezone; SET timezone = 'Asia/Tokyo'; SELECT now(); RESET timezone;`
**28.** `SELECT * FROM pg_timezone_names LIMIT 10;`
**29.** `true`
**30.** `97200` seconds (86400 + 10800).

### Section B

**31.**
```sql
SELECT first_name, birth_date,
       EXTRACT(YEAR FROM age(DATE '2025-01-01', birth_date))::int AS age_years
FROM   customers
WHERE  birth_date IS NOT NULL
ORDER  BY age_years DESC;
```
→ Michael O'Connor (1977) is oldest, at 47.
**32.** `SELECT first_name, age(DATE '2025-01-01', hire_date) AS service FROM employees;`
**33.**
```sql
SELECT first_name, EXTRACT(YEAR FROM age(DATE '2025-01-01', hire_date))::int AS years
FROM   employees ORDER BY years DESC;
```
→ Sofia Lindqvist, 8 years.
**34.** `SELECT order_id, order_date, order_date + 30 AS plus_30 FROM orders;`
**35.** `SELECT order_id, order_date, date_trunc('month', order_date)::date AS month_start FROM orders;`
**36.**
```sql
SELECT order_id, order_date,
       (date_trunc('month', order_date) + INTERVAL '1 month - 1 day')::date AS month_end
FROM   orders;
```
**37.** `SELECT order_id, to_char(order_date, 'FMDD FMMonth YYYY') FROM orders;`
**38.** `SELECT order_id, to_char(order_date, 'Dy DD/MM/YYYY') FROM orders;`
**39.** `SELECT payment_id, paid_at, paid_at AT TIME ZONE 'Europe/Berlin' AS berlin FROM payments;`
**40.**
```sql
SELECT payment_id,
       paid_at AT TIME ZONE 'Europe/Berlin'    AS berlin,
       paid_at AT TIME ZONE 'America/New_York' AS new_york
FROM   payments;
```
**41.** `SELECT payment_id, to_char(paid_at, 'YYYY-MM-DD HH24:MI') FROM payments;`
**42.** `SELECT review_id, created_at, age(TIMESTAMPTZ '2025-07-07', created_at) FROM reviews;`
**43.** `SELECT * FROM orders WHERE order_date > DATE '2025-07-07' - 90;`
**44.** `SELECT * FROM customers WHERE signup_date < DATE '2025-01-01' - INTERVAL '2 years';`
**45.** `SELECT * FROM products WHERE added_on < DATE '2025-01-01' - INTERVAL '18 months';`
**46.** `SELECT * FROM payments WHERE EXTRACT(DAY FROM paid_at) <= 7;`
**47.**
```sql
SELECT first_name, to_char(hire_date, 'FMMon YYYY') AS hired
FROM   employees WHERE EXTRACT(QUARTER FROM hire_date) = 1;
```
**48.**
```sql
SELECT order_id, order_date FROM orders
WHERE  order_date = (date_trunc('month', order_date) + INTERVAL '1 month - 1 day')::date;
```
**49.**
```sql
SELECT first_name, signup_date,
       make_date(2025, EXTRACT(MONTH FROM signup_date)::int,
                       EXTRACT(DAY FROM signup_date)::int) AS anniversary_2025
FROM   customers;
```
(Note this would fail for a 29 February signup — a real edge case.)
**50.** `SELECT order_id, (DATE '2025-07-07' - order_date) / 7 AS weeks_ago FROM orders;`
**51.** `SELECT DISTINCT to_char(order_date, 'FMMonth') AS month FROM orders;`
**52.** `SELECT * FROM orders WHERE order_date + 45 >= DATE '2025-01-01';`
**53.**
```sql
SELECT payment_id, paid_at,
       EXTRACT(HOUR FROM paid_at)                                  AS utc_hour,
       EXTRACT(HOUR FROM paid_at AT TIME ZONE 'Europe/Berlin')     AS berlin_hour
FROM   payments;
```
(The first `EXTRACT` uses your session timezone — set it to UTC to make the
comparison meaningful.)
**54.** `SELECT * FROM reviews WHERE date_trunc('month', created_at) = date_trunc('month', TIMESTAMPTZ '2024-04-15');`
**55.** `SELECT first_name, hire_date, (hire_date + INTERVAL '10 years')::date AS decade FROM employees;`

### Section C

**56.** `WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2026-01-01';`
**57.** `7` — a Sunday.
**58.** `SELECT date_trunc('month', order_date)::date FROM orders;`
**59.** `SELECT product_name, round((price-cost)/price*100, 1) FROM products;`
**60.** `3` and `2`.
**61.** `SELECT split_part(email, '@', 2) FROM customers;`
**62.** `a-b` and `NULL`.
**63.** `WHERE product_name ILIKE '%laptop%';`
**64.** `Webcam HD` has `supplier_id IS NULL`, so it satisfies neither `IN` nor
`NOT IN`.
**65.** `\i 99_reset.sql`

### Section D

**66.**
```sql
SELECT DATE '2024-01-31'                                        AS start_date,
       DATE '2024-01-31' + INTERVAL '1 month'                   AS plus_month,
      (DATE '2024-01-31' + INTERVAL '1 month') - INTERVAL '1 month' AS back_again;
```
→ `2024-01-31`, `2024-02-29`, `2024-01-29`.

No library can avoid it because the operation is not injective: 29, 30 and
31 January all map to 29 February, so the reverse mapping cannot recover which
one you started from. The information is destroyed by the clamp, not by the
implementation.

**67.**
```sql
SELECT d,
       (date_trunc('month', d) + INTERVAL '1 month - 1 day')::date AS last_day
FROM   (VALUES (DATE '2024-01-15'), (DATE '2024-02-15'),
               (DATE '2023-02-15'), (DATE '2024-12-15')) AS t(d);
```
→ `2024-01-31`, `2024-02-29`, `2023-02-28`, `2024-12-31`. Correct for leap and
non-leap February without a special case.

**68.**
```sql
SELECT EXTRACT(DAY FROM (date_trunc('month', DATE '2024-02-15')
                         + INTERVAL '1 month - 1 day'))::int AS days_in_month;
```
→ 29. The day-of-month of the last day *is* the number of days in the month.

**69.**
```sql
-- Day 16 version
SELECT order_id, order_date FROM orders
WHERE  order_date = (date_trunc('month', order_date) + INTERVAL '1 month - 1 day')::date;

-- Day 15 version
SELECT order_id, order_date FROM orders
WHERE  order_date + 1 = date_trunc('month', order_date + 1)::date;
```
Both return the same rows. The Day 15 version ("tomorrow is the 1st") is
cleverer; the Day 16 version ("this is the computed last day") is more obvious
to a reader. Prefer the readable one unless you have a reason not to.

**70.**
```sql
SELECT first_name,
       EXTRACT(YEAR  FROM age(DATE '2025-01-01', birth_date))::int AS years,
       EXTRACT(MONTH FROM age(DATE '2025-01-01', birth_date))::int AS months,
       EXTRACT(DAY   FROM age(DATE '2025-01-01', birth_date))::int AS days
FROM   customers WHERE birth_date IS NOT NULL;
```

**71.**
```sql
SET timezone = 'Europe/Berlin';
SELECT TIMESTAMPTZ '2024-03-30 12:00:00+01' + INTERVAL '1 day'    AS plus_day,
       TIMESTAMPTZ '2024-03-30 12:00:00+01' + INTERVAL '24 hours' AS plus_24h;
RESET timezone;
```
`+ 1 day` lands on 31 March at 12:00 **local** (13:00 in the pre-shift offset),
while `+ 24 hours` lands 86,400 seconds later, which is 13:00 local. One hour
apart. `days` is calendar-aware; `hours` is absolute. Choose deliberately.

**72.**
```sql
SELECT payment_id,
       paid_at,
       to_char(paid_at, 'HH24:MM') AS wrong,
       to_char(paid_at, 'HH24:MI') AS right
FROM   payments ORDER BY paid_at LIMIT 5;
```
The `wrong` column shows the hour followed by the **month number** — so a
payment at 14:22 in January renders as `14:01`. It looks like a plausible time,
which is precisely why it survives review.

**73.**
```sql
SELECT payment_id,
       paid_at,
       paid_at AT TIME ZONE 'Europe/Berlin'    AS berlin,
       paid_at AT TIME ZONE 'America/New_York' AS new_york,
       EXTRACT(EPOCH FROM (paid_at AT TIME ZONE 'Europe/Berlin')
                        - (paid_at AT TIME ZONE 'America/New_York')) / 3600
         AS hours_apart
FROM   payments ORDER BY paid_at;
```
The difference is **usually** 6 hours, but not always: the EU and the US change
their clocks on different dates, so for roughly two weeks in March and one week
in autumn the gap is 5 or 7 hours. Any code that hard-codes "Berlin is 6 hours
ahead of New York" is wrong for about three weeks a year — a bug that surfaces
only in specific weeks and is nearly impossible to reproduce afterwards.

**74.**
```sql
SELECT to_date('2024-02-30', 'YYYY-MM-DD');   -- 2024-03-01
SELECT '2024-02-30'::date;                    -- ERROR: date/time field value out of range
```
`to_date` rolls the overflow into March. The cast refuses.

For validating a CSV import, use the **cast**. You want bad data to fail loudly
at the boundary, not to be silently converted into a plausible wrong date that
propagates through every downstream report. The general principle — *reject at
the edge, don't repair silently* — applies far beyond dates.

**75.** **Rule I would implement:** bill on the anchor day-of-month, clamped to
the last day of the target month.

```sql
-- next billing date from an anchor date and a target month
SELECT least(
         EXTRACT(DAY FROM anchor)::int,
         EXTRACT(DAY FROM (date_trunc('month', target) + INTERVAL '1 month - 1 day'))::int
       ) AS billing_day;
```

Concretely, computing the next billing date one month on from an anchor:

```sql
SELECT (date_trunc('month', anchor + INTERVAL '1 month')
        + make_interval(days => least(
              EXTRACT(DAY FROM anchor)::int,
              EXTRACT(DAY FROM (date_trunc('month', anchor + INTERVAL '1 month')
                                + INTERVAL '1 month - 1 day'))::int
          ) - 1))::date AS next_billing_date;
```

**Crucially, store the original anchor day (31), not the clamped one.** If you
store the clamped date, a customer anchored on 31 January bills on 29 February,
then 29 March, then 29 April — drifting permanently off their real anniversary.
Recomputing from the anchor every cycle gives 31 Jan → 29 Feb → 31 Mar → 30 Apr,
which is what the customer expects.

**Where it still annoys someone:** a customer who signed up on the 31st is
billed on the 28th in February — three days "early" — and if they cancel on
1 March they have paid for a period they perceive as 29 days, not a month. Some
businesses avoid the whole argument by normalising every anchor to day ≤ 28, or
by billing on a fixed day for everyone and pro-rating the first period. All
three are defensible; none is free. The senior move is to make the choice
explicitly with the product owner and write it down, rather than letting it be
decided implicitly by whatever `+ INTERVAL '1 month'` happens to do.

---

## Day 16 Checklist

- [ ] I know an interval stores months, days and microseconds **separately**
- [ ] **I know `1 month` ≠ `30 days` and `+1 month` is not reversible**
- [ ] I know `date + interval` gives a `timestamp`, and cast back when needed
- [ ] I can compute the first and last day of any month
- [ ] I use `age()` for human ages, not `/ 365`
- [ ] I can format dates with `to_char` and I know `MI` ≠ `MM`
- [ ] I know `FM` suppresses padding
- [ ] I use `::date` to validate and `to_date` only for non-ISO parsing
- [ ] **I know `AT TIME ZONE` converts *to* the type you don't have**
- [ ] I always use IANA zone names, never offsets or abbreviations
- [ ] I know some local times don't exist and some occur twice
- [ ] I know `+1 day` and `+24 hours` can differ across a DST boundary

---

## What's next

**Day 17 — `CASE`, `COALESCE`, `NULLIF`, `GREATEST` and `LEAST`.** Conditional
logic inside a query — and, at last, the answer to the problem you have been
carrying since Day 4: how to substitute a sensible value when a column is
`NULL`.
