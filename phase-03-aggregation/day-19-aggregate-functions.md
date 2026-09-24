# Day 19 — Aggregate Functions

> **Phase** 3 · Aggregation
> **Level** Absolute Beginner → Confident Beginner
> **Time** 110–140 minutes
> **Prerequisites** Days 01–18
> **New concepts** The shape change (N rows → 1 row) · `count(*)` · `count(column)` · `count(DISTINCT column)` · `sum` · `avg` · `min` · `max` · aggregates skip NULLs · empty-set behaviour · aggregates cannot appear in `WHERE` · the "must appear in GROUP BY" error
>
> ⚠️ **Today is whole-table aggregates only.** `GROUP BY` is tomorrow. Every
> query today returns exactly **one row**.

---

## Why this matters

Every query you have written in eighteen days has had the same shape: **one
output row per input row**. Filter 25 products down to 5, and you get 5 rows.
Add a computed column, still 5 rows.

Today that breaks. An aggregate function takes **many rows and returns one
value**. That single change is what turns SQL from a data-retrieval language
into an analysis language — and it is the foundation of everything in the next
four phases.

It also brings the most-asked beginner interview question in existence:
*what is the difference between `COUNT(*)` and `COUNT(column)`?* You already
know the answer, because it is a `NULL` question and you spent twelve days on
`NULL`.

---

## Part 1 — The shape change

```sql
SELECT product_name FROM products;          -- 25 rows
SELECT count(*)     FROM products;          --  1 row
```

```
 count
-------
    25
(1 row)
```

Twenty-five rows went in. One row came out. Read that `(1 row)` at the bottom —
it is the whole lesson.

You have been using `count(*)` since Day 3 as a sanity check. Today it becomes a
tool, and it gains five siblings.

| Function | Returns |
|---|---|
| `count(*)` | how many rows |
| `count(expr)` | how many rows where `expr` is **not NULL** |
| `sum(expr)` | total |
| `avg(expr)` | mean |
| `min(expr)` | smallest |
| `max(expr)` | largest |

All six collapse the entire input into **one row**.

```sql
SELECT count(*)   AS n_products,
       sum(price) AS total_price,
       avg(price) AS mean_price,
       min(price) AS cheapest,
       max(price) AS dearest
FROM   products;
```

```
 n_products | total_price |     mean_price      | cheapest | dearest
------------+-------------+---------------------+----------+---------
         25 |     8130.38 |            325.2152 |    29.99 | 1899.00
```

Five numbers describing 25 rows. Note there is no `product_name` column —
there *can't* be. Which of the 25 names would it show? That question is the
subject of Part 6, and its answer is tomorrow's topic.

▶ **Try it** — run it. Then run `SELECT * FROM products;` and satisfy yourself
that the five numbers describe what you see.

---

## Part 2 — `count(*)` vs `count(column)`

This is the one that matters.

```sql
SELECT count(*)            AS all_rows,
       count(city)         AS with_city,
       count(phone)        AS with_phone,
       count(birth_date)   AS with_birth_date,
       count(loyalty_tier) AS with_tier
FROM   customers;
```

```
 all_rows | with_city | with_phone | with_birth_date | with_tier
----------+-----------+------------+-----------------+-----------
       24 |        22 |         19 |              22 |        20
```

Four different answers from one table of 24 rows.

> **`count(*)` counts rows. `count(expr)` counts rows where `expr` is not
> `NULL`.**

That's it. That's the entire distinction, and it follows directly from Day 9.

The relationship always holds:

```
count(*)  =  count(col)  +  (number of rows where col IS NULL)
```

Verify it:

```sql
SELECT count(*)                                     AS total,        -- 24
       count(phone)                                 AS non_null,     -- 19
       count(*) - count(phone)                      AS nulls;        --  5
```

And cross-check against Day 9:

```sql
SELECT count(*) FROM customers WHERE phone IS NULL;   -- 5 ✓
```

⚠️ **Trap** — `count(*)` is the only aggregate with a `*`. There is no
`sum(*)` or `avg(*)`; those need a column, because "the sum of a row" is
meaningless.

💡 **`count(1)` is not faster than `count(*)`.** You will see `count(1)` in old
codebases and hear it defended on performance grounds. In PostgreSQL the planner
treats them identically — `count(*)` does not fetch any column. Write
`count(*)`; it says what it means. (This is folklore inherited from other
database systems, some of which were genuinely different decades ago.)

🎯 **Interview** — "Difference between `COUNT(*)` and `COUNT(col)`?" Expected
answer: rows vs non-NULL values of that column. A strong follow-up answer adds:
"and `COUNT(DISTINCT col)` counts distinct non-NULL values", plus the
observation that this is why `count(*)` and `count(col)` disagree on exactly the
number of NULLs.

---

## Part 3 — `count(DISTINCT ...)`

```sql
SELECT count(*)                 AS rows,
       count(country)           AS non_null_countries,
       count(DISTINCT country)  AS distinct_countries
FROM   customers;
```

```
 rows | non_null_countries | distinct_countries
------+--------------------+--------------------
   24 |                 24 |                 19
```

24 customers, spread across 19 countries. `country` is `NOT NULL`, so the first
two agree.

Compare with Day 5's `DISTINCT`:

```sql
SELECT DISTINCT country FROM customers;   -- 19 rows, one per country
SELECT count(DISTINCT country) FROM customers;   -- 1 row, the number 19
```

Same information, different shape. `DISTINCT` **lists**; `count(DISTINCT ...)`
**counts**.

⚠️ **`count(DISTINCT col)` also skips NULLs:**

```sql
SELECT count(DISTINCT loyalty_tier) FROM customers;   -- 4, not 5
SELECT DISTINCT loyalty_tier FROM customers;          -- 5 rows, incl. NULL
```

`DISTINCT` as a clause treats `NULL` as a value worth listing. `count(DISTINCT
...)` as an aggregate skips it. The two disagree by exactly one, and it catches
people every time.

💡 **Performance note for later:** `count(DISTINCT x)` cannot use a hash
aggregate in the same way a plain `count(*)` can, and on tens of millions of
rows it is markedly slower. Day 80 covers the approximate alternative
(`HyperLogLog` via the `postgres_hll` extension) for when "roughly how many
distinct users" is good enough.

---

## Part 4 — Aggregates skip NULLs, and what that costs you

Every aggregate ignores `NULL` inputs. This is convenient, and occasionally
wrong.

```sql
SELECT count(*)            AS employees,       -- 12
       count(commission_pct) AS with_commission, -- 5
       sum(commission_pct)   AS total_commission,
       avg(commission_pct)   AS mean_commission
FROM   employees;
```

```
 employees | with_commission | total_commission | mean_commission
-----------+-----------------+------------------+-----------------------
        12 |               5 |            0.175 | 0.03500000000000000000
```

Read `mean_commission` carefully. It is **0.035**, which is `0.175 / 5` — the
average over the **five** employees who have a commission, not over all twelve.

Is that right? It depends entirely on the question:

- *"What is the average commission rate among commissioned staff?"* → 0.035. ✅
- *"What is the average commission rate across the company?"* → 0.175 / 12 =
  0.0146. ❌ `avg` will not give you this.

`avg` answers the first question. If you want the second, you must say so:

```sql
SELECT avg(commission_pct)                  AS avg_among_earners,   -- 0.0350
       avg(COALESCE(commission_pct, 0))     AS avg_across_company,  -- 0.0146
       sum(commission_pct) / count(*)       AS same_thing_again     -- 0.0146
FROM   employees;
```

> **The rule: `avg(x)` is `sum(x) / count(x)`, never `sum(x) / count(*)`.**

This is the single most common source of quietly wrong averages in business
reporting. A dashboard says "average discount: 8%" when it means "average
discount among orders that had one" — and every order without a discount has
been excluded from the denominator.

⚠️ **`sum` is safer than `avg` here**, because a skipped NULL contributes
nothing to a sum. `sum(commission_pct)` is 0.175 whether you treat missing as
NULL or as zero. It is only the **denominator** that changes, so only `avg`
and `count` are affected.

▶ **Try it** — run all three columns above and convince yourself the two
answers differ, then say out loud which one a manager asking "what's our average
commission?" actually wants. (They almost always mean the second, and they are
almost always shown the first.)

---

## Part 5 — The empty set

What happens when nothing matches?

```sql
SELECT count(*)   AS n,
       sum(price) AS total,
       avg(price) AS mean,
       min(price) AS lo,
       max(price) AS hi
FROM   products
WHERE  price > 999999;
```

```
 n | total | mean | lo | hi
---+-------+------+----+----
 0 | ␀     | ␀    | ␀  | ␀
```

**One row still comes back.** Not zero rows — one row, containing:

| Aggregate over an empty set | Returns |
|---|---|
| `count(*)`, `count(col)` | **0** |
| `sum`, `avg`, `min`, `max` | **NULL** |

`count` returns zero because "how many? none" is a definite answer. `sum`
returns NULL because "the total of nothing" is genuinely undefined — the SQL
standard chose NULL over 0, and this is the source of a specific, expensive bug:

```sql
-- a report that should show 0.00 shows blank instead
SELECT sum(amount) FROM payments WHERE status = 'failed';   -- NULL, not 0.00
```

The fix is `COALESCE`, and you should apply it reflexively to any `sum` whose
result gets displayed or fed into further arithmetic:

```sql
SELECT COALESCE(sum(amount), 0) AS failed_total FROM payments WHERE status = 'failed';
```

⚠️ Worse, remember Day 9: `NULL` poisons arithmetic. So
`sum(a) + sum(b)` becomes `NULL` if *either* sum is over an empty set — even if
the other is a perfectly good number.

🎯 **Interview** — "What does `SELECT sum(x) FROM t WHERE false` return?" →
One row containing `NULL`. Candidates who say "zero rows" or "0" have not
thought about it. The follow-up — "and `count(*)`?" — is `0`, and explaining
*why they differ* is the real test.

---

## Part 6 — Two errors you must be able to read

### Error 1 — aggregates cannot go in `WHERE`

```sql
SELECT product_name FROM products WHERE price > avg(price);
```

```
ERROR:  aggregate functions are not allowed in WHERE
LINE 1: SELECT product_name FROM products WHERE price > avg(price);
                                                        ^
```

Why? Recall Day 7: `WHERE` is evaluated **per row**, before anything is
aggregated. When `WHERE` runs, there is no "average" yet — the rows it is
filtering are the very rows the average would be computed from. The question is
circular.

There are two real answers, and you don't have either yet:

- **`HAVING`** (Day 21) filters *after* aggregation — but it filters groups, not
  individual rows.
- **A subquery** (Day 36) computes the average separately, then compares:
  `WHERE price > (SELECT avg(price) FROM products)`.

For today, just recognise the error and know that wanting it is reasonable.

### Error 2 — mixing an aggregate with a plain column

```sql
SELECT product_name, avg(price) FROM products;
```

```
ERROR:  column "products.product_name" must appear in the GROUP BY clause
        or be used in an aggregate function
```

This is the error you will see more than any other in the next three days, so
read it properly now.

`avg(price)` produces **one** value for the whole table. `product_name` has
**25** values. PostgreSQL cannot put 25 things and 1 thing in the same row, and
it will not guess which of the 25 you meant.

The error message even tells you both escape routes:

1. **"appear in the `GROUP BY` clause"** — split the table into groups so that
   one name goes with one average. That's **tomorrow**.
2. **"or be used in an aggregate function"** — wrap it, e.g.
   `max(product_name)`, so it also collapses to one value.

```sql
SELECT max(product_name) AS last_alphabetically,
       avg(price)        AS mean_price
FROM   products;
```

That runs — both columns are now aggregates. Whether `max(product_name)` means
anything useful is a different question. (It doesn't, here.)

💡 **Remember this error message.** When it appears tomorrow, it will be because
you forgot a column in `GROUP BY`, and recognising it instantly saves you
minutes each time.

---

## Part 7 — `min` and `max` work on more than numbers

```sql
SELECT min(product_name) AS first_alphabetically,
       max(product_name) AS last_alphabetically
FROM   products;
```

```
 first_alphabetically |  last_alphabetically
----------------------+------------------------
 Blender 500W         | Wireless Mouse
```

`min`/`max` work on anything with an ordering — text, dates, timestamps,
booleans.

```sql
SELECT min(order_date) AS first_order,
       max(order_date) AS latest_order,
       max(order_date) - min(order_date) AS days_of_history
FROM   orders;
```

```
 first_order | latest_order | days_of_history
-------------+--------------+-----------------
 2024-01-08  | 2025-07-07   |             545
```

That last column reuses Day 15's `date - date` → integer. Aggregates compose
with everything you already know.

```sql
SELECT min(signup_date) AS earliest_customer,
       max(signup_date) AS newest_customer
FROM   customers;
```

⚠️ **Trap** — `min`/`max` on text uses **collation order**, which in `shopdb`
is `C`. So `max(product_name)` puts all lowercase-starting names after all
uppercase-starting ones. With this dataset every name starts with a capital, so
you won't notice — but it is the Day 5 collation lesson lying in wait.

⚠️ **Do not confuse `max()` with `GREATEST()`.** Day 17's `GREATEST(a, b, c)`
compares **columns within one row**. `max(col)` compares **rows within one
column**. They look similar and do entirely different things:

```sql
SELECT GREATEST(price, cost) FROM products;   -- 25 rows, one per product
SELECT max(price)            FROM products;   --  1 row, the largest price
```

🎯 **Interview** — "`MAX` vs `GREATEST`?" Vertical vs horizontal. This gets
asked because candidates who have only read documentation tend to conflate them.

---

## Part 8 — Aggregates with everything you already know

Aggregates sit on top of every tool from Phases 1 and 2.

**With `WHERE`** — aggregate only the rows that matter:

```sql
SELECT count(*)   AS in_stock_products,
       avg(price) AS mean_price,
       sum(price * stock_quantity) AS inventory_value
FROM   products
WHERE  stock_quantity > 0
  AND  NOT is_discontinued;
```

**With expressions inside the aggregate:**

```sql
SELECT sum(quantity * unit_price * (1 - discount_pct)) AS gross_revenue
FROM   order_items;
```

That is the total value of every order line ever sold — the line-total formula
you have written twenty times, now summed. Round it:

```sql
SELECT round(sum(quantity * unit_price * (1 - discount_pct)), 2) AS gross_revenue
FROM   order_items;
```

**With `CASE` inside the aggregate** — this is a genuinely powerful pattern and
it gets a full treatment on Day 22:

```sql
SELECT count(*) AS all_orders,
       sum(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) AS delivered,
       sum(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled
FROM   orders;
```

```
 all_orders | delivered | cancelled
------------+-----------+-----------
         60 |        47 |         3
```

Three counts of the same table, in one pass, with one `WHERE`-less query. That
is **conditional aggregation**, and once you see it you will use it constantly.

**With date functions:**

```sql
SELECT count(*) AS orders_2024
FROM   orders
WHERE  order_date >= DATE '2024-01-01'
  AND  order_date <  DATE '2025-01-01';
```

**Nesting is not allowed:**

```sql
SELECT max(avg(price)) FROM products;
```

```
ERROR:  aggregate function calls cannot be nested
```

"The maximum of the average" is meaningless over one group. Once you have
groups (tomorrow) you may genuinely want "the highest group average", and the
way to get it is a subquery (Day 39) or a window function (Day 46).

---

## Reference

| Aggregate | Skips NULL? | Empty set | Notes |
|---|---|---|---|
| `count(*)` | n/a | `0` | counts rows |
| `count(expr)` | yes | `0` | counts non-NULL values |
| `count(DISTINCT expr)` | yes | `0` | distinct non-NULL values |
| `sum(expr)` | yes | **`NULL`** | wrap in `COALESCE` for display |
| `avg(expr)` | yes | **`NULL`** | denominator is `count(expr)` |
| `min(expr)` | yes | **`NULL`** | works on text, dates, booleans |
| `max(expr)` | yes | **`NULL`** | not the same as `GREATEST` |

💡 **Return types worth knowing:** `count` returns `bigint`.
`avg` on an `integer` column returns `numeric` (so no integer-division
surprise — `avg(rating)` on the integers 1–5 gives `4.1111…`, not `4`).
`sum` on `integer` returns `bigint`; on `numeric` it returns `numeric`.

---

## Traps & Gotchas

| # | Trap | What happens |
|---|---|---|
| 1 | `count(col)` where you meant `count(*)` | Silently under-counts by the number of NULLs |
| 2 | `avg(col)` with NULLs present | Denominator excludes them — usually not what's wanted |
| 3 | `sum` over an empty set | `NULL`, not `0`. Use `COALESCE` |
| 4 | `sum(a) + sum(b)` where one is empty | Whole expression is `NULL` |
| 5 | `count(DISTINCT col)` vs `SELECT DISTINCT col` | Differ by one when NULLs exist |
| 6 | Aggregate in `WHERE` | Error — `HAVING` (Day 21) or a subquery (Day 36) |
| 7 | Mixing an aggregate with a bare column | `must appear in the GROUP BY clause` |
| 8 | Nesting aggregates | `cannot be nested` |
| 9 | Confusing `max()` with `GREATEST()` | Vertical vs horizontal |
| 10 | Believing `count(1)` is faster | It isn't, in PostgreSQL |

---

## Interview angles

- **Junior** — "How many customers do we have?" → `SELECT count(*) FROM customers;`
- **Junior** — "`COUNT(*)` vs `COUNT(col)`?" → rows vs non-NULL values.
- **Junior** — "Average order value?" → and then the follow-up: *average over
  what denominator?*
- **Mid** — "`SELECT sum(x) FROM t WHERE false` — what comes back?" → one row,
  `NULL`.
- **Mid** — "Your dashboard shows average discount 8%, finance says 3%. Why?" →
  `avg` skips NULLs; orders with no discount are excluded from the denominator.
  Fix with `avg(COALESCE(discount, 0))`.
- **Mid** — "Why can't I put an aggregate in `WHERE`?" → `WHERE` runs per row,
  before aggregation; the reference would be circular. Use `HAVING` or a
  subquery.
- **Senior** — "`count(*)` on a 500-million-row table takes 40 seconds. Options?"
  → PostgreSQL has no stored row count (MVCC means row visibility is per
  transaction), so an exact count is always a full scan or index-only scan.
  Options: `reltuples` from `pg_class` for an estimate, a maintained counter
  table updated by trigger, or accepting the estimate. Explaining *why* the
  count is expensive — visibility, not laziness — is the answer that lands.
  Day 73 and Day 84.
- **Senior** — "`count(DISTINCT user_id)` over a billion rows?" → Expensive;
  consider `postgres_hll` for an approximate distinct count, or a pre-aggregated
  rollup table. Day 80, Day 103.

---

## Practice

> Available: everything from Days 1–18, plus `count`, `sum`, `avg`, `min`,
> `max`, `count(DISTINCT ...)`.
> **Not yet:** `GROUP BY` (Day 20), `HAVING` (Day 21), `FILTER` (Day 22).
> **Every query today returns exactly one row.**

### Section A — Drill (new concept only)

1. How many products are there?
2. How many customers?
3. How many orders?
4. How many order items?
5. How many payments?
6. How many reviews?
7. How many employees?
8. The total of all product prices.
9. The average product price.
10. The cheapest and dearest product price, in one row.
11. The total stock across all products.
12. The average stock per product.
13. The total, average, minimum and maximum employee salary, in one row.
14. How many customers have a recorded city?
15. How many customers have a recorded phone?
16. How many customers have a recorded birth date?
17. How many customers have a recorded loyalty tier?
18. How many products have a supplier?
19. How many orders have a salesperson?
20. How many employees have a manager?
21. How many employees have a commission percentage?
22. How many distinct countries appear in `customers`?
23. How many distinct loyalty tiers appear in `customers`? Compare with
    `SELECT DISTINCT loyalty_tier` and explain the difference.
24. How many distinct statuses appear in `orders`?
25. How many distinct products appear in `order_items`?
26. The earliest and latest `order_date`, in one row.
27. The earliest and latest `signup_date`.
28. The first and last product name alphabetically.
29. The total and average `helpful_votes` across all reviews.
30. The average review rating.

### Section B — Combination (with Days 01–18)

31. How many products are in stock **and** not discontinued?
32. The average price of in-stock products only.
33. The total inventory value (`price * stock_quantity`) across all products,
    rounded to 2 decimals.
34. The total inventory value of in-stock, non-discontinued products.
35. Total gross revenue from all order lines
    (`quantity * unit_price * (1 - discount_pct)`), rounded to 2 decimals.
36. Total gross revenue from order lines that had a discount.
37. The total amount discounted across all order lines
    (`quantity * unit_price * discount_pct`), rounded.
38. How many orders were placed in 2024? In 2025?  (Two queries.)
39. How many orders are `delivered`?
40. How many payments were captured, and how many refunded? (Two queries.)
41. The total captured payment amount, rounded.
42. The average payment amount, rounded to 2 decimals.
43. The total shipping cost collected across all orders.
44. The average shipping cost, rounded to 2 decimals.
45. The number of distinct shipping countries.
46. The average salary of Sales employees.
47. The average salary of non-Sales employees.
48. The average commission percentage among those who have one, and across the
    whole company, in one row.
49. The number of customers who signed up in 2024.
50. The number of days between the first and last order.
51. The average age of customers at 2025-01-01, in whole years.
52. The average product name length.
53. The number of products whose name contains `laptop`, any case.
54. Using conditional aggregation, show in one row: total orders, delivered,
    cancelled, pending.
55. Using conditional aggregation, show in one row: total products, in-stock
    count, out-of-stock count.

### Section C — Recall (Days 01–18)

56. Products in categories 3 or 4 priced under 700, correctly parenthesised.
57. Customers with no city, showing name and country.
58. `supplier_id NOT IN (1, 2)` — the count, and why it isn't 16.
59. Payments in December 2024, using a half-open range.
60. `round(2.5::numeric)` versus `round(2.5::float8)`.
61. Every customer's email domain via `split_part`.
62. `concat_ws('-', 'a', NULL, 'b')` versus `'a' || NULL || 'b'`.
63. The last day of the month containing `2024-02-10`.
64. Label products `premium` / `mid-range` / `budget` / `accessory`.
65. Reset the database and verify the nine row counts.

### Section D — Challenge

66. Prove, with one query, that
    `count(*) = count(phone) + (rows where phone IS NULL)` for `customers`.
67. Show in one row the average commission computed two ways — among earners
    and across the company — and explain which one a manager asking "what's our
    average commission?" means.
68. `SELECT sum(price) FROM products WHERE price > 999999;` returns what? Now
    make it return `0.00`.
69. Show that `sum(a) + sum(b)` becomes `NULL` when one of the two is over an
    empty set, using `payments` and a status that doesn't exist.
70. Run `SELECT product_name, avg(price) FROM products;`. Read the error
    message carefully and write down, in your own words, both escape routes it
    offers.
71. Run `SELECT count(*) FROM products WHERE price > avg(price);`. Read the
    error. Explain in one sentence why the request is circular.
72. `count(DISTINCT loyalty_tier)` gives 4 but `SELECT DISTINCT loyalty_tier`
    gives 5 rows. Write both, and explain the discrepancy in one sentence.
73. Compute the average order line value two ways: `avg(line_total)` and
    `sum(line_total) / count(*)`. Are they equal? Under what condition would
    they differ?
74. Without `GROUP BY`, produce a one-row summary of `orders` containing: total
    orders, distinct customers who ordered, distinct salespeople involved,
    earliest order, latest order, and total shipping revenue.
75. Design question: a colleague wants a `products.review_count` column, updated
    whenever a review is added, "because `count(*)` is slow". Argue both sides.
    What would you need to know before deciding?

---

## Solutions

### Section A

**1.** `SELECT count(*) FROM products;` → 25
**2.** → 24  **3.** → 60  **4.** → 105  **5.** → 56  **6.** → 36  **7.** → 12
**8.** `SELECT sum(price) FROM products;` → 8130.38
**9.** `SELECT avg(price) FROM products;` → 325.2152
**10.** `SELECT min(price), max(price) FROM products;` → 29.99, 1899.00
**11.** `SELECT sum(stock_quantity) FROM products;` → 1145
**12.** `SELECT avg(stock_quantity) FROM products;` → 45.8 (1145 / 25). Note
`avg` on an `integer` column returns `numeric`, so there is no integer-division
surprise.
**13.**
```sql
SELECT sum(salary), avg(salary), min(salary), max(salary) FROM employees;
```
→ 798500.00, 66541.666…, 36500.00, 185000.00
**14.** `SELECT count(city) FROM customers;` → 22
**15.** `SELECT count(phone) FROM customers;` → 19
**16.** `SELECT count(birth_date) FROM customers;` → 22
**17.** `SELECT count(loyalty_tier) FROM customers;` → 20
**18.** `SELECT count(supplier_id) FROM products;` → 24
**19.** `SELECT count(employee_id) FROM orders;` → 54
**20.** `SELECT count(manager_id) FROM employees;` → 11
**21.** `SELECT count(commission_pct) FROM employees;` → 5
**22.** `SELECT count(DISTINCT country) FROM customers;` → 19
**23.** `SELECT count(DISTINCT loyalty_tier) FROM customers;` → **4**, but
`SELECT DISTINCT loyalty_tier FROM customers;` → **5 rows**. The aggregate skips
NULL; the clause lists it as a value.
**24.** `SELECT count(DISTINCT status) FROM orders;` → 6
**25.** `SELECT count(DISTINCT product_id) FROM order_items;` → 22 (25 products
minus the 3 never ordered).
**26.** `SELECT min(order_date), max(order_date) FROM orders;` → 2024-01-08,
2025-07-07
**27.** `SELECT min(signup_date), max(signup_date) FROM customers;` →
2022-08-17, 2025-04-05
**28.** `SELECT min(product_name), max(product_name) FROM products;` →
`Blender 500W`, `Wireless Mouse`
**29.** `SELECT sum(helpful_votes), avg(helpful_votes) FROM reviews;` → 954,
26.5
**30.** `SELECT avg(rating) FROM reviews;` → 4.1111… (148 / 36)

### Section B

**31.** `SELECT count(*) FROM products WHERE stock_quantity > 0 AND NOT is_discontinued;` → 21
**32.** `SELECT avg(price) FROM products WHERE stock_quantity > 0;`
**33.** `SELECT round(sum(price * stock_quantity), 2) FROM products;`
**34.** Same with `WHERE stock_quantity > 0 AND NOT is_discontinued;`
**35.**
```sql
SELECT round(sum(quantity * unit_price * (1 - discount_pct)), 2) AS gross_revenue
FROM   order_items;
```
**36.** Same, with `WHERE discount_pct > 0;`
**37.** `SELECT round(sum(quantity * unit_price * discount_pct), 2) FROM order_items;`
**38.**
```sql
SELECT count(*) FROM orders WHERE order_date >= DATE '2024-01-01' AND order_date < DATE '2025-01-01';  -- 52
SELECT count(*) FROM orders WHERE order_date >= DATE '2025-01-01';                                      --  8
```
**39.** `SELECT count(*) FROM orders WHERE status = 'delivered';` → 47
**40.** 54 captured, 2 refunded.
**41.** `SELECT round(sum(amount), 2) FROM payments WHERE status = 'captured';`
**42.** `SELECT round(avg(amount), 2) FROM payments;`
**43.** `SELECT sum(shipping_cost) FROM orders;` → 354.36
**44.** `SELECT round(avg(shipping_cost), 2) FROM orders;` → 5.91
**45.** `SELECT count(DISTINCT shipping_country) FROM orders;`
**46.** `SELECT avg(salary) FROM employees WHERE department = 'Sales';` → 61200.00
**47.** `SELECT avg(salary) FROM employees WHERE department <> 'Sales';` → 76071.43 (run it)
**48.**
```sql
SELECT avg(commission_pct)              AS among_earners,
       avg(COALESCE(commission_pct, 0)) AS across_company
FROM   employees;
```
→ 0.0350 and 0.014583…
**49.** `SELECT count(*) FROM customers WHERE signup_date >= DATE '2024-01-01' AND signup_date < DATE '2025-01-01';` → 8
**50.** `SELECT max(order_date) - min(order_date) FROM orders;` → 545
**51.**
```sql
SELECT avg(EXTRACT(YEAR FROM age(DATE '2025-01-01', birth_date))) FROM customers;
```
Note this averages over the 22 customers who have a birth date — the two NULLs
are skipped, which is correct here.
**52.** `SELECT avg(length(product_name)) FROM products;`
**53.** `SELECT count(*) FROM products WHERE product_name ILIKE '%laptop%';` → 4
**54.**
```sql
SELECT count(*)                                              AS total,
       sum(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) AS delivered,
       sum(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled,
       sum(CASE WHEN status = 'pending'   THEN 1 ELSE 0 END) AS pending
FROM   orders;
```
→ 60, 47, 3, 3
**55.**
```sql
SELECT count(*)                                              AS total,
       sum(CASE WHEN stock_quantity > 0  THEN 1 ELSE 0 END)  AS in_stock,
       sum(CASE WHEN stock_quantity = 0  THEN 1 ELSE 0 END)  AS out_of_stock
FROM   products;
```
→ 25, 21, 4

### Section C

**56.** `WHERE (category_id = 3 OR category_id = 4) AND price < 700;` → 3
**57.** `SELECT first_name, last_name, country FROM customers WHERE city IS NULL;`
**58.** 15 — `Webcam HD` has `supplier_id IS NULL` and satisfies neither `IN`
nor `NOT IN`.
**59.** `WHERE paid_at >= '2024-12-01' AND paid_at < '2025-01-01';`
**60.** `3` and `2`.
**61.** `SELECT split_part(email, '@', 2) FROM customers;`
**62.** `a-b` and `NULL`.
**63.** `SELECT (date_trunc('month', DATE '2024-02-10') + INTERVAL '1 month - 1 day')::date;` → 2024-02-29
**64.** The four-branch searched `CASE` from Day 17.
**65.** `\i 99_reset.sql`

### Section D

**66.**
```sql
SELECT count(*)                                   AS total,       -- 24
       count(phone)                               AS non_null,    -- 19
       count(*) - count(phone)                    AS nulls,       --  5
       sum(CASE WHEN phone IS NULL THEN 1 ELSE 0 END) AS null_check -- 5
FROM   customers;
```
The third and fourth columns agree, which is the proof. The identity
`count(*) = count(col) + nulls(col)` holds for every column of every table.

**67.** See B48. A manager asking "what's our average commission?" almost
always means **across the company** — 1.46%, not 3.5%. The 3.5% figure silently
excludes the seven employees who earn no commission, which is exactly the people
the question is usually trying to account for.

The general rule: whenever you report an `avg`, state the denominator. "Average
commission among commissioned staff" and "average commission per employee" are
different numbers and both are legitimate — but a bare "average commission" on a
dashboard will be read as the second and computed as the first.

**68.**
```sql
SELECT sum(price) FROM products WHERE price > 999999;                    -- NULL
SELECT COALESCE(sum(price), 0) FROM products WHERE price > 999999;       -- 0
SELECT COALESCE(sum(price), 0)::numeric(10,2) FROM products WHERE price > 999999; -- 0.00
```

**69.**
```sql
SELECT sum(amount) FILTER (WHERE true)                        AS ignore_this,
       (SELECT sum(amount) FROM payments WHERE status = 'captured')
     + (SELECT sum(amount) FROM payments WHERE status = 'chargeback') AS combined;
```
…except `FILTER` is Day 22 and subqueries are Day 36. With today's tools:
```sql
SELECT sum(CASE WHEN status = 'captured'   THEN amount END)
     + sum(CASE WHEN status = 'chargeback' THEN amount END) AS combined
FROM   payments;
```
→ `NULL`. There is no `chargeback` status, so the second `sum` is over an empty
set and returns `NULL`, and `34326.38 + NULL` is `NULL`. The entire figure
disappears because one of its components had no rows.

The fix is `COALESCE` on each term, not on the total:
```sql
SELECT COALESCE(sum(CASE WHEN status = 'captured'   THEN amount END), 0)
     + COALESCE(sum(CASE WHEN status = 'chargeback' THEN amount END), 0) AS combined
FROM   payments;
```
Note also: `CASE WHEN ... THEN amount END` with no `ELSE` yields `NULL` for
non-matching rows, and `sum` skips those — which is exactly what you want. That
is the neater form of conditional aggregation and it is Day 22's main idea.

**70.**
```
ERROR:  column "products.product_name" must appear in the GROUP BY clause
        or be used in an aggregate function
```
Route 1: put `product_name` in a `GROUP BY` clause, so the query returns one row
per product name with an average computed within that group. (Tomorrow.)
Route 2: wrap it in an aggregate — `max(product_name)` — so it collapses to one
value like `avg(price)` does.

The underlying reason: one column produces 25 values and the other produces 1,
and a single result row cannot hold both.

**71.**
```
ERROR:  aggregate functions are not allowed in WHERE
```
`WHERE` decides, row by row, which rows survive — and it runs **before**
anything is aggregated. To evaluate `price > avg(price)` it would need the
average of the rows that survive the filter, but the filter is what it is
currently computing. The dependency is circular.

The resolution (Day 36) is to compute the average in a **separate** query that
sees all the rows:
```sql
SELECT count(*) FROM products WHERE price > (SELECT avg(price) FROM products);
```

**72.**
```sql
SELECT count(DISTINCT loyalty_tier) FROM customers;   -- 4
SELECT DISTINCT loyalty_tier FROM customers;          -- 5 rows
```
`count(DISTINCT x)` is an aggregate, and every aggregate skips `NULL` inputs.
`DISTINCT` as a clause treats `NULL` as a value and returns one row for it. They
will always differ by exactly one when the column contains any NULL.

**73.**
```sql
SELECT avg(quantity * unit_price * (1 - discount_pct))               AS via_avg,
       sum(quantity * unit_price * (1 - discount_pct)) / count(*)    AS via_sum
FROM   order_items;
```
They are **equal here**, because no component of the expression is `NULL` —
`quantity`, `unit_price` and `discount_pct` are all `NOT NULL`, so every one of
the 105 rows contributes.

They would differ the moment the expression could be `NULL` for some row: `avg`
divides by `count(expr)` (non-NULL rows only) while `count(*)` counts all rows.
Make `discount_pct` nullable and set one row to `NULL`, and `via_avg` divides by
104 while `via_sum` divides by 105.

That is the whole of Part 4 restated: **`avg` and `count(*)` disagree about the
denominator whenever NULLs are present.**

**74.**
```sql
SELECT count(*)                       AS total_orders,        -- 60
       count(DISTINCT customer_id)    AS distinct_customers,  -- 20
       count(DISTINCT employee_id)    AS distinct_sellers,    --  4
       min(order_date)                AS first_order,
       max(order_date)                AS latest_order,
       sum(shipping_cost)             AS shipping_revenue     -- 354.36
FROM   orders;
```
Note `count(DISTINCT customer_id)` is 20, not 24 — four customers have never
ordered, and they cannot appear in a table they have no rows in. Finding *those*
customers requires reaching into `customers` from a query over `orders`, which
is an **anti-join**, Day 29. Notice the limit; it is the shape of what Phase 4
unlocks.

**75.** **The case for the counter column:** an exact `count(*)` in PostgreSQL
always costs a scan, because MVCC means row visibility depends on the querying
transaction — there is no single stored row count the way MyISAM had. On a
product page rendering a review count for every item in a 50-item grid, that is
50 counts per page load. Precomputing is a legitimate denormalization.

**The case against:** you now have two sources of truth that can drift. Every
insert, delete, soft-delete, moderation-hide and bulk import must maintain it.
The obvious implementation — a trigger — adds write contention on the `products`
row, turning independent review inserts into a queue behind a single hot row
(Day 86). And "slow" is doing a lot of work in the premise.

**What I'd need to know before deciding:**

1. **Is it actually slow?** `EXPLAIN (ANALYZE, BUFFERS)` on the real query at
   real data volume. An index on `reviews(product_id)` may make the count an
   index-only scan and end the conversation. Optimising un-measured slowness is
   how systems accumulate complexity for nothing. (Days 74–76.)
2. **How many reviews per product?** Counting 40 rows is free; counting 4
   million is not.
3. **Write rate.** A hot product receiving 100 reviews a second through a
   trigger is a contention problem you did not previously have.
4. **Does it need to be exact?** A "roughly 1.2k reviews" badge tolerates a
   stale figure that a materialized view (Day 90) refreshed every minute would
   serve perfectly, with no write-path coupling at all.

My default answer is: **measure first, then reach for an index, then a
materialized view, and only then a trigger-maintained counter** — because each
step adds coupling that the previous one didn't. But a counter column is a
legitimate and common design, and refusing it on principle is as wrong as
adopting it on reflex.

---

## Day 19 Checklist

- [ ] I understand that an aggregate turns N rows into 1 row
- [ ] **I know `count(*)` counts rows and `count(col)` counts non-NULL values**
- [ ] I know `count(*) = count(col) + nulls(col)` always holds
- [ ] I know `count(DISTINCT col)` skips NULL while `SELECT DISTINCT` doesn't
- [ ] **I know `avg(x)` divides by `count(x)`, not `count(*)`**
- [ ] I know `sum` over an empty set returns `NULL`, not `0`
- [ ] I wrap displayed sums in `COALESCE`
- [ ] I know aggregates cannot appear in `WHERE`, and why
- [ ] I recognise `must appear in the GROUP BY clause` and know both escape
      routes
- [ ] I know `max()` is vertical and `GREATEST()` is horizontal
- [ ] I can write conditional aggregation with `CASE` inside `sum`

---

## What's next

**Day 20 — `GROUP BY`.** Today every query returned one row describing the whole
table. Tomorrow you split the table into groups and get one row per group — the
single biggest jump in expressive power in this program. The
`must appear in the GROUP BY clause` error you met today becomes the error you
will read most often for the next week, and by the end of tomorrow it will take
you two seconds to fix.
