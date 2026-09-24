# Day 20 — `GROUP BY`

> **Phase** 3 · Aggregation
> **Level** Confident Beginner
> **Time** 120–150 minutes
> **Prerequisites** Days 01–19
> **New concepts** `GROUP BY` · one row per group · the grouping rule · grouping by an expression · grouping by `date_trunc` · `NULL` as its own group · groups that don't appear · `GROUP BY` vs `DISTINCT` · clause order · `ORDER BY` on an aggregate
>
> ⚠️ **`HAVING` is tomorrow.** Today you can filter rows *before* grouping with
> `WHERE`, but not filter the groups themselves.

---

## Why this matters

Yesterday: *"what is the average product price?"* → one number.
Today: *"what is the average product price **in each category**?"* → one number
per category.

That's `GROUP BY`, and it is the biggest single jump in expressive power in this
program. Almost every business question is a grouped question — revenue *per
month*, orders *per customer*, headcount *per department*. Once `GROUP BY` is
automatic, you can answer most of what anyone will ever ask of a single table.

---

## Part 1 — Splitting the table into groups

```sql
SELECT category_id,
       count(*) AS n_products
FROM   products
GROUP  BY category_id
ORDER  BY category_id;
```

```
 category_id | n_products
-------------+------------
           1 |          4
           3 |          3
           4 |          3
           6 |          3
           7 |          3
           9 |          4
          10 |          5
(7 rows)
```

Seven rows. 4 + 3 + 3 + 3 + 3 + 4 + 5 = 25 — every product accounted for, once.

**The mental model:**

```
1. FROM products           →  25 rows
2. GROUP BY category_id    →  sort the 25 rows into piles, one pile per
                              distinct category_id.  Seven piles.
3. SELECT count(*)         →  for EACH pile, compute the aggregates.
                              Emit one row per pile.
```

> **One row out per distinct value of the grouping column.**

That sentence is worth memorising. It immediately tells you how many rows a
grouped query will return, before you run it — and predicting the row count is
rule L3.

### Add the other aggregates

Every aggregate from Day 19 now works *per group*:

```sql
SELECT category_id,
       count(*)   AS n,
       sum(price) AS total,
       round(avg(price), 2) AS mean,
       min(price) AS cheapest,
       max(price) AS dearest
FROM   products
GROUP  BY category_id
ORDER  BY category_id;
```

```
 category_id | n | total  |  mean   | cheapest | dearest
-------------+---+--------+---------+----------+---------
           1 | 4 | 966.00 |  241.50 |    89.00 |  429.00
           3 | 3 |3547.00 | 1182.33 |   549.00 | 1899.00
           4 | 3 |1997.00 |  665.67 |   299.00 |  999.00
           6 | 3 | 269.97 |   89.99 |    59.99 |  129.99
           7 | 3 | 897.00 |  299.00 |   149.00 |  499.00
           9 | 4 | 174.45 |   43.61 |    34.95 |   55.00
          10 | 5 | 278.96 |   55.79 |    29.99 |   89.99
```

Yesterday's whole-table `sum(price)` was 8130.38. Add this column up and you get
8130.38 — the same total, now broken down. **Grouping partitions; it never
loses or duplicates.** That invariant is your best sanity check on any grouped
query: the group totals must sum to the ungrouped total.

▶ **Try it** — run both and verify the sum yourself. Do it now; this habit
catches real bugs in Phase 4.

---

## Part 2 — The grouping rule

This is the rule that generates the error you met yesterday.

> **Every column in the `SELECT` list must either appear in `GROUP BY`, or be
> wrapped in an aggregate function.**

```sql
SELECT category_id, product_name, count(*)
FROM   products
GROUP  BY category_id;
```

```
ERROR:  column "products.product_name" must appear in the GROUP BY clause
        or be used in an aggregate function
```

Same message as yesterday, and the same reason. Category 10 is one group
containing five products. `count(*)` gives one number for that group — but
`product_name` has five different values in it. PostgreSQL will not pick one
arbitrarily, and it will not silently return five rows.

Three legitimate fixes:

```sql
-- 1. group by it too  (now one row per (category, name) pair — 25 rows)
SELECT category_id, product_name, count(*)
FROM products GROUP BY category_id, product_name;

-- 2. aggregate it
SELECT category_id, max(product_name) AS last_alphabetically, count(*)
FROM products GROUP BY category_id;

-- 3. drop it
SELECT category_id, count(*) FROM products GROUP BY category_id;
```

Fix 1 is worth running: grouping by a column that is nearly unique produces
almost as many groups as rows, and every `count(*)` is 1. That is a grouped
query doing nothing useful, and it's a common beginner mistake — adding a column
to `GROUP BY` just to silence the error, and destroying the aggregation in the
process.

> ⚠️ **Never add a column to `GROUP BY` merely to make the error go away.**
> Ask first whether you wanted one row per that column. Usually you didn't —
> you wanted it *aggregated*, or you wanted it gone.

💡 **Why PostgreSQL is strict here.** MySQL historically allowed
`SELECT a, b FROM t GROUP BY a`, silently returning an arbitrary `b`. That
produces plausible, unreproducible, wrong reports. PostgreSQL refuses, and this
strictness is a feature. (There is one narrow exception — if you group by a
table's primary key, PostgreSQL can prove every other column is functionally
dependent on it and allows them without listing. That becomes useful in Phase 4.)

🎯 **Interview** — "Why must every non-aggregated column be in `GROUP BY`?"
Because a group is many rows collapsed to one, and a non-aggregated column has
no single defined value within the group. Mentioning the functional-dependency
exception for primary keys marks you as someone who has read the rules rather
than absorbed them by osmosis.

---

## Part 3 — `NULL` gets its own group

```sql
SELECT loyalty_tier,
       count(*) AS n
FROM   customers
GROUP  BY loyalty_tier
ORDER  BY loyalty_tier;
```

```
 loyalty_tier | n
--------------+---
 bronze       | 7
 gold         | 5
 platinum     | 2
 silver       | 6
 ␀            | 4
(5 rows)
```

**Five** groups, not four. All four customers with no tier land in one `NULL`
group.

This is Day 9's asymmetry again: `NULL = NULL` is unknown, but `GROUP BY`,
`DISTINCT` and `ORDER BY` all treat NULLs as *equal to one another* for the
purpose of bucketing. The standard calls it "not distinct from" semantics.

Contrast with yesterday:

```sql
SELECT count(DISTINCT loyalty_tier) FROM customers;    -- 4  (aggregate skips NULL)
SELECT loyalty_tier FROM customers GROUP BY loyalty_tier;  -- 5 rows (NULL is a group)
```

Label it for a report using Day 17's tools:

```sql
SELECT COALESCE(loyalty_tier, 'no tier') AS tier,
       count(*) AS n
FROM   customers
GROUP  BY loyalty_tier          -- group by the raw column
ORDER  BY n DESC;
```

You may also group by the `COALESCE` expression itself — see Part 5.

⚠️ **Trap** — `GROUP BY` on a nullable column always produces a group you
weren't thinking about. If a report has an unexplained extra row with a blank
label, that's it.

---

## Part 4 — Groups that don't appear

Look again at Part 1's output. Categories **2, 5 and 8 are missing**.

They exist in `categories` — Computers, Home & Living, Books — but no product
has them as a direct `category_id` (they're parent categories). And `GROUP BY`
can only make a group from a value that **exists in the rows being grouped**.

> **`GROUP BY` never invents groups.** A category with no products produces no
> row. A month with no orders produces no row. A customer with no orders
> produces no row.

This is one of the most consequential facts in reporting, because it produces
**silent gaps**:

```sql
SELECT date_trunc('month', order_date)::date AS month,
       count(*) AS orders
FROM   orders
GROUP  BY date_trunc('month', order_date)
ORDER  BY month;
```

Nineteen rows — January 2024 through July 2025. But if a month had *no* orders
at all, it would simply be absent, and a chart drawn from this data would join
the two neighbouring months with a straight line as though nothing had
happened. Revenue didn't drop to zero on your chart; the zero is just not there.

The fixes, both later:

- **`generate_series`** to build a complete list of months and `LEFT JOIN` the
  data onto it (Days 29 and 43).
- A **calendar table** joined the same way (Day 64).

For today: know that absence is invisible, and check for it.

▶ **Try it** — run the query above and count the rows. Then reason about which
months *could* have been missing if the data were sparser.

🎯 **Interview** — "Your monthly revenue chart skips March. Why?" → No rows for
March, so `GROUP BY` produced no group. Fix by generating the month series and
left-joining. This is asked constantly in analytics interviews, because it is
the most common real bug in dashboards.

---

## Part 5 — Grouping by an expression

The grouping key doesn't have to be a bare column. Anything you can compute, you
can group by.

**By month** — the most useful one you will ever write:

```sql
SELECT date_trunc('month', order_date)::date AS month,
       count(*)           AS orders,
       sum(shipping_cost) AS shipping
FROM   orders
GROUP  BY date_trunc('month', order_date)
ORDER  BY month;
```

Note the `GROUP BY` repeats the expression **without** the `::date` cast, and
the `SELECT` has it. Both work; they just have to describe the same grouping.
Simplest is to make them identical:

```sql
GROUP BY date_trunc('month', order_date)::date
```

💡 Recall Day 15: group by `date_trunc('month', ...)`, **never**
`EXTRACT(MONTH ...)`. The latter merges January 2024 with January 2025. Prove it
to yourself:

```sql
SELECT EXTRACT(MONTH FROM order_date)::int AS month_only, count(*)
FROM orders GROUP BY 1 ORDER BY 1;                         -- 12 rows

SELECT date_trunc('month', order_date)::date AS month, count(*)
FROM orders GROUP BY 1 ORDER BY 1;                         -- 19 rows
```

Twelve versus nineteen. The twelve-row version has silently added two Januaries
together.

**By a `CASE` expression** — grouping into bands:

```sql
SELECT CASE WHEN price >= 1000 THEN 'premium'
            WHEN price >= 300  THEN 'mid-range'
            WHEN price >= 50   THEN 'budget'
            ELSE                    'accessory' END AS band,
       count(*)             AS n,
       round(avg(price), 2) AS mean_price
FROM   products
GROUP  BY 1
ORDER  BY mean_price DESC;
```

**By a derived value:**

```sql
SELECT split_part(email, '@', 2) AS domain, count(*) AS n
FROM   customers
GROUP  BY split_part(email, '@', 2);
```

**By year:**

```sql
SELECT EXTRACT(YEAR FROM signup_date)::int AS signup_year, count(*) AS n
FROM   customers
GROUP  BY EXTRACT(YEAR FROM signup_date)
ORDER  BY signup_year;
```

→ 2022: 3, 2023: 9, 2024: 8, 2025: 4. Sums to 24 ✓

### `GROUP BY` can use a position number, or a `SELECT` alias

```sql
SELECT category_id, count(*) FROM products GROUP BY 1;            -- position
SELECT category_id AS cat, count(*) FROM products GROUP BY cat;   -- alias 🐘
```

Both work in PostgreSQL. The alias form is a PostgreSQL extension — **`WHERE`
still cannot see an alias, but `GROUP BY` can.** (Day 21 explains why: `GROUP
BY` is evaluated after the `SELECT` list's expressions are known, `WHERE` is
not.)

⚠️ Positional `GROUP BY 1` is compact and fragile for the same reason
`ORDER BY 1` is: insert a column and every position shifts. Fine at the prompt;
avoid it in code that ships — except for long `CASE` expressions, where
repeating the whole thing is genuinely worse.

---

## Part 6 — Grouping by more than one column

```sql
SELECT department,
       job_title,
       count(*)   AS n,
       round(avg(salary), 2) AS mean_salary
FROM   employees
GROUP  BY department, job_title
ORDER  BY department, job_title;
```

One row per **distinct combination** — nine rows for twelve employees, because
some share a title.

This is the same "combination" rule as `SELECT DISTINCT a, b` on Day 5. The
number of groups is the number of distinct *pairs* that actually occur, not
`distinct(a) × distinct(b)`.

Day 22 goes further with multi-key grouping. Today, just note that the comma
works and that order in the `GROUP BY` clause doesn't affect *which* groups you
get (only `ORDER BY` controls presentation).

---

## Part 7 — Clause order, and where `GROUP BY` sits

```sql
SELECT   columns and aggregates
FROM     table
WHERE    row filter            ← runs BEFORE grouping
GROUP BY grouping keys
ORDER BY sort keys             ← can use aggregate aliases
LIMIT    n;
```

**`WHERE` filters rows before they are grouped.** That is the only filtering you
have today, and it is often exactly right:

```sql
SELECT category_id,
       count(*)             AS n,
       round(avg(price), 2) AS mean_price
FROM   products
WHERE  NOT is_discontinued
  AND  stock_quantity > 0
GROUP  BY category_id
ORDER  BY mean_price DESC;
```

*"Average price per category, counting only sellable products."* The
discontinued and out-of-stock rows are removed **before** the piles are made, so
they affect neither the counts nor the averages.

⚠️ You still cannot write `WHERE count(*) > 3` — that filters *groups*, and it
is tomorrow's `HAVING`.

### `ORDER BY` an aggregate

```sql
SELECT category_id, count(*) AS n
FROM   products
GROUP  BY category_id
ORDER  BY n DESC, category_id;
```

```
 category_id | n
-------------+---
          10 | 5
           1 | 4
           9 | 4
           3 | 3
           4 | 3
           6 | 3
           7 | 3
```

Sorting by the aggregate is how you answer "which is the biggest?" — and note
the tie-breaker `category_id`, because categories 1 and 9 both have 4, and
without it their relative order is undefined (Day 5).

You can also sort by an aggregate you don't display:

```sql
SELECT category_id FROM products GROUP BY category_id ORDER BY count(*) DESC;
```

Legal, and occasionally confusing to read. Show the number.

---

## Part 8 — `GROUP BY` vs `DISTINCT`

```sql
SELECT DISTINCT country FROM customers;              -- 19 rows
SELECT country FROM customers GROUP BY country;      -- 19 rows
```

Identical results. PostgreSQL will often produce the identical plan
(a `HashAggregate`) for both.

So which do you write?

| Want | Use |
|---|---|
| Just the distinct values | `DISTINCT` — it says what it means |
| Distinct values **plus a number about each** | `GROUP BY` |

```sql
SELECT country, count(*) AS n FROM customers GROUP BY country ORDER BY n DESC;
```

`DISTINCT` cannot do that at all. The moment you want to know *how many* of
each, you need `GROUP BY`.

> Rule of thumb: if you find yourself writing `SELECT DISTINCT` and then
> wondering how many of each there are, you wanted `GROUP BY` all along.

---

## Part 9 — Worked examples on real questions

These are the shapes you'll reuse for the next hundred days.

**Orders per customer:**

```sql
SELECT customer_id, count(*) AS orders
FROM   orders
GROUP  BY customer_id
ORDER  BY orders DESC, customer_id;
```

20 rows. Top: customer 3 with 7 orders, then customers 1 and 6 with 6 each.

⚠️ Twenty rows, not 24 — the four customers who never ordered have no rows in
`orders`, so they cannot form a group. Part 4's lesson, in the wild. Listing
them requires an anti-join, Day 29.

**Revenue per order:**

```sql
SELECT order_id,
       round(sum(quantity * unit_price * (1 - discount_pct)), 2) AS order_total
FROM   order_items
GROUP  BY order_id
ORDER  BY order_total DESC
LIMIT  5;
```

Sixty rows before the `LIMIT` — one per order. **This is the "order total"
query you have been unable to write since Day 3**, and it is the single most
reused query in this database.

**Orders per salesperson, including the self-service group:**

```sql
SELECT employee_id, count(*) AS orders
FROM   orders
GROUP  BY employee_id
ORDER  BY orders DESC NULLS LAST;
```

```
 employee_id | orders
-------------+--------
           6 |     17
           5 |     16
           7 |     11
          12 |     10
           ␀ |      6
```

Five groups: four salespeople plus the `NULL` group of self-service orders.
16 + 17 + 11 + 10 + 6 = 60 ✓

**Payments by method:**

```sql
SELECT method,
       count(*)              AS n,
       round(sum(amount), 2) AS total
FROM   payments
GROUP  BY method
ORDER  BY total DESC;
```

Five rows: card 37, paypal 9, bank_transfer 5, gift_card 3, cash_on_delivery 2.
Sums to 56 ✓

**Reviews per rating:**

```sql
SELECT rating, count(*) AS n
FROM   reviews
GROUP  BY rating
ORDER  BY rating DESC;
```

Four rows — 5:15, 4:13, 3:5, 2:3. **No row for rating 1**, because no
one-star review exists. Part 4 again.

**Monthly order volume and shipping revenue:**

```sql
SELECT date_trunc('month', order_date)::date AS month,
       count(*)                              AS orders,
       round(sum(shipping_cost), 2)          AS shipping
FROM   orders
GROUP  BY 1
ORDER  BY month;
```

---

## Traps & Gotchas

| # | Trap | What happens |
|---|---|---|
| 1 | Non-aggregated column not in `GROUP BY` | `must appear in the GROUP BY clause` |
| 2 | Adding a column to `GROUP BY` to silence the error | Destroys the aggregation; one row per row |
| 3 | Forgetting `NULL` forms its own group | An unexplained extra row with a blank label |
| 4 | Expecting every category/month to appear | `GROUP BY` never invents groups — silent gaps |
| 5 | `GROUP BY EXTRACT(MONTH ...)` across years | Januaries merged |
| 6 | `WHERE count(*) > 3` | Error — that's `HAVING`, Day 21 |
| 7 | `GROUP BY 1` then editing the `SELECT` list | Grouping key silently changes |
| 8 | No tie-breaker in `ORDER BY count(*) DESC` | Tied groups in arbitrary order |
| 9 | Assuming group count = rows in the lookup table | Only values present in the data form groups |
| 10 | Grouped totals not summing to the ungrouped total | You filtered in one and not the other — check `WHERE` |

---

## Interview angles

- **Junior** — "Count products per category." →
  `SELECT category_id, count(*) FROM products GROUP BY category_id;`
- **Junior** — "Why must non-aggregated columns be in `GROUP BY`?" → A group is
  many rows collapsed to one; the column has no single value.
- **Mid** — "Revenue by month." → `date_trunc('month', d)`, and explain why not
  `EXTRACT(MONTH ...)`.
- **Mid** — "Your monthly chart is missing a month. Why?" → No rows → no group.
  Generate the series and left-join.
- **Mid** — "`GROUP BY` vs `DISTINCT`?" → Equivalent for de-duplication, often
  the same plan; `GROUP BY` when you also want an aggregate.
- **Mid** — "Does `GROUP BY` put NULLs in one group or drop them?" → One group.
  Contrast with `count(col)`, which skips them.
- **Senior** — "How does Postgres execute a `GROUP BY`?" → Either
  `HashAggregate` (build a hash table keyed by the grouping columns — fast, but
  needs `work_mem`, and spills to disk in batches if it doesn't fit) or
  `GroupAggregate` (requires sorted input, so it's chosen when a sort is free,
  e.g. from an index). You'll see both in `EXPLAIN` on Day 77.
- **Senior** — "A `GROUP BY` on 200 million rows is spilling to disk. Options?"
  → Raise `work_mem` for that session; reduce the number of groups; pre-
  aggregate into a rollup table or materialized view; consider whether an
  approximate answer suffices. Days 78, 90, 98.

---

## Practice

> Available: everything from Days 1–19, plus `GROUP BY`.
> **Not yet:** `HAVING` (Day 21), `FILTER` (Day 22), joins (Day 27).
> For each problem, **predict the row count before you run it.**

### Section A — Drill (new concept only)

1. Number of products per `category_id`.
2. Number of products per `supplier_id`. How many groups, and why one of them
   is blank.
3. Number of customers per `country`.
4. Number of customers per `loyalty_tier`. How many rows, and why?
5. Number of employees per `department`.
6. Number of orders per `status`.
7. Number of orders per `customer_id`.
8. Number of orders per `employee_id`.
9. Number of order items per `order_id`.
10. Number of reviews per `rating`.
11. Number of reviews per `product_id`.
12. Number of payments per `method`.
13. Number of payments per `status`.
14. Total `price` per `category_id`.
15. Average `price` per `category_id`, rounded to 2 decimals.
16. Minimum and maximum `price` per `category_id`.
17. Total `stock_quantity` per `category_id`.
18. Average `salary` per `department`, rounded.
19. Minimum and maximum `salary` per `department`.
20. Total `shipping_cost` per `status` in `orders`.
21. Average `rating` per `product_id`, rounded to 2 decimals.
22. Total `helpful_votes` per `rating`.
23. Total `amount` per payment `method`.
24. Number of employees per `department` and `job_title`.
25. Number of customers per `country` and `loyalty_tier`.

### Section B — Combination (with Days 01–19)

26. Number of products per category, **most products first**, with a
    tie-breaker.
27. Average price per category, **highest average first**.
28. Number of products per category, counting only in-stock,
    non-discontinued products.
29. Total inventory value (`price * stock_quantity`) per category, rounded,
    highest first.
30. Total revenue per `order_id` using the line-total formula, rounded, top 10.
31. Total quantity sold per `product_id`, highest first, top 10.
32. Total revenue per `product_id`, rounded, top 10.
33. Number of orders per month, using `date_trunc`.
34. Total shipping cost per month, rounded.
35. Number of orders per year.
36. Number of customers per signup year.
37. Number of orders per `shipping_country`, most first.
38. Number of products per price band (`premium`/`mid-range`/`budget`/
    `accessory`), with average price per band.
39. Number of customers per email domain.
40. Number of employees per `commission_pct`, including the NULL group.
41. Average salary per department, but only for employees hired before 2022.
42. Number of orders per customer, for 2024 orders only.
43. Number of order items per order, for orders with more than one item —
    (you can't filter groups yet; instead show all and eyeball it).
44. Average review rating per product, only counting reviews with more than 10
    helpful votes.
45. Number of reviews per customer.
46. Total revenue per month from `order_items`, joined to nothing — group by
    `order_id` first and note why monthly revenue is not yet possible.
47. Number of products per category, with the category shown as
    `'Category ' || category_id`.
48. Number of customers per country, showing `COALESCE(city, 'unknown')` is
    *not* what's being grouped — group by country only, but also show the count
    of customers with a city.
49. Number of orders per ISO weekday.
50. Average order `shipping_cost` per status, rounded, most expensive first.
51. Number of products per supplier, showing `COALESCE(supplier_id::text, 'none')`.
52. Distinct countries per loyalty tier (`count(DISTINCT country)`).
53. Number of distinct products ordered per order.
54. Total and average payment amount per month.
55. Number of reviews per rating, with the rating shown as stars using
    `repeat('*', rating)`.

### Section C — Recall (Days 01–19)

56. Whole-table: count, sum, avg, min, max of `products.price`.
57. `count(*)` vs `count(city)` on `customers`, and the difference explained.
58. `sum(price)` over an empty set — what and why?
59. Products in categories 3 or 4 priced under 700.
60. Customers with no loyalty tier.
61. Payments in December 2024, half-open range.
62. `concat_ws('-', 'a', NULL, 'b')`.
63. The last day of the month containing `2024-02-10`.
64. `round(2.5::numeric)` versus `round(2.5::float8)`.
65. Reset the database and verify the nine row counts.

### Section D — Challenge

66. Prove that the per-category `sum(price)` values add up to the whole-table
    `sum(price)`. Write both queries and compare.
67. Run `SELECT category_id, product_name, count(*) FROM products GROUP BY category_id;`
    Read the error. Then write three different queries that fix it, and say what
    each one now means.
68. `GROUP BY category_id` gives 7 rows but `categories` has 10 rows. Explain
    in one sentence, and name which three categories are missing and why.
69. Show, with two queries, that grouping by `EXTRACT(MONTH FROM order_date)`
    gives 12 rows while `date_trunc('month', order_date)` gives 19, and explain
    which is correct for a revenue report.
70. `GROUP BY loyalty_tier` gives 5 rows but `count(DISTINCT loyalty_tier)`
    gives 4. Write both and explain the discrepancy.
71. Number of orders per customer gives 20 rows, but there are 24 customers.
    Explain. Then state what you would need to list all 24 with zeroes.
72. Write the "order total" query (revenue per `order_id`) and verify one order
    by hand against `SELECT * FROM order_items WHERE order_id = 30;`.
73. Group `orders` by month and count them. Are any months missing from the
    range 2024-01 to 2025-07? Write the query, count the rows, and work out
    which months (if any) have no orders.
74. Produce a per-category summary showing: category id, product count, in-stock
    count, out-of-stock count, and total inventory value — using conditional
    aggregation, in one pass.
75. Design question: a colleague writes
    `SELECT customer_id, first_name, count(*) FROM orders GROUP BY customer_id;`
    and is confused that it errors, "because `first_name` is determined by
    `customer_id` anyway". Explain why PostgreSQL rejects it, why MySQL
    historically accepted it, and what the correct query is.

---

## Solutions

### Section A

**1.** `SELECT category_id, count(*) FROM products GROUP BY category_id ORDER BY category_id;` → 7 rows
**2.** `SELECT supplier_id, count(*) FROM products GROUP BY supplier_id ORDER BY supplier_id;`
→ **7 rows**: suppliers 1–6 plus a `NULL` group of 1 (`Webcam HD` has no
supplier). Counts: 1→3, 2→6, 3→3, 4→4, 5→3, 6→5, NULL→1. Sums to 25 ✓
**3.** `SELECT country, count(*) FROM customers GROUP BY country ORDER BY count(*) DESC;` → 19 rows; Germany 4, India 2, France 2, the rest 1 each.
**4.** `SELECT loyalty_tier, count(*) FROM customers GROUP BY loyalty_tier;` →
**5 rows**. Four tiers plus a `NULL` group of 4. `GROUP BY` buckets NULLs
together rather than dropping them.
**5.** → 4 rows: Management 1, Sales 5, Support 3, Warehouse 3
**6.** → 6 rows: delivered 47, cancelled 3, pending 3, shipped 3, paid 2,
returned 2
**7.** → **20 rows** (not 24 — four customers have never ordered)
**8.** → **5 rows** (four salespeople plus the NULL group of 6 self-service
orders)
**9.** → 60 rows, one per order
**10.** → **4 rows** (5:15, 4:13, 3:5, 2:3 — there is no 1-star review)
**11.** → 17 rows (only 17 of 25 products have any review)
**12.** → 5 rows: card 37, paypal 9, bank_transfer 5, gift_card 3,
cash_on_delivery 2
**13.** → 2 rows: captured 54, refunded 2
**14.** `SELECT category_id, sum(price) FROM products GROUP BY category_id ORDER BY 1;`
**15.** `SELECT category_id, round(avg(price), 2) FROM products GROUP BY category_id ORDER BY 1;`
**16.** `SELECT category_id, min(price), max(price) FROM products GROUP BY category_id ORDER BY 1;`
**17.** `SELECT category_id, sum(stock_quantity) FROM products GROUP BY category_id ORDER BY 1;`
**18.** `SELECT department, round(avg(salary), 2) FROM employees GROUP BY department ORDER BY 2 DESC;`
→ Management 185000.00, Sales 61200.00, Support 54000.00, Warehouse 48500.00
**19.** `SELECT department, min(salary), max(salary) FROM employees GROUP BY department;`
**20.** `SELECT status, sum(shipping_cost) FROM orders GROUP BY status ORDER BY 2 DESC;`
**21.** `SELECT product_id, round(avg(rating), 2) FROM reviews GROUP BY product_id ORDER BY 1;`
**22.** `SELECT rating, sum(helpful_votes) FROM reviews GROUP BY rating ORDER BY rating;`
**23.** `SELECT method, round(sum(amount), 2) FROM payments GROUP BY method ORDER BY 2 DESC;`
**24.** `SELECT department, job_title, count(*) FROM employees GROUP BY department, job_title ORDER BY 1, 2;` → 9 rows
**25.** `SELECT country, loyalty_tier, count(*) FROM customers GROUP BY country, loyalty_tier ORDER BY 1, 2;`

### Section B

**26.**
```sql
SELECT category_id, count(*) AS n
FROM   products GROUP BY category_id
ORDER  BY n DESC, category_id;
```
**27.**
```sql
SELECT category_id, round(avg(price), 2) AS mean_price
FROM   products GROUP BY category_id ORDER BY mean_price DESC;
```
→ category 3 leads at 1182.33.
**28.**
```sql
SELECT category_id, count(*) AS n
FROM   products
WHERE  stock_quantity > 0 AND NOT is_discontinued
GROUP  BY category_id ORDER BY category_id;
```
**29.**
```sql
SELECT category_id, round(sum(price * stock_quantity), 2) AS inventory_value
FROM   products GROUP BY category_id ORDER BY inventory_value DESC;
```
**30.**
```sql
SELECT order_id,
       round(sum(quantity * unit_price * (1 - discount_pct)), 2) AS order_total
FROM   order_items
GROUP  BY order_id
ORDER  BY order_total DESC
LIMIT  10;
```
**31.**
```sql
SELECT product_id, sum(quantity) AS units_sold
FROM   order_items GROUP BY product_id
ORDER  BY units_sold DESC, product_id LIMIT 10;
```
**32.**
```sql
SELECT product_id,
       round(sum(quantity * unit_price * (1 - discount_pct)), 2) AS revenue
FROM   order_items GROUP BY product_id ORDER BY revenue DESC LIMIT 10;
```
**33.**
```sql
SELECT date_trunc('month', order_date)::date AS month, count(*) AS orders
FROM   orders GROUP BY 1 ORDER BY month;
```
→ 19 rows.
**34.** Same with `round(sum(shipping_cost), 2)`.
**35.** `SELECT EXTRACT(YEAR FROM order_date)::int AS yr, count(*) FROM orders GROUP BY 1 ORDER BY 1;` → 2024: 52, 2025: 8
**36.** `SELECT EXTRACT(YEAR FROM signup_date)::int AS yr, count(*) FROM customers GROUP BY 1 ORDER BY 1;` → 2022: 3, 2023: 9, 2024: 8, 2025: 4
**37.** `SELECT shipping_country, count(*) AS n FROM orders GROUP BY 1 ORDER BY n DESC, 1;`
**38.**
```sql
SELECT CASE WHEN price >= 1000 THEN 'premium'
            WHEN price >= 300  THEN 'mid-range'
            WHEN price >= 50   THEN 'budget'
            ELSE                    'accessory' END AS band,
       count(*) AS n, round(avg(price), 2) AS mean_price
FROM   products GROUP BY 1 ORDER BY mean_price DESC;
```
**39.** `SELECT split_part(email, '@', 2) AS domain, count(*) FROM customers GROUP BY 1;` → 1 row
**40.** `SELECT commission_pct, count(*) FROM employees GROUP BY commission_pct ORDER BY commission_pct NULLS LAST;` → 6 rows (5 rates + NULL group of 7)
**41.**
```sql
SELECT department, round(avg(salary), 2) AS mean_salary
FROM   employees WHERE hire_date < DATE '2022-01-01'
GROUP  BY department ORDER BY mean_salary DESC;
```
**42.**
```sql
SELECT customer_id, count(*) AS orders FROM orders
WHERE  order_date >= DATE '2024-01-01' AND order_date < DATE '2025-01-01'
GROUP  BY customer_id ORDER BY orders DESC, customer_id;
```
**43.** `SELECT order_id, count(*) AS items FROM order_items GROUP BY order_id ORDER BY items DESC, order_id;`
Orders 30 and 38 have 4 items each. Filtering to `items > 1` is `HAVING` —
tomorrow.
**44.**
```sql
SELECT product_id, round(avg(rating), 2) AS mean_rating, count(*) AS n
FROM   reviews WHERE helpful_votes > 10
GROUP  BY product_id ORDER BY mean_rating DESC, product_id;
```
**45.** `SELECT customer_id, count(*) FROM reviews GROUP BY customer_id ORDER BY 2 DESC, 1;`
**46.** You can group `order_items` by `order_id`, but `order_items` has **no
date column** — the date lives in `orders`. Monthly revenue therefore needs data
from two tables at once, which is a **join** (Day 27) and specifically
join + aggregation (Day 34). Notice the wall; it's the shape of Phase 4.
**47.** `SELECT 'Category ' || category_id AS cat, count(*) FROM products GROUP BY category_id ORDER BY category_id;`
**48.**
```sql
SELECT country, count(*) AS customers, count(city) AS with_city
FROM   customers GROUP BY country ORDER BY customers DESC, country;
```
The `count(*)` / `count(city)` pair is Day 19's distinction applied per group —
France shows 2 and 1, because Marie Dubois has no city.
**49.** `SELECT EXTRACT(ISODOW FROM order_date)::int AS weekday, count(*) FROM orders GROUP BY 1 ORDER BY 1;`
**50.** `SELECT status, round(avg(shipping_cost), 2) AS mean_shipping FROM orders GROUP BY status ORDER BY mean_shipping DESC;`
**51.** `SELECT COALESCE(supplier_id::text, 'none') AS supplier, count(*) FROM products GROUP BY supplier_id ORDER BY supplier_id NULLS LAST;`
**52.** `SELECT loyalty_tier, count(DISTINCT country) AS countries FROM customers GROUP BY loyalty_tier ORDER BY countries DESC;`
**53.** `SELECT order_id, count(DISTINCT product_id) FROM order_items GROUP BY order_id;` — always equal to `count(*)` here, because `UNIQUE (order_id, product_id)` guarantees no repeats within an order. A good example of a constraint making a query redundant.
**54.**
```sql
SELECT date_trunc('month', paid_at)::date AS month,
       round(sum(amount), 2) AS total, round(avg(amount), 2) AS mean
FROM   payments GROUP BY 1 ORDER BY month;
```
**55.** `SELECT repeat('*', rating) AS stars, count(*) FROM reviews GROUP BY rating ORDER BY rating DESC;`

### Section C

**56.** `SELECT count(*), sum(price), avg(price), min(price), max(price) FROM products;`
**57.** 24 and 22 — `count(*)` counts rows, `count(city)` counts non-NULL cities; two customers have none.
**58.** `NULL`. The sum of no rows is undefined; `count` would give 0.
**59.** `WHERE (category_id = 3 OR category_id = 4) AND price < 700;`
**60.** `WHERE loyalty_tier IS NULL;` → 4
**61.** `WHERE paid_at >= '2024-12-01' AND paid_at < '2025-01-01';`
**62.** `a-b`
**63.** `2024-02-29`
**64.** `3` and `2`
**65.** `\i 99_reset.sql`

### Section D

**66.**
```sql
SELECT sum(price) FROM products;                                    -- 8130.38
SELECT category_id, sum(price) FROM products GROUP BY category_id;  -- 7 rows
```
Adding the seven group totals gives 966.00 + 3547.00 + 1997.00 + 269.97 +
897.00 + 174.45 + 278.96 = **8130.38** ✓

This invariant — *the parts sum to the whole* — is the single best sanity check
on any grouped query. If they don't match, either a `WHERE` differs between the
two queries, or you are grouping on something that loses rows. Get in the habit
of checking it; in Phase 4 it catches join-related double-counting that is
otherwise invisible.

**67.**
```
ERROR:  column "products.product_name" must appear in the GROUP BY clause
```
Three fixes:
```sql
-- (a) group by it too: 25 rows, one per product, every count = 1.
SELECT category_id, product_name, count(*) FROM products GROUP BY category_id, product_name;

-- (b) aggregate it: 7 rows, showing the alphabetically last name per category.
SELECT category_id, max(product_name) AS last_name, count(*) FROM products GROUP BY category_id;

-- (c) drop it: 7 rows, just the counts.
SELECT category_id, count(*) FROM products GROUP BY category_id;
```
(a) is almost never what you want — it turns an aggregation into a row listing.
(b) and (c) are real answers to real questions. The point is that the three
queries answer three *different* questions, so "make the error go away" is not a
strategy; you have to decide what you were asking.

**68.** `GROUP BY` can only create a group for a value that appears in the rows
being grouped. Categories **2 (Computers), 5 (Home & Living) and 8 (Books)** are
parent categories — no product references them directly — so they produce no
rows in `products` and therefore no group. Listing all ten categories with zero
counts requires a `LEFT JOIN` from `categories` to `products`, which is Day 29.

**69.**
```sql
SELECT EXTRACT(MONTH FROM order_date)::int AS month_only, count(*)
FROM orders GROUP BY 1 ORDER BY 1;                         -- 12 rows

SELECT date_trunc('month', order_date)::date AS month, count(*)
FROM orders GROUP BY 1 ORDER BY 1;                         -- 19 rows
```
`date_trunc` is correct for a revenue report. The 12-row version discards the
year, so January 2024 and January 2025 are added together and labelled
"month 1" — a report that looks fine and is wrong, and that only becomes wrong
once the system has been live for more than a year.

**70.**
```sql
SELECT loyalty_tier, count(*) FROM customers GROUP BY loyalty_tier;  -- 5 rows
SELECT count(DISTINCT loyalty_tier) FROM customers;                  -- 4
```
`GROUP BY` buckets all NULLs into one group and emits a row for it.
`count(DISTINCT x)` is an aggregate, and every aggregate skips NULL inputs. They
differ by exactly one whenever the column contains any NULL. Same underlying
asymmetry as Day 9: bucketing uses "not distinct from" semantics, aggregation
ignores NULL.

**71.** Twenty rows because customers **13, 18, 22 and 23** have no rows in
`orders` at all, and a group cannot be formed from rows that don't exist.

To list all 24 with zero for the non-orderers, you need to start from
`customers` and attach the orders that exist — a `LEFT JOIN` with
`count(orders.order_id)` (not `count(*)`, which would count the NULL-extended
row as 1). That is Day 28, and the `count(*)`-vs-`count(col)` distinction from
yesterday is exactly what makes it work. Note the dependency now; it's a
satisfying moment when it lands.

**72.**
```sql
SELECT order_id, round(sum(quantity * unit_price * (1 - discount_pct)), 2) AS total
FROM   order_items WHERE order_id = 30 GROUP BY order_id;

SELECT * FROM order_items WHERE order_id = 30;
```
Order 30 has four lines: 29.99 + 89.99 + 49.99 + 39.99, all quantity 1, no
discounts → **209.96**. Check it against the grouped result, then against
`SELECT amount FROM payments WHERE order_id = 30;` → 214.95, which is 209.96
plus the 4.99 shipping cost. Three numbers agreeing across three tables is a
good feeling and a genuinely useful debugging habit.

**73.**
```sql
SELECT date_trunc('month', order_date)::date AS month, count(*) AS orders
FROM   orders GROUP BY 1 ORDER BY month;
```
→ **19 rows**. The range 2024-01 to 2025-07 inclusive is 19 months, so **no
months are missing** in this dataset — every month has at least one order.

That is worth confirming rather than assuming, because the query gives you no
way to tell the difference between "19 consecutive months" and "19 months with
gaps". Count the rows, count the months in the range, and compare. When they
disagree, you have found a gap — and the only reliable way to *see* the gap is
to generate the full month series and left-join, which is Day 43.

**74.**
```sql
SELECT category_id,
       count(*)                                                AS products,
       sum(CASE WHEN stock_quantity > 0 THEN 1 ELSE 0 END)     AS in_stock,
       sum(CASE WHEN stock_quantity = 0 THEN 1 ELSE 0 END)     AS out_of_stock,
       round(sum(price * stock_quantity), 2)                   AS inventory_value
FROM   products
GROUP  BY category_id
ORDER  BY category_id;
```
One pass over the table, four different numbers per group. This is conditional
aggregation combined with `GROUP BY`, and it is the workhorse of reporting SQL.
Day 22 gives you `FILTER (WHERE ...)`, which expresses the same thing far more
readably.

**75.** **Why PostgreSQL rejects it:** `orders` has no `first_name` column at
all, so the query fails on that alone. But assume the intended query were over a
table containing both. PostgreSQL requires every non-aggregated `SELECT` column
to be in `GROUP BY` because, in general, it cannot know that `first_name` is
functionally determined by `customer_id` — that guarantee comes from a
constraint, and `orders.customer_id` is a *foreign* key, not a key of the table
being grouped. Within a group of five orders, `first_name` has five values as
far as the grouping machinery is concerned, even if they happen to be identical.

**Why MySQL historically accepted it:** older MySQL (before 5.7's
`ONLY_FULL_GROUP_BY` default) returned an arbitrary value from the group. When
the values genuinely are identical this is harmless; when they aren't, it
silently produces a different answer depending on plan, storage order or
version. That is worse than an error, because it can't be detected.

**The correct query,** once joins exist (Day 27):
```sql
SELECT c.customer_id, c.first_name, count(*) AS orders
FROM   orders o
JOIN   customers c ON c.customer_id = o.customer_id
GROUP  BY c.customer_id, c.first_name
ORDER  BY orders DESC;
```
And the pleasing detail: because `c.customer_id` is `customers`' **primary
key**, PostgreSQL can prove `c.first_name` is functionally dependent on it, so
`GROUP BY c.customer_id` alone is accepted — the one place the strict rule
relaxes, and it relaxes precisely when the database can *prove* the value is
unique. Listing both columns is still the more portable habit.

---

## Day 20 Checklist

- [ ] I can predict the row count of a grouped query before running it
- [ ] **I know every non-aggregated `SELECT` column must be in `GROUP BY`**
- [ ] I never add a column to `GROUP BY` just to silence the error
- [ ] I know `NULL` forms its own group
- [ ] **I know `GROUP BY` never invents groups — absence is invisible**
- [ ] I group by `date_trunc('month', …)`, never `EXTRACT(MONTH …)`
- [ ] I can group by an expression, a `CASE`, a position or an alias
- [ ] I know `WHERE` filters rows *before* grouping
- [ ] I can `ORDER BY` an aggregate, with a tie-breaker
- [ ] I know when `GROUP BY` beats `DISTINCT`
- [ ] I check that group totals sum to the ungrouped total

---

## What's next

**Day 21 — `HAVING` and the logical order of query processing.** You can now
produce groups but not filter them: *"customers with more than three orders"* is
still out of reach. `HAVING` fixes that in one clause — and the day's real
payload is the **six-step evaluation order** that explains, all at once, why
`WHERE` can't see aggregates, why `WHERE` can't see aliases, why `ORDER BY` can,
and why `GROUP BY` sits in between. It is the single most useful mental model in
SQL.
