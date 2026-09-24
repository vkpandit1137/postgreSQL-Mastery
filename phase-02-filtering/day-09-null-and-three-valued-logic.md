# Day 09 — `NULL` and Three-Valued Logic

> **Phase** 2 · Filtering & Expressions
> **Level** Absolute Beginner
> **Time** 120–150 minutes
> **Prerequisites** Days 01–08
> **New concepts** What `NULL` means · TRUE/FALSE/UNKNOWN · `IS NULL` / `IS NOT NULL` · `NULL` in arithmetic, concatenation and comparison · `IS DISTINCT FROM` · `IS TRUE`/`IS FALSE`/`IS NOT TRUE` · `NULL` in `ORDER BY`, `DISTINCT`, `AND`/`OR` · `NULL` vs empty string vs zero
>
> **This is the most important day in the first month of this program.** Do not
> rush it. If you only half-learn one day out of 115, do not let it be this one.

---

## Why this matters

You have already been bitten by `NULL` three times without being told why:

- **Day 4** — `first_name || ' lives in ' || city` produced two blank rows.
- **Day 7** — `city = 'Berlin'` and `city <> 'Berlin'` summed to 22, not 24.
- **Day 8** — `loyalty_tier = 'gold' OR loyalty_tier <> 'gold'` returned 20 of
  24 customers, even though that sentence is logically always true.

Each time, rows **silently disappeared**. No error. No warning. A plausible
number in a report that was wrong.

That is what makes `NULL` the highest-consequence topic in beginner SQL. A
syntax error costs you thirty seconds. A `NULL` bug costs you a quarter of
misreported revenue, and you find out when someone else notices.

---

## Part 1 — What `NULL` actually means

`NULL` means **"no value here"** — unknown, missing, or not applicable.

It is emphatically **not**:

| `NULL` is not | Because |
|---|---|
| zero | `0` is a known quantity: *we counted, and there were none* |
| an empty string `''` | `''` is a known string of length 0 |
| `false` | `false` is a known boolean |
| the text `'NULL'` | that's a four-character string |

Run this once and keep the output in your head:

```sql
SELECT NULL = 0        AS null_is_zero,
       NULL = ''       AS null_is_empty,
       NULL = false    AS null_is_false,
       NULL = 'NULL'   AS null_is_the_word;
```

```
 null_is_zero | null_is_empty | null_is_false | null_is_the_word
--------------+---------------+---------------+------------------
 ␀            | ␀             | ␀             | ␀
```

Every answer is **`NULL`** — not `true`, not `false`. That is the whole lesson,
and everything else today follows from it.

💡 If your output shows blanks rather than `␀`, set
`\pset null '␀'` (Day 1, Part 7). Working with an invisible NULL is like
debugging with the lights off.

### Why a database needs `NULL`

Three genuinely different situations, all represented by `NULL`:

| Situation | Example in `shopdb` |
|---|---|
| **Unknown** — there is a value, we don't know it | `customers.birth_date` for customer 4 |
| **Not applicable** — the attribute makes no sense here | `employees.commission_pct` for the CEO |
| **Not yet** — will have a value later | `orders.employee_id` for a self-service order |

Some designers argue these should be modelled separately. They are right in
theory and almost nobody does it. What matters practically is that `NULL`
conflates all three, so *you* must know which one you're dealing with.

### Finding the NULLs in the practice database

```sql
SELECT customer_id, first_name, city, phone, birth_date, loyalty_tier
FROM   customers
WHERE  city IS NULL;
```

```
 customer_id | first_name |  city  | phone | birth_date | loyalty_tier
-------------+------------+--------+-------+------------+--------------
           7 | Marie      | ␀      | ␀     | 1995-08-19 | bronze
          18 | Nina       | ␀      | ␀     | 1994-05-30 | ␀
```

There they are — the two customers who have been vanishing since Day 4.

---

## Part 2 — Three-valued logic

Most programming languages have two truth values. **SQL has three.**

```
TRUE        FALSE        UNKNOWN
```

`UNKNOWN` is what you get when a comparison involves `NULL`. PostgreSQL
represents `UNKNOWN` as `NULL`, which is confusing but consistent: the result of
an unknown comparison is itself unknown.

### The rule that explains everything

> **`WHERE` keeps a row only when the condition evaluates to `TRUE`.**
> `FALSE` and `UNKNOWN` are both discarded.

That single sentence explains every disappearance you've seen. A row whose
`city` is `NULL` produces `UNKNOWN` for `city = 'Berlin'` **and** `UNKNOWN` for
`city <> 'Berlin'`. Neither is `TRUE`. The row is discarded by both.

### The truth tables

**`AND`** — `TRUE` only if both are true; `FALSE` wins over `UNKNOWN`:

| `AND` | TRUE | FALSE | UNKNOWN |
|---|---|---|---|
| **TRUE** | TRUE | FALSE | UNKNOWN |
| **FALSE** | FALSE | FALSE | **FALSE** |
| **UNKNOWN** | UNKNOWN | **FALSE** | UNKNOWN |

**`OR`** — `TRUE` wins over `UNKNOWN`:

| `OR` | TRUE | FALSE | UNKNOWN |
|---|---|---|---|
| **TRUE** | TRUE | **TRUE** | **TRUE** |
| **FALSE** | TRUE | FALSE | UNKNOWN |
| **UNKNOWN** | **TRUE** | UNKNOWN | UNKNOWN |

**`NOT`**:

| | NOT |
|---|---|
| TRUE | FALSE |
| FALSE | TRUE |
| **UNKNOWN** | **UNKNOWN** |

The two cells worth memorising are the bold ones:

- **`FALSE AND UNKNOWN = FALSE`** — a definite falsehood beats an unknown.
- **`TRUE OR UNKNOWN = TRUE`** — a definite truth beats an unknown.
- **`NOT UNKNOWN = UNKNOWN`** — negating "I don't know" gives "I don't know".

That last one is why yesterday's tautology failed. `NOT` cannot rescue a `NULL`.

▶ **Try it** — verify the tables yourself:

```sql
SELECT true  AND NULL AS t_and_n,
       false AND NULL AS f_and_n,
       true  OR  NULL AS t_or_n,
       false OR  NULL AS f_or_n,
       NOT NULL       AS not_n;
```

```
 t_and_n | f_and_n | t_or_n | f_or_n | not_n
---------+---------+--------+--------+-------
 ␀       | f       | t      | ␀      | ␀
```

---

## Part 3 — `IS NULL` and `IS NOT NULL`

Because `= NULL` never works, SQL provides a dedicated operator.

```sql
SELECT customer_id, first_name, city
FROM   customers
WHERE  city IS NULL;              -- 2 rows

SELECT customer_id, first_name, city
FROM   customers
WHERE  city IS NOT NULL;          -- 22 rows
```

2 + 22 = 24. ✓ **`IS NULL` and `IS NOT NULL` always partition a table
exactly**, because they return `TRUE`/`FALSE` and never `UNKNOWN`.

Compare with yesterday's broken split:

```sql
SELECT count(*) FROM customers WHERE city = 'Berlin';    --  2
SELECT count(*) FROM customers WHERE city <> 'Berlin';   -- 20
SELECT count(*) FROM customers WHERE city IS NULL;       --  2
                                                          -- ---
                                                          --  24 ✓
```

The three together account for everyone. Any exhaustive analysis of a nullable
column needs all three branches.

### The NULLs in `shopdb`

Worth running all of these once, today:

```sql
SELECT count(*) FROM customers WHERE city IS NULL;            -- 2
SELECT count(*) FROM customers WHERE phone IS NULL;           -- 5
SELECT count(*) FROM customers WHERE birth_date IS NULL;      -- 2
SELECT count(*) FROM customers WHERE loyalty_tier IS NULL;    -- 4
SELECT count(*) FROM products  WHERE supplier_id IS NULL;     -- 1
SELECT count(*) FROM orders    WHERE employee_id IS NULL;     -- 6
SELECT count(*) FROM employees WHERE manager_id IS NULL;      -- 1
SELECT count(*) FROM employees WHERE commission_pct IS NULL;  -- 7
SELECT count(*) FROM suppliers WHERE contact_email IS NULL;   -- 1
```

Each one is a real modelling decision:

- `employees.manager_id IS NULL` → the CEO. Exactly one, by design.
- `employees.commission_pct IS NULL` → non-sales roles. "Not applicable".
- `orders.employee_id IS NULL` → self-service orders. "Not applicable".
- `products.supplier_id IS NULL` → a discontinued product whose supplier
  relationship has ended. "No longer applicable".

🎯 **Interview** — "Find all employees with no manager." →
`WHERE manager_id IS NULL`. If the candidate writes `= NULL`, the interview is
effectively over. This is the single most common SQL screening question.

---

## Part 4 — `NULL` propagates through everything

### Arithmetic

```sql
SELECT 10 + NULL, 10 * NULL, 10 / NULL, NULL - NULL;
```

All `NULL`. Any arithmetic involving `NULL` is `NULL`. It makes sense: if you
don't know one of the numbers, you don't know the answer.

Realistically:

```sql
SELECT first_name, salary, commission_pct,
       salary * commission_pct AS commission
FROM   employees;
```

Seven employees show a blank `commission` — the ones with no
`commission_pct`. Not zero. Blank. If you then sum that column for a payroll
report you will (correctly) skip them — but if you *average* it, you'll get the
average over five people, not twelve, which may or may not be what you wanted.
Day 19 covers exactly that.

### Concatenation

```sql
SELECT first_name || ' lives in ' || city AS location
FROM   customers;
```

Two blank rows, as on Day 4. Now you know why: `'Marie lives in ' || NULL` is
`NULL`.

💡 There is a function that concatenates while ignoring NULLs —
`concat_ws()` — and one that substitutes a fallback — `COALESCE()`. They are
Days 13 and 17 respectively. Today, just recognise the problem.

### Comparison

```sql
SELECT NULL = NULL, NULL <> NULL, NULL > 5, NULL < 5;
```

All `NULL`. Including `NULL = NULL` — two unknown values cannot be shown to be
equal.

⚠️ **Trap** — this is why you cannot compare two nullable columns naively:

```sql
SELECT count(*) FROM orders WHERE shipping_country = 'Germany';
```

is fine, because `shipping_country` has no NULLs here. But if it did, any row
with a NULL would drop out silently.

---

## Part 5 — `IS DISTINCT FROM` 🐘

Sometimes you want `=` semantics but with NULLs treated as a comparable value.
`IS DISTINCT FROM` is `<>` that handles NULLs sensibly; `IS NOT DISTINCT FROM`
is `=` that handles NULLs sensibly.

```sql
SELECT NULL =  NULL                    AS plain_equals,        -- NULL
       NULL IS NOT DISTINCT FROM NULL  AS null_safe_equals,    -- true
       1    IS DISTINCT FROM NULL      AS null_safe_neq,       -- true
       1    <> NULL                    AS plain_neq;           -- NULL
```

```
 plain_equals | null_safe_equals | null_safe_neq | plain_neq
--------------+------------------+---------------+-----------
 ␀            | t                | t             | ␀
```

| Operator | NULL = NULL | NULL = 1 | Returns NULL? |
|---|---|---|---|
| `=` | NULL | NULL | yes |
| `IS NOT DISTINCT FROM` | true | false | **never** |
| `<>` | NULL | NULL | yes |
| `IS DISTINCT FROM` | false | true | **never** |

Where this earns its keep: *"find every customer not in Berlin, including those
with no city recorded."*

```sql
-- the naive version loses the NULLs
SELECT count(*) FROM customers WHERE city <> 'Berlin';                   -- 20

-- this one keeps them
SELECT count(*) FROM customers WHERE city IS DISTINCT FROM 'Berlin';     -- 22
```

22 is almost always the number a human meant. A customer whose city we never
recorded is certainly *not* in Berlin, as far as a mailing-list query is
concerned.

🐘 **Postgres-only-ish** — `IS DISTINCT FROM` is standard SQL and works in
PostgreSQL, SQLite and SQL Server 2022+. MySQL spells it `<=>` (null-safe
equals). Oracle has no direct equivalent.

🎯 **Interview** — mid-level and up: "How do you compare two nullable columns
for inequality, treating NULL as a value?" → `a IS DISTINCT FROM b`. This is a
good discriminator because it's the sort of thing you only know if you've been
burned.

---

## Part 6 — `IS TRUE`, `IS FALSE`, `IS NOT TRUE`

For boolean columns and expressions there is a family of NULL-safe tests:

```sql
SELECT NULL IS TRUE      AS a,   -- false
       NULL IS FALSE     AS b,   -- false
       NULL IS NOT TRUE  AS c,   -- true
       NULL IS NOT FALSE AS d,   -- true
       NULL IS UNKNOWN   AS e;   -- true
```

None of these ever return `NULL`. They always give a definite `true` or `false`.

The useful one is **`IS NOT TRUE`**, which means "false or unknown":

```sql
-- misses rows where is_active is NULL (none here, but in general)
WHERE NOT is_active

-- catches false AND null
WHERE is_active IS NOT TRUE
```

In `shopdb`, `is_active` is `NOT NULL`, so both return the same 2 rows. In a
table where the flag is nullable, they differ — and `IS NOT TRUE` is usually
what a human means by "not active".

💡 **Design note** — this whole family of problems is why boolean columns should
almost always be declared `NOT NULL DEFAULT false`. A three-state boolean is
rarely intentional. You'll make that call yourself on Day 55.

---

## Part 7 — Where `NULL` behaves *unlike* itself

Here is the genuinely confusing part, and the reason `NULL` trips up even
experienced engineers. In some contexts, SQL treats all NULLs as **equal to each
other**, contradicting `NULL = NULL` being unknown.

| Context | How NULLs are treated |
|---|---|
| `WHERE a = b` | unknown — row discarded |
| `ORDER BY` | all NULLs group together; sort last by default (Day 5) |
| `DISTINCT` | all NULLs collapse to **one** row |
| `GROUP BY` | all NULLs form **one** group (Day 20) |
| `UNION` / `INTERSECT` / `EXCEPT` | NULLs match each other (Day 33) |
| `UNIQUE` constraint | multiple NULLs are **allowed** (Day 55) |
| `count(col)` | NULLs are **skipped** (Day 19) |
| `count(*)` | rows counted regardless (Day 19) |

You have already seen two of these:

```sql
SELECT DISTINCT loyalty_tier FROM customers;   -- 5 rows: 4 tiers + one NULL
SELECT * FROM customers ORDER BY city;         -- the 2 NULL cities sort last
```

The apparent contradiction has a tidy explanation: `=` asks *"are these the same
value?"*, which is unanswerable for unknowns. `DISTINCT` and `GROUP BY` ask
*"should these rows be bucketed together?"*, and the useful answer is yes. The
standard calls this "not distinct from" semantics — the same idea as
`IS NOT DISTINCT FROM`.

🎯 **Interview** — senior-level: *"`NULL = NULL` is unknown, yet
`SELECT DISTINCT` collapses NULLs into one row. Explain."* This is a genuinely
good question and the answer above is the one to give.

---

## Part 8 — `NULL` vs empty string vs zero

PostgreSQL keeps these strictly separate. (Oracle famously does not — it treats
`''` as `NULL`, which is a long-standing source of cross-database bugs.)

```sql
SELECT ''     IS NULL     AS empty_is_null,      -- false
       length('')         AS len_of_empty,       -- 0
       length(NULL)       AS len_of_null,        -- NULL
       ''     = NULL      AS empty_eq_null,      -- NULL
       0      IS NULL     AS zero_is_null;       -- false
```

```
 empty_is_null | len_of_empty | len_of_null | empty_eq_null | zero_is_null
---------------+--------------+-------------+---------------+--------------
 f             |            0 | ␀           | ␀             | f
```

**Why this matters in practice:** a web form that submits an untouched text box
usually sends `''`, not `NULL`. If your table has some rows with `''` and some
with `NULL`, then `WHERE phone IS NULL` finds only half your "missing phone"
records. Data cleaning jobs exist almost entirely because of this.

The correct fix is at write time, not read time: decide that "missing" is
represented by `NULL`, add a `CHECK (phone <> '')` constraint (Day 55), and
normalise the application's empty strings to `NULL` on the way in.

---

## Traps & Gotchas

| # | Trap | What happens |
|---|---|---|
| 1 | `WHERE col = NULL` | 0 rows, no error. Use `IS NULL`. |
| 2 | `WHERE col <> 'x'` on a nullable column | NULL rows silently excluded |
| 3 | `a = x OR a <> x` | Not a tautology — NULL rows excluded |
| 4 | `NOT (col = 'x')` | Still excludes NULLs — `NOT UNKNOWN` is `UNKNOWN` |
| 5 | `col || 'text'` with nullable `col` | Entire string becomes NULL |
| 6 | `col + 1` with nullable `col` | Result is NULL, not 1 |
| 7 | Assuming `''` and `NULL` are the same | They aren't in Postgres |
| 8 | Assuming `DISTINCT` drops NULLs | It keeps exactly one |
| 9 | `UNIQUE` column with several NULLs | Allowed. NULLs don't conflict. |
| 10 | `NOT IN (subquery)` with a NULL in it | Returns **zero rows**. Day 37. |

Trap 10 is the most dangerous construct in SQL, and you'll meet it properly on
Day 37 once subqueries exist. A one-line preview so it's on your radar:

```sql
SELECT 1 WHERE 5 NOT IN (1, 2, NULL);
```

```
(0 rows)
```

5 is obviously not 1, 2 or NULL — and yet the result is empty. Reason:
`5 NOT IN (1,2,NULL)` expands to `5<>1 AND 5<>2 AND 5<>NULL`, which is
`TRUE AND TRUE AND UNKNOWN` = `UNKNOWN`. Discarded.

---

## Interview angles

- **Junior** — "How do you find rows where a column has no value?" →
  `IS NULL`, never `= NULL`.
- **Junior** — "What does `NULL = NULL` return?" → `NULL` (unknown), not `true`.
- **Mid** — "`WHERE status <> 'cancelled'` — what's the risk?" → Rows with
  `status IS NULL` are silently excluded. Use `IS DISTINCT FROM`, or add an
  `OR status IS NULL`, or make the column `NOT NULL`.
- **Mid** — "Difference between `NULL` and empty string?" → Unknown versus a
  known zero-length string. Distinct in Postgres; conflated in Oracle.
- **Mid** — "Why does `COUNT(column)` differ from `COUNT(*)`?" → `COUNT(col)`
  skips NULLs. Day 19.
- **Senior** — "`NULL = NULL` is unknown but `GROUP BY` puts NULLs in one
  group. Reconcile." → `=` tests value equality; grouping uses "not distinct
  from" semantics. Same for `DISTINCT` and set operations.
- **Senior** — "Can a `UNIQUE` column hold two NULLs?" → Yes, in standard SQL
  and Postgres — NULLs are not equal so they don't conflict. Postgres 15 added
  `UNIQUE NULLS NOT DISTINCT` to change that. Day 55.
- **Senior** — "Design question: should this column be nullable?" → The right
  answer discusses the three meanings (unknown / not applicable / not yet),
  whether a `NOT NULL DEFAULT` removes an entire bug class, and whether a
  "not applicable" case actually indicates a missing table.

---

## Practice

> Available: everything from Days 1–8, plus `IS NULL`, `IS NOT NULL`,
> `IS DISTINCT FROM`, `IS TRUE`/`IS FALSE`/`IS NOT TRUE`.
> Not yet available: `IN`, `BETWEEN`, `LIKE`, `COALESCE`.

### Section A — Drill (new concept only)

1. Customers with no city recorded.
2. Customers with a city recorded.
3. Customers with no phone number.
4. Customers with no birth date.
5. Customers with no loyalty tier.
6. Customers who have a loyalty tier.
7. Products with no supplier.
8. Products that have a supplier.
9. Orders placed without a salesperson.
10. Orders that had a salesperson.
11. Employees with no manager.
12. Employees who have a manager.
13. Employees with no commission percentage.
14. Employees who earn commission.
15. Suppliers with no contact email.
16. Count how many customers have no city, and how many do. Do they sum to 24?
17. Count how many employees have no commission, and how many do. Sum?
18. Return `NULL = NULL` and explain the result in one sentence.
19. Return `NULL IS NOT DISTINCT FROM NULL`.
20. Return `1 IS DISTINCT FROM NULL`.
21. Return `NULL IS TRUE`, `NULL IS FALSE` and `NULL IS NOT TRUE` in one row.
22. Return `true AND NULL`, `false AND NULL`, `true OR NULL`, `false OR NULL`.
23. Return `NOT NULL`.
24. Return `'' IS NULL` and `length('')`.
25. Return `length(NULL)`.

### Section B — Combination (with Days 01–08)

26. Active customers with no phone number.
27. Customers with a loyalty tier but no city.
28. German customers with a phone number recorded.
29. Customers with no birth date **or** no phone.
30. Customers with neither a city nor a loyalty tier.
31. Employees in Sales who have a commission percentage, highest commission
    first.
32. Employees who are **not** in Sales and have no commission.
33. Orders from 2024 placed without a salesperson.
34. Orders with a salesperson that were cancelled or returned.
35. Products with a supplier, in stock, not discontinued, priced over 100.
36. Full names of customers with no city, concatenated with their country.
37. Every customer's name and city — and for the two without a city, note what
    the concatenated `name || ', ' || city` column shows.
38. Customers not in Berlin, **including** those with no city (use
    `IS DISTINCT FROM`). How many rows, and how does it differ from `<>`?
39. Products not from supplier 4, including the one with no supplier.
40. Employees whose commission is not 0.040, including those with no commission.
41. Count of customers whose city is Berlin, whose city is not Berlin, and
    whose city is NULL. Verify the three sum to 24.
42. Count of orders with a salesperson, without one, and the total. Verify.
43. The 5 most expensive products that have a supplier.
44. Distinct countries among customers who have no phone number.
45. Distinct loyalty tiers among customers with a city recorded.
46. The most expensive product per category, restricted to products that have a
    supplier (`DISTINCT ON`).
47. Employees' names and `salary * commission_pct` as `commission` — which rows
    are blank and why?
48. Customers' names and their age in days as `current_date - birth_date` —
    which rows are blank and why?
49. Show every customer with three boolean columns: `city IS NULL`,
    `phone IS NULL`, `birth_date IS NULL`. Order so that the customers missing
    the most data appear first. (Hint: you can order by a boolean.)
50. Which customers are missing *both* phone and city? Answer with one query.

### Section C — Recall (Days 01–08)

51. Products in category 3 or 4, priced under 600, in stock.
52. The 3 highest-paid Sales employees.
53. Distinct order statuses that are not `delivered`.
54. How many rows in `payments`?
55. Concatenate `'SKU-'` with each `product_id`.
56. Compute `(price - cost) / price` for product 1 only.
57. Orders that are neither cancelled nor returned — count them.
58. `pg_typeof(NULL)`. What do you get, and why?
59. The cheapest in-stock product in each category.
60. Reset the database and verify the nine counts.

### Section D — Challenge

61. Prove, with three counts that sum to 24, that `= 'Berlin'`,
    `<> 'Berlin'` and `IS NULL` exhaustively partition `customers`.
62. Prove that `loyalty_tier = 'gold' OR loyalty_tier <> 'gold'` does **not**
    return all 24 customers, then fix it so it does — two different ways.
63. Explain why `WHERE NOT (city = 'Berlin')` returns 20 rows rather than 22,
    and rewrite it so it returns 22.
64. `SELECT count(*) FROM customers WHERE phone IS NULL;` gives 5.
    `SELECT count(phone) FROM customers;` gives 19. Explain the relationship.
    (You haven't been taught `count(col)`. Run it, then reason it out.)
65. Construct a value that is an empty string and one that is NULL, in one
    query, and show four different tests that distinguish them.
66. Two employees have `commission_pct` of `0.040`. Write a query returning
    every employee whose commission is *not* 0.040 — and make sure the seven
    with no commission are included. How many rows should there be?
67. `SELECT 1 WHERE 5 NOT IN (1, 2, NULL);` returns zero rows. Expand the
    expression by hand into `AND`s of `<>` and explain, using the truth table,
    exactly which cell produces the empty result.
68. `is_active` in `customers` is `NOT NULL`. Write the two queries
    `WHERE NOT is_active` and `WHERE is_active IS NOT TRUE`, confirm they agree
    here, and explain in one sentence the circumstance under which they would
    disagree.
69. Design question, no query required: `orders.employee_id` is nullable and
    means "no salesperson". Name one alternative design that removes the NULL,
    and state one disadvantage of that alternative.
70. Using only what you know today, write a single query that lists every
    customer along with a text column reading either the customer's city or the
    word `unknown`. (`COALESCE` is Day 17 and `CASE` is Day 17 — so this is
    genuinely hard with today's tools. Try for ten minutes, then read the
    solution, which explains why the honest answer is "wait for Day 17".)

---

## Solutions

### Section A

**1.** `SELECT * FROM customers WHERE city IS NULL;` → 2 (customers 7, 18)
**2.** `SELECT * FROM customers WHERE city IS NOT NULL;` → 22
**3.** `SELECT * FROM customers WHERE phone IS NULL;` → 5 (3, 7, 13, 18, 22)
**4.** `SELECT * FROM customers WHERE birth_date IS NULL;` → 2 (4, 13)
**5.** `SELECT * FROM customers WHERE loyalty_tier IS NULL;` → 4 (8, 11, 18, 22)
**6.** `SELECT * FROM customers WHERE loyalty_tier IS NOT NULL;` → 20
**7.** `SELECT * FROM products WHERE supplier_id IS NULL;` → 1 (Webcam HD)
**8.** `SELECT * FROM products WHERE supplier_id IS NOT NULL;` → 24
**9.** `SELECT * FROM orders WHERE employee_id IS NULL;` → 6
**10.** `SELECT * FROM orders WHERE employee_id IS NOT NULL;` → 54
**11.** `SELECT * FROM employees WHERE manager_id IS NULL;` → 1 (Sofia Lindqvist)
**12.** `SELECT * FROM employees WHERE manager_id IS NOT NULL;` → 11
**13.** `SELECT * FROM employees WHERE commission_pct IS NULL;` → 7
**14.** `SELECT * FROM employees WHERE commission_pct IS NOT NULL;` → 5
**15.** `SELECT * FROM suppliers WHERE contact_email IS NULL;` → 1 (Nordic Home
Goods)
**16.** 2 + 22 = 24 ✓
**17.** 7 + 5 = 12 ✓
**18.** `SELECT NULL = NULL;` → `NULL`. Two unknown values cannot be shown to be
equal, so the answer is itself unknown.
**19.** `SELECT NULL IS NOT DISTINCT FROM NULL;` → `true`
**20.** `SELECT 1 IS DISTINCT FROM NULL;` → `true`
**21.** `SELECT NULL IS TRUE, NULL IS FALSE, NULL IS NOT TRUE;` → f, f, t
**22.** `SELECT true AND NULL, false AND NULL, true OR NULL, false OR NULL;`
→ `NULL`, `f`, `t`, `NULL`
**23.** `SELECT NOT NULL;` → `NULL`
**24.** `SELECT '' IS NULL, length('');` → `f`, `0`
**25.** `SELECT length(NULL);` → `NULL`

### Section B

**26.** `SELECT * FROM customers WHERE is_active AND phone IS NULL;` → 5 rows
(all five phone-less customers happen to be active).
**27.** `... WHERE loyalty_tier IS NOT NULL AND city IS NULL;` → 1 (Marie
Dubois — bronze, no city). Nina Petrova has neither.
**28.** `... WHERE country = 'Germany' AND phone IS NOT NULL;` → 3 (Anna, Tom,
Lucas — Hannah Schmidt has no phone).
**29.** `... WHERE birth_date IS NULL OR phone IS NULL;` → 6 rows
(3, 4, 7, 13, 18, 22 — customer 13 has both).
**30.** `... WHERE city IS NULL AND loyalty_tier IS NULL;` → 1 (Nina Petrova).
**31.**
```sql
SELECT first_name, commission_pct FROM employees
WHERE department = 'Sales' AND commission_pct IS NOT NULL
ORDER BY commission_pct DESC;
```
→ 5 rows (Tom .045, Lucia .040, Omar .040, Liam .030, Marcus .020).
**32.** `... WHERE department <> 'Sales' AND commission_pct IS NULL;` → 7 rows.
**33.**
```sql
SELECT * FROM orders
WHERE employee_id IS NULL AND order_date < DATE '2025-01-01';
```
→ 6 rows (all six salesperson-less orders are from 2024).
**34.**
```sql
SELECT * FROM orders
WHERE employee_id IS NOT NULL
  AND (status = 'cancelled' OR status = 'returned');
```
→ 3 rows (orders 4, 8, 23 — orders 14 and 35 are cancelled but had no
salesperson).
**35.**
```sql
SELECT * FROM products
WHERE supplier_id IS NOT NULL
  AND stock_quantity > 0
  AND NOT is_discontinued
  AND price > 100;
```
**36.**
```sql
SELECT first_name || ' ' || last_name || ' (' || country || ')' AS label
FROM   customers WHERE city IS NULL;
```
→ `Marie Dubois (France)`, `Nina Petrova (Russia)`.
**37.**
```sql
SELECT first_name, city, first_name || ', ' || city AS combined
FROM   customers;
```
The two city-less rows show a blank `combined` — the NULL propagates through
`||` and destroys the whole string, including the part that was known.
**38.**
```sql
SELECT count(*) FROM customers WHERE city IS DISTINCT FROM 'Berlin';  -- 22
SELECT count(*) FROM customers WHERE city <> 'Berlin';                -- 20
```
`IS DISTINCT FROM` counts the two NULL-city customers as "not Berlin", which is
what a human means. `<>` returns `UNKNOWN` for them and drops them.
**39.** `SELECT * FROM products WHERE supplier_id IS DISTINCT FROM 4;` → 21
rows (25 − 4 from supplier 4, and Webcam HD is *included*).
**40.** `SELECT * FROM employees WHERE commission_pct IS DISTINCT FROM 0.040;`
→ 10 rows (12 − the 2 with exactly 0.040; the 7 NULLs are included).
**41.**
```sql
SELECT count(*) FROM customers WHERE city = 'Berlin';     --  2
SELECT count(*) FROM customers WHERE city <> 'Berlin';    -- 20
SELECT count(*) FROM customers WHERE city IS NULL;        --  2
```
2 + 20 + 2 = 24 ✓
**42.** 54 + 6 = 60 ✓
**43.**
```sql
SELECT product_name, price FROM products
WHERE supplier_id IS NOT NULL ORDER BY price DESC LIMIT 5;
```
**44.**
```sql
SELECT DISTINCT country FROM customers WHERE phone IS NULL ORDER BY country;
```
→ France, Germany, Russia, South Korea, USA.
**45.**
```sql
SELECT DISTINCT loyalty_tier FROM customers WHERE city IS NOT NULL
ORDER BY loyalty_tier;
```
→ 5 rows including NULL (customers 8, 11 and 22 have a city but no tier).
**46.**
```sql
SELECT DISTINCT ON (category_id) category_id, product_name, price
FROM   products WHERE supplier_id IS NOT NULL
ORDER  BY category_id, price DESC;
```
**47.**
```sql
SELECT first_name, salary, commission_pct,
       salary * commission_pct AS commission
FROM   employees;
```
Seven blank rows — everyone outside Sales. Multiplying by NULL gives NULL.
**48.**
```sql
SELECT first_name, birth_date, current_date - birth_date AS age_days
FROM   customers;
```
Two blank rows — customers 4 and 13 have no birth date.
**49.**
```sql
SELECT first_name, last_name,
       city       IS NULL AS no_city,
       phone      IS NULL AS no_phone,
       birth_date IS NULL AS no_birth_date
FROM   customers
ORDER  BY (city IS NULL) DESC,
          (phone IS NULL) DESC,
          (birth_date IS NULL) DESC;
```
Booleans sort `false` before `true`, so `DESC` puts the missing-data rows first.
A cleaner version adds the three booleans as integers — but that needs `CASE`
(Day 17) or a cast, e.g. `(city IS NULL)::int + (phone IS NULL)::int + ...`,
which you *can* write today. Try it.
**50.** `SELECT * FROM customers WHERE phone IS NULL AND city IS NULL;` → 2
(Marie Dubois, Nina Petrova).

### Section C

**51.** `SELECT * FROM products WHERE (category_id = 3 OR category_id = 4) AND price < 600 AND stock_quantity > 0;`
**52.** `SELECT * FROM employees WHERE department = 'Sales' ORDER BY salary DESC LIMIT 3;`
**53.** `SELECT DISTINCT status FROM orders WHERE status <> 'delivered' ORDER BY status;`
**54.** 56
**55.** `SELECT 'SKU-' || product_id FROM products;`
**56.** `SELECT (price - cost) / price FROM products WHERE product_id = 1;`
→ 0.2627…
**57.** `SELECT count(*) FROM orders WHERE status <> 'cancelled' AND status <> 'returned';` → 55
**58.** `SELECT pg_typeof(NULL);` → `text`. A bare `NULL` has no type, so
PostgreSQL resolves the `unknown` literal to `text` by default. Cast it if the
type matters: `pg_typeof(NULL::integer)` → `integer`. This occasionally causes
surprising function-overload resolution.
**59.**
```sql
SELECT DISTINCT ON (category_id) category_id, product_name, price
FROM products WHERE stock_quantity > 0 ORDER BY category_id, price;
```
**60.** `\i 99_reset.sql`

### Section D

**61.** Shown in B41: 2 + 20 + 2 = 24. The key insight is that the first two
counts alone do **not** partition the table, because `UNKNOWN` rows fall out of
both. Any exhaustive analysis of a nullable column needs the third branch.

**62.**
```sql
SELECT count(*) FROM customers
WHERE loyalty_tier = 'gold' OR loyalty_tier <> 'gold';              -- 20
```
Fix A — add the missing branch:
```sql
WHERE loyalty_tier = 'gold' OR loyalty_tier <> 'gold' OR loyalty_tier IS NULL;
```
Fix B — use null-safe comparison:
```sql
WHERE loyalty_tier IS NOT DISTINCT FROM 'gold'
   OR loyalty_tier IS DISTINCT FROM 'gold';
```
Both give 24. Fix B is the one to reach for in real code, because it stays
correct if the condition later becomes more complex.

**63.** `NOT (city = 'Berlin')` evaluates `city = 'Berlin'` to `UNKNOWN` for the
two NULL rows, and `NOT UNKNOWN` is still `UNKNOWN` — so they are discarded.
`NOT` never converts unknown into true. Fix:
```sql
WHERE city IS DISTINCT FROM 'Berlin';          -- 22
-- or
WHERE NOT (city = 'Berlin') OR city IS NULL;   -- 22
```

**64.** `count(phone)` counts only the **non-NULL** values of `phone`: 24 − 5 =
19. `count(*)` counts rows regardless: 24. The relationship
`count(*) = count(col) + count(*) WHERE col IS NULL` always holds, and it is the
cleanest way to explain the difference in an interview. Day 19 makes this
formal.

**65.**
```sql
SELECT ''::text            AS empty,
       NULL::text          AS nul,
       '' IS NULL          AS empty_is_null,     -- f
       NULL::text IS NULL  AS null_is_null,      -- t
       length('')          AS len_empty,         -- 0
       length(NULL::text)  AS len_null,          -- NULL
       '' = ''             AS empty_eq_empty,    -- t
       NULL::text = NULL   AS null_eq_null;      -- NULL
```
Four distinguishing tests: `IS NULL`, `length()`, self-equality, and
concatenation behaviour (`'' || 'x'` = `'x'`, but `NULL || 'x'` = `NULL`).

**66.**
```sql
SELECT first_name, commission_pct FROM employees
WHERE commission_pct IS DISTINCT FROM 0.040;
```
→ **10 rows**. Twelve employees, minus Lucia and Omar at exactly 0.040. The
seven with no commission are included, which is what "not 0.040" means in
plain English. Writing `commission_pct <> 0.040` gives only 3 rows and quietly
loses seven people from your payroll report.

**67.** `5 NOT IN (1, 2, NULL)` expands to:

```
NOT (5 = 1 OR 5 = 2 OR 5 = NULL)
  = NOT (FALSE OR FALSE OR UNKNOWN)
  = NOT (UNKNOWN)                     ← OR table: FALSE OR UNKNOWN = UNKNOWN
  = UNKNOWN                           ← NOT table: NOT UNKNOWN = UNKNOWN
```

The deciding cell is **`FALSE OR UNKNOWN = UNKNOWN`**. If even one element of a
`NOT IN` list is NULL, the whole expression can never be `TRUE`, so the query
returns nothing — no matter what the other values are. This is why
`NOT IN (SELECT ...)` against a nullable column is a notorious production bug,
and why `NOT EXISTS` is the safe alternative. Day 37 and Day 38.

**68.**
```sql
SELECT count(*) FROM customers WHERE NOT is_active;            -- 2
SELECT count(*) FROM customers WHERE is_active IS NOT TRUE;    -- 2
```
They agree because `is_active` is declared `NOT NULL`. They would disagree the
moment the column became nullable: a row with `is_active = NULL` gives
`NOT NULL` = `UNKNOWN` (excluded) but `IS NOT TRUE` = `TRUE` (included). Since
"not active" almost always means "false or we don't know", `IS NOT TRUE` is the
safer spelling for nullable flags.

**69.** Alternative design: create a sentinel employee row — e.g. a "Self
Service" pseudo-employee — and make `employee_id` `NOT NULL` referencing it.

*Advantage:* every query that joins to `employees` behaves uniformly; no
outer joins needed; no NULL-handling in reports.

*Disadvantage:* you have inserted a fake row into a table of real people. Every
headcount query, every payroll export and every "list all employees" screen must
now remember to exclude it — and eventually one of them won't. You have traded
an explicit NULL for an implicit magic value, which is usually a worse trade.
Magic sentinel values are a recognised anti-pattern, and you'll meet them again
on Day 107.

The honest answer to "should this be nullable?" is usually: **yes, when the
absence is genuinely meaningful**, and the discipline is to handle it
explicitly at every read site.

**70.** With today's tools, you cannot do this cleanly. The nearest thing is:

```sql
SELECT first_name,
       city,
       city IS NULL AS city_unknown
FROM   customers;
```

…which reports the absence rather than substituting for it. A hack using
concatenation almost works and then doesn't:

```sql
SELECT first_name, city || '' AS attempt FROM customers;   -- still NULL
```

The real answer is one line, and it is Day 17:

```sql
SELECT first_name, COALESCE(city, 'unknown') AS city FROM customers;
```

Spending ten minutes failing at this is the point of the exercise. `COALESCE`
will feel obvious and necessary when you meet it, rather than being one more
function on a list — and you will remember that NULL substitution is a
*deliberate decision at the read site*, not something the database does for you.

---

## Day 09 Checklist

- [ ] I can state what `NULL` means, and three situations it represents
- [ ] I know `NULL` is not zero, not `''`, and not `false`
- [ ] I can reproduce the `AND`, `OR` and `NOT` truth tables from memory
- [ ] I know `WHERE` keeps only `TRUE`, discarding `FALSE` **and** `UNKNOWN`
- [ ] I always use `IS NULL` / `IS NOT NULL`, never `= NULL`
- [ ] I know `IS NULL` + `IS NOT NULL` always partitions a table exactly
- [ ] I know any `<>` on a nullable column silently loses rows
- [ ] I can use `IS DISTINCT FROM` and say when it's the right tool
- [ ] I know `NOT UNKNOWN` is `UNKNOWN` — `NOT` cannot rescue a NULL
- [ ] I know `DISTINCT`, `GROUP BY` and `ORDER BY` treat NULLs as equal, and why
      that doesn't contradict `NULL = NULL`
- [ ] I know why `NOT IN` with a NULL in the list returns zero rows
- [ ] I have written at least three lines in `mistakes.md` today

---

## What's next

**Day 10 — `IN`, `NOT IN` and `BETWEEN`.** The shorthand that replaces long
chains of `OR`, and the range operator that replaces two comparisons. Both are
conveniences — and `NOT IN` carries the NULL trap you saw a preview of today,
which is exactly why it comes *after* this day rather than before it.
