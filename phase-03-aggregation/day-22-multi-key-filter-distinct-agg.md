# Day 22 — Multi-Key Grouping, `FILTER`, and Conditional Aggregation

> **Phase** 3 · Aggregation
> **Level** Confident Beginner
> **Time** 120–150 minutes
> **Prerequisites** Days 01–21
> **New concepts** Grouping by several keys · group cardinality · `FILTER (WHERE …)` 🐘 · conditional aggregation with `CASE` · the pivot pattern · `count(DISTINCT …)` per group · percentages within a group · `FILTER` vs `WHERE` vs `CASE`

---

## Why this matters

Today is the most immediately practical day in the phase.

You have been writing `sum(CASE WHEN … THEN 1 ELSE 0 END)` since Day 19.
PostgreSQL has a clause that expresses the same idea in half the characters and
reads like English. And once you can compute several *differently-filtered*
aggregates in one pass, you can build a **pivot table** — rows down one axis,
categories across the top — which is what most business reporting actually is.

---

## Part 1 — Grouping by several keys

```sql
SELECT EXTRACT(YEAR FROM order_date)::int AS yr,
       status,
       count(*) AS orders
FROM   orders
GROUP  BY 1, 2
ORDER  BY yr, status;
```

```
  yr  |  status   | orders
------+-----------+--------
 2024 | cancelled |      3
 2024 | delivered |     45
 2024 | returned  |      2
 2024 | shipped   |      2
 2025 | delivered |      2
 2025 | paid      |      2
 2025 | pending   |      3
 2025 | shipped   |      1
(8 rows)
```

One row per **distinct combination** that actually occurs. 3+45+2+2+2+2+3+1 = 60 ✓

### Cardinality: how many groups will you get?

Not `distinct(a) × distinct(b)`. Only the combinations **present in the data**.

Here: 2 years × 6 statuses would be 12, but only 8 combinations exist. There
were no cancelled or returned orders in 2025, and no paid or pending orders in
2024, so those four cells simply don't appear.

> **Day 20's rule, intensified: the more keys you group by, the more missing
> combinations you get — and they are invisible.**

This is why a two-dimensional report built with multi-key grouping is full of
holes, and why the **pivot** approach in Part 3 is usually better for a fixed set
of categories: a pivot produces a column for every category whether or not it
has data, and shows `0` rather than nothing.

### More multi-key examples

```sql
-- headcount and pay by department and job title
SELECT department, job_title, count(*) AS n, round(avg(salary), 2) AS mean_salary
FROM   employees
GROUP  BY department, job_title
ORDER  BY department, mean_salary DESC;              -- 9 rows

-- customers by country and tier
SELECT country, COALESCE(loyalty_tier, 'none') AS tier, count(*) AS n
FROM   customers
GROUP  BY country, loyalty_tier
ORDER  BY country, tier;

-- monthly orders per salesperson
SELECT date_trunc('month', order_date)::date AS month,
       employee_id,
       count(*) AS orders
FROM   orders
GROUP  BY 1, 2
ORDER  BY month, employee_id NULLS LAST;
```

⚠️ **Trap** — grouping by a near-unique column destroys the aggregation. If you
add `order_id` to the `GROUP BY` of a query over `orders`, you get 60 groups of
1 and every `count(*)` is 1. Always ask: *do I want one row per this?*

---

## Part 2 — `FILTER (WHERE …)` 🐘

Here is the day's main tool.

```sql
SELECT count(*)                                   AS all_orders,
       count(*) FILTER (WHERE status = 'delivered') AS delivered,
       count(*) FILTER (WHERE status = 'cancelled') AS cancelled,
       count(*) FILTER (WHERE status = 'pending')   AS pending
FROM   orders;
```

```
 all_orders | delivered | cancelled | pending
------------+-----------+-----------+---------
         60 |        47 |         3 |       3
```

`FILTER (WHERE condition)` attaches a condition to **one aggregate**. Rows that
fail it are not fed to that aggregate — but they still feed the others.

Compare with what you wrote on Day 19:

```sql
-- Day 19 way
sum(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) AS delivered

-- Day 22 way
count(*) FILTER (WHERE status = 'delivered')          AS delivered
```

Same answer. The second says what it means.

### `FILTER` works on every aggregate

```sql
SELECT count(*)                                            AS orders,
       round(sum(shipping_cost), 2)                        AS total_shipping,
       round(sum(shipping_cost) FILTER (WHERE status = 'delivered'), 2)
                                                           AS delivered_shipping,
       round(avg(shipping_cost) FILTER (WHERE shipping_cost > 0), 2)
                                                           AS mean_paid_shipping,
       max(order_date) FILTER (WHERE status = 'delivered')  AS last_delivery
FROM   orders;
```

Note `avg(shipping_cost) FILTER (WHERE shipping_cost > 0)` — *"the average
shipping charge among orders that actually paid for shipping"*. Without the
filter, the ten free-shipping orders drag the average down. This is Day 19's
denominator problem, solved explicitly rather than accidentally.

### `FILTER` combines with `GROUP BY` — this is the payoff

```sql
SELECT customer_id,
       count(*)                                     AS total_orders,
       count(*) FILTER (WHERE status = 'delivered') AS delivered,
       count(*) FILTER (WHERE status = 'cancelled') AS cancelled,
       round(sum(shipping_cost), 2)                 AS shipping_paid
FROM   orders
GROUP  BY customer_id
ORDER  BY total_orders DESC, customer_id;
```

Four different numbers about each customer, in **one pass** over the table. Try
computing that with `WHERE` and you need three separate queries.

> **`WHERE` filters the whole query. `FILTER` filters one aggregate.**
> That is the entire distinction, and it is why they coexist.

### They compose

```sql
SELECT category_id,
       count(*)                                         AS products,
       count(*) FILTER (WHERE stock_quantity = 0)       AS out_of_stock,
       count(*) FILTER (WHERE is_discontinued)          AS discontinued,
       round(avg(price) FILTER (WHERE stock_quantity > 0), 2) AS mean_sellable_price
FROM   products
WHERE  price > 20                       -- applies to everything
GROUP  BY category_id
ORDER  BY category_id;
```

The `WHERE` narrows the rows that reach the grouping; each `FILTER` then carves
a subset out of what survived. Order of operations: `WHERE` first (step 2),
`FILTER` at aggregation time (step 3).

🐘 **`FILTER` is standard SQL** (SQL:2003) but support is patchy — PostgreSQL and
SQLite have it, MySQL and SQL Server do not. In portable code you fall back to
`CASE`. Know both.

🎯 **Interview** — "Count delivered and cancelled orders per customer in one
query." A `CASE`-based answer is correct and gets you through. `FILTER` gets you
a nod of recognition, especially if you add "…falling back to `CASE` if this
has to run on MySQL."

---

## Part 3 — Conditional aggregation and the pivot pattern

`FILTER` is a special case of a broader technique: **put a condition inside the
aggregate** so that different columns summarise different subsets.

### The `CASE` forms, and the one subtlety

```sql
-- counting: both work, and there is a real difference
sum(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END)   -- sums 1s and 0s
count(CASE WHEN status = 'delivered' THEN 1 END)        -- counts non-NULLs
```

The second has no `ELSE`, so non-matching rows produce `NULL`, and `count`
**skips NULLs** (Day 19). Both give the same answer. The second is idiomatic
because it makes the NULL-skipping do the work.

⚠️ But this one is a bug:

```sql
count(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END)   -- WRONG
```

With `ELSE 0`, every row produces a non-NULL value, so `count` counts **all 60
rows** regardless of status. `count` counts *rows with a value*; `0` is a value.
Use `sum` with `ELSE 0`, or `count` with no `ELSE`. Mixing them silently returns
the total.

▶ **Try it** — run all three against `orders` and see 47, 47, 60.

### Summing conditionally

```sql
SELECT round(sum(CASE WHEN status = 'delivered' THEN shipping_cost END), 2) AS delivered_shipping,
       round(sum(shipping_cost) FILTER (WHERE status = 'delivered'), 2)     AS same_thing
FROM   orders;
```

Identical. Note the `CASE` needs no `ELSE` — non-matching rows yield `NULL`, and
`sum` skips them.

### The pivot

Now the reason all this exists:

```sql
SELECT employee_id,
       count(*)                                     AS total,
       count(*) FILTER (WHERE status = 'delivered') AS delivered,
       count(*) FILTER (WHERE status = 'shipped')   AS shipped,
       count(*) FILTER (WHERE status = 'paid')      AS paid,
       count(*) FILTER (WHERE status = 'pending')   AS pending,
       count(*) FILTER (WHERE status = 'cancelled') AS cancelled,
       count(*) FILTER (WHERE status = 'returned')  AS returned
FROM   orders
GROUP  BY employee_id
ORDER  BY total DESC NULLS LAST;
```

```
 employee_id | total | delivered | shipped | paid | pending | cancelled | returned
-------------+-------+-----------+---------+------+---------+-----------+----------
           6 |    17 |        15 |       1 |    0 |       1 |         0 |        0
           5 |    16 |        12 |       1 |    0 |       1 |         0 |        2
           7 |    11 |         8 |       0 |    1 |       1 |         1 |        0
          12 |    10 |         8 |       1 |    1 |       0 |         0 |        0
           ␀ |     6 |         4 |       0 |    0 |       0 |         2 |        0
```

**Statuses have become columns.** That is a pivot, and it is what a spreadsheet
user means by "cross-tab".

Three things to notice:

1. **Zeros appear.** Employee 6 has no cancelled orders, and the cell says `0`
   rather than being missing. Contrast Part 1's multi-key grouping, where absent
   combinations produce no row at all. For a fixed, known set of categories, the
   pivot is almost always the better report.
2. **Each row's status columns sum to `total`.** 15+1+0+1+0+0 = 17 ✓ That's your
   sanity check.
3. **The column list is hard-coded.** You had to know the six statuses in
   advance. SQL returns a fixed set of columns decided at parse time, so a
   *dynamic* pivot — one column per value discovered at runtime — is not possible
   in plain SQL. It needs `crosstab()` from the `tablefunc` extension (Day 103),
   dynamic SQL in PL/pgSQL (Day 93), or, most commonly and most sensibly,
   pivoting in the application layer.

🎯 **Interview** — "Pivot order counts by status." Write the `FILTER` version,
then volunteer the `CASE` fallback and the fact that dynamic column lists need
`crosstab` or application code. That three-part answer is complete.

### Percentages within a group

```sql
SELECT employee_id,
       count(*) AS total,
       count(*) FILTER (WHERE status = 'delivered') AS delivered,
       round(100.0 * count(*) FILTER (WHERE status = 'delivered')
                   / count(*), 1) AS delivered_pct
FROM   orders
GROUP  BY employee_id
ORDER  BY delivered_pct DESC NULLS LAST;
```

Note `100.0` rather than `100` — both `count(*)` values are `bigint`, so
`100 * a / b` would do **integer division** and give you whole percents at best,
zero at worst. Day 14's rule, in a grouped context: cast the operand.

`count(*)` can never be zero within a group (a group exists because it has at
least one row), so no `NULLIF` guard is needed here. If the denominator were a
filtered count, you would need one:

```sql
round(100.0 * count(*) FILTER (WHERE status = 'returned')
            / NULLIF(count(*) FILTER (WHERE status = 'delivered'), 0), 1)
```

---

## Part 4 — `DISTINCT` inside aggregates, per group

```sql
SELECT customer_id,
       count(*)                       AS orders,
       count(DISTINCT shipping_city)  AS cities_shipped_to,
       count(DISTINCT status)         AS distinct_statuses
FROM   orders
GROUP  BY customer_id
ORDER  BY orders DESC, customer_id;
```

Everything from Day 19 about `count(DISTINCT …)` still applies — it skips NULLs,
and it is more expensive than a plain count — but now it operates **within each
group**.

Genuinely useful questions this answers:

```sql
-- how many distinct products did each order contain?
SELECT order_id, count(DISTINCT product_id) AS distinct_products
FROM   order_items GROUP BY order_id;

-- how many distinct customers ordered in each month?
SELECT date_trunc('month', order_date)::date AS month,
       count(*)                     AS orders,
       count(DISTINCT customer_id)  AS active_customers
FROM   orders GROUP BY 1 ORDER BY month;

-- how many distinct countries does each loyalty tier span?
SELECT COALESCE(loyalty_tier, 'none') AS tier,
       count(*)                  AS customers,
       count(DISTINCT country)   AS countries
FROM   customers GROUP BY loyalty_tier ORDER BY customers DESC;
```

That middle one — **monthly active customers** — is a genuine business metric,
and you now have it in four lines.

### `DISTINCT` and `FILTER` together

```sql
SELECT date_trunc('month', order_date)::date AS month,
       count(DISTINCT customer_id)                                        AS active,
       count(DISTINCT customer_id) FILTER (WHERE status = 'delivered')    AS with_delivery
FROM   orders
GROUP  BY 1
ORDER  BY month;
```

Perfectly legal and occasionally invaluable.

⚠️ **Performance note.** `count(DISTINCT x)` per group forces PostgreSQL to keep
every distinct value of `x` for every group in memory. Twelve groups is nothing;
twelve million groups will spill to disk and may not finish. This is one of the
first things to look at when a grouped query is slow — Day 80.

---

## Part 5 — `FILTER` vs `WHERE` vs `CASE`: choosing

| You want | Use |
|---|---|
| To remove rows from the whole query | `WHERE` |
| One aggregate over a subset, others over everything | `FILTER` |
| The same, but portable to MySQL/SQL Server | `CASE` inside the aggregate |
| To remove entire groups after aggregating | `HAVING` |

A query using all four:

```sql
SELECT category_id,
       count(*)                                          AS products,
       count(*) FILTER (WHERE stock_quantity = 0)        AS out_of_stock,
       sum(CASE WHEN price > 500 THEN 1 ELSE 0 END)      AS premium_count,
       round(avg(price), 2)                              AS mean_price
FROM   products
WHERE  NOT is_discontinued                               -- rows
GROUP  BY category_id
HAVING count(*) > 2                                      -- groups
ORDER  BY mean_price DESC;
```

Read it against Day 21's processing order:

```
FROM products          →  25 rows
WHERE NOT discontinued →  23 rows        (step 2)
GROUP BY category_id   →  7 groups       (step 3)
   ... each aggregate applies its own FILTER/CASE within its group
HAVING count(*) > 2    →  fewer groups   (step 4)
SELECT                 →  columns built  (step 5)
ORDER BY mean_price    →  sorted         (step 7)
```

If you can narrate that, you understand aggregation.

---

## Traps & Gotchas

| # | Trap | What happens |
|---|---|---|
| 1 | `count(CASE WHEN c THEN 1 ELSE 0 END)` | Counts **all** rows — `0` is a value |
| 2 | Multi-key grouping for a 2-D report | Missing combinations vanish; use a pivot |
| 3 | Adding a near-unique key to `GROUP BY` | One row per row; aggregation destroyed |
| 4 | `100 * a / b` with `bigint` counts | Integer division — use `100.0` |
| 5 | Dividing by a filtered count | Can be zero — needs `NULLIF` |
| 6 | Expecting a dynamic pivot in plain SQL | Column lists are fixed at parse time |
| 7 | `count(DISTINCT …)` over millions of groups | Memory blow-up, disk spill |
| 8 | Using `FILTER` in portable code | Not in MySQL or SQL Server |
| 9 | Confusing `FILTER` with `WHERE` | One narrows an aggregate, the other the query |
| 10 | Pivot columns not summing to the total | A status you forgot to include |

---

## Interview angles

- **Junior** — "Count delivered and cancelled orders in one query." →
  `count(*) FILTER (WHERE …)` twice, or `CASE`.
- **Junior** — "Monthly active customers." →
  `count(DISTINCT customer_id)` grouped by `date_trunc('month', …)`.
- **Mid** — "Difference between `WHERE` and `FILTER`?" → `WHERE` removes rows
  from the whole query; `FILTER` restricts one aggregate while others still see
  everything.
- **Mid** — "Why does `count(CASE WHEN x THEN 1 ELSE 0 END)` return the row
  count?" → `count` counts non-NULL values and `0` is not NULL. Drop the `ELSE`
  or use `sum`.
- **Mid** — "Pivot statuses into columns." → `FILTER`/`CASE`, plus the note that
  the column list must be static.
- **Senior** — "A report needs one column per product category, and categories
  are added weekly. How?" → Not in plain SQL. Options: `crosstab()` from
  `tablefunc`; dynamic SQL building the column list in PL/pgSQL; returning long
  format (`category, value`) and pivoting in the application; or returning
  `jsonb_object_agg`. Recommend the third for most cases — it keeps the SQL
  stable and moves presentation where it belongs. Days 93, 103, 68.
- **Senior** — "`count(DISTINCT user_id)` per day over 2 billion rows is
  timing out." → High-cardinality distinct aggregation is memory-bound.
  Pre-aggregate daily into a rollup table; or use `postgres_hll` for approximate
  distinct counts, which are mergeable across days — a property exact counts
  don't have. Days 80, 90, 103.

---

## Practice

> Available: everything from Days 1–21, plus multi-key `GROUP BY`, `FILTER`,
> conditional aggregation, and `count(DISTINCT …)` per group.

### Section A — Drill (new concept only)

1. Orders per year and status.
2. Employees per department and job title.
3. Customers per country and loyalty tier.
4. Products per category and discontinued flag.
5. Orders per month and status.
6. Payments per method and status.
7. Reviews per rating and product, limited to products 1 and 2.
8. Whole-table: total orders, delivered, cancelled, pending, using `FILTER`.
9. The same, using `CASE` inside `sum`.
10. The same, using `count(CASE WHEN … THEN 1 END)`.
11. Run `count(CASE WHEN status='delivered' THEN 1 ELSE 0 END)` and explain the
    result.
12. Total products, out-of-stock products and discontinued products, using
    `FILTER`.
13. Total customers, those with a city, those with a phone, using `FILTER`.
14. Total employees and those with a commission, using `FILTER`.
15. Total shipping cost and shipping cost on delivered orders only.
16. Average shipping cost overall and average among orders that paid for
    shipping.
17. Per customer: total orders and delivered orders.
18. Per customer: total orders, delivered, cancelled, returned.
19. Per category: product count and out-of-stock count.
20. Per category: product count and average price of in-stock products only.
21. Per department: headcount and count with a commission.
22. Per month: orders and delivered orders.
23. Per order: distinct products ordered.
24. Per month: orders and distinct customers.
25. Per loyalty tier: customers and distinct countries.

### Section B — Combination (with Days 01–21)

26. Pivot: orders per salesperson broken into all six statuses, plus a total.
27. Verify that each row of problem 26 sums correctly.
28. Pivot: products per category broken into in-stock / out-of-stock, plus
    total inventory value.
29. Per customer: orders, delivered orders, and delivered percentage to 1
    decimal.
30. Per salesperson: orders, cancelled orders, and cancellation rate to 1
    decimal.
31. Per month: orders, distinct customers, and orders per customer to 2
    decimals.
32. Per category: count, average price, and count of products priced over 500.
33. Per country: customers, active customers, and inactive customers.
34. Per year: orders, distinct customers, total shipping.
35. Per product: units sold, revenue, and number of distinct orders it appeared
    in.
36. Per month: revenue is impossible — explain why in one sentence, then
    compute orders and shipping per month instead.
37. Per customer: total orders, first order date, latest order date, and days
    between them.
38. Per department: headcount, average salary, and count earning over 50000.
39. Per rating: reviews, total helpful votes, and average helpful votes.
40. Per product: reviews, average rating, and count of 5-star reviews.
41. Per payment method: count, total, and count of refunds.
42. Per category: products, and the percentage of the whole catalogue they
    represent (hint: you can't yet — try, then explain what's missing).
43. Per customer: orders in 2024 and orders in 2025, side by side.
44. Per status: orders, average shipping cost, and count with free shipping.
45. Per supplier: products, average price, and count discontinued.
46. Per signup year: customers, and count with a loyalty tier.
47. Per ISO weekday: orders and delivered orders.
48. Per category: products, and count whose name contains a digit.
49. Per customer: orders, and distinct shipping countries.
50. Per month in 2024: orders, delivered, and delivered percentage.

### Section C — Recall (Days 01–21)

51. Customers with more than 3 orders.
52. Categories with more than 3 products.
53. Recite the eight-step logical processing order.
54. Why can't `HAVING` use a `SELECT` alias?
55. `count(*)` vs `count(city)` on `customers`.
56. Products per category — how many rows, which categories missing?
57. `sum(price)` over an empty set.
58. Payments in December 2024, half-open range.
59. The last day of the month containing `2024-02-10`.
60. Reset the database and verify the nine row counts.

### Section D — Challenge

61. Run all three counting forms against `orders` — `sum(CASE … ELSE 0 END)`,
    `count(CASE … THEN 1 END)`, `count(CASE … ELSE 0 END)` — and explain why the
    third gives 60.
62. Build the full status pivot per salesperson and prove every row's status
    columns sum to its total.
63. Write the same pivot using only `CASE` (no `FILTER`) and confirm the
    outputs are identical.
64. Compute the delivered percentage per salesperson. First write it with
    `100 *` and note what happens, then fix it.
65. Compute the return rate per salesperson as
    `returned / delivered`, and make it safe when a salesperson has zero
    deliveries.
66. Multi-key group `orders` by year and status — 8 rows. Now build the same
    information as a pivot with years as rows and statuses as columns. Which
    presentation makes the missing combinations visible, and why does that
    matter?
67. Find, per customer, the number of distinct months in which they ordered.
    (Hint: `count(DISTINCT date_trunc(...))`.)
68. Per category, compute the share of products that are out of stock, as a
    percentage to 1 decimal, and sort worst first.
69. Write one query giving, per month: orders, distinct customers, distinct
    salespeople, total shipping, delivered count, and delivered percentage.
    Then say which single extra piece of information would make this a genuine
    monthly revenue report, and which Day unlocks it.
70. Design question: your pivot has six hard-coded status columns. Next week the
    business adds a `refunded` status. What breaks, how would you find out, and
    what are three different designs that avoid the problem?

---

## Solutions

### Section A

**1.**
```sql
SELECT EXTRACT(YEAR FROM order_date)::int AS yr, status, count(*) AS n
FROM orders GROUP BY 1, 2 ORDER BY 1, 2;
```
→ 8 rows.
**2.** `SELECT department, job_title, count(*) FROM employees GROUP BY 1,2 ORDER BY 1,2;` → 9 rows
**3.** `SELECT country, loyalty_tier, count(*) FROM customers GROUP BY 1,2 ORDER BY 1,2 NULLS LAST;`
**4.** `SELECT category_id, is_discontinued, count(*) FROM products GROUP BY 1,2 ORDER BY 1,2;`
**5.** `SELECT date_trunc('month', order_date)::date AS m, status, count(*) FROM orders GROUP BY 1,2 ORDER BY 1,2;`
**6.** `SELECT method, status, count(*) FROM payments GROUP BY 1,2 ORDER BY 1,2;`
**7.** `SELECT product_id, rating, count(*) FROM reviews WHERE product_id IN (1,2) GROUP BY 1,2 ORDER BY 1,2;`
**8.**
```sql
SELECT count(*) AS total,
       count(*) FILTER (WHERE status = 'delivered') AS delivered,
       count(*) FILTER (WHERE status = 'cancelled') AS cancelled,
       count(*) FILTER (WHERE status = 'pending')   AS pending
FROM   orders;
```
→ 60, 47, 3, 3
**9.** Replace each with `sum(CASE WHEN status = '…' THEN 1 ELSE 0 END)`.
**10.** Replace each with `count(CASE WHEN status = '…' THEN 1 END)` — **no**
`ELSE`.
**11.** `count(CASE WHEN status='delivered' THEN 1 ELSE 0 END)` → **60**. With
`ELSE 0` every row yields a non-NULL value, and `count` counts values, not
truths. The `0`s are counted just like the `1`s.
**12.**
```sql
SELECT count(*) AS products,
       count(*) FILTER (WHERE stock_quantity = 0) AS out_of_stock,
       count(*) FILTER (WHERE is_discontinued)    AS discontinued
FROM   products;
```
→ 25, 4, 2
**13.**
```sql
SELECT count(*) AS customers,
       count(*) FILTER (WHERE city IS NOT NULL)  AS with_city,
       count(*) FILTER (WHERE phone IS NOT NULL) AS with_phone
FROM   customers;
```
→ 24, 22, 19 — the same numbers as Day 19's `count(city)` and `count(phone)`,
by a different route.
**14.** `SELECT count(*), count(*) FILTER (WHERE commission_pct IS NOT NULL) FROM employees;` → 12, 5
**15.**
```sql
SELECT round(sum(shipping_cost), 2) AS total,
       round(sum(shipping_cost) FILTER (WHERE status = 'delivered'), 2) AS delivered
FROM   orders;
```
**16.**
```sql
SELECT round(avg(shipping_cost), 2) AS overall,
       round(avg(shipping_cost) FILTER (WHERE shipping_cost > 0), 2) AS among_payers
FROM   orders;
```
→ 5.91 and a higher figure, because the ten free-shipping orders are excluded
from the second.
**17.**
```sql
SELECT customer_id, count(*) AS orders,
       count(*) FILTER (WHERE status = 'delivered') AS delivered
FROM   orders GROUP BY customer_id ORDER BY orders DESC, customer_id;
```
**18.** Add `cancelled` and `returned` filters.
**19.**
```sql
SELECT category_id, count(*) AS products,
       count(*) FILTER (WHERE stock_quantity = 0) AS out_of_stock
FROM   products GROUP BY category_id ORDER BY category_id;
```
**20.** Add `round(avg(price) FILTER (WHERE stock_quantity > 0), 2)`.
**21.** `SELECT department, count(*), count(*) FILTER (WHERE commission_pct IS NOT NULL) FROM employees GROUP BY department;`
**22.**
```sql
SELECT date_trunc('month', order_date)::date AS month, count(*) AS orders,
       count(*) FILTER (WHERE status = 'delivered') AS delivered
FROM   orders GROUP BY 1 ORDER BY month;
```
**23.** `SELECT order_id, count(DISTINCT product_id) FROM order_items GROUP BY order_id;`
**24.**
```sql
SELECT date_trunc('month', order_date)::date AS month,
       count(*) AS orders, count(DISTINCT customer_id) AS customers
FROM   orders GROUP BY 1 ORDER BY month;
```
**25.** `SELECT COALESCE(loyalty_tier,'none') AS tier, count(*) AS customers, count(DISTINCT country) AS countries FROM customers GROUP BY loyalty_tier ORDER BY customers DESC;`

### Section B

**26.**
```sql
SELECT employee_id,
       count(*)                                     AS total,
       count(*) FILTER (WHERE status = 'delivered') AS delivered,
       count(*) FILTER (WHERE status = 'shipped')   AS shipped,
       count(*) FILTER (WHERE status = 'paid')      AS paid,
       count(*) FILTER (WHERE status = 'pending')   AS pending,
       count(*) FILTER (WHERE status = 'cancelled') AS cancelled,
       count(*) FILTER (WHERE status = 'returned')  AS returned
FROM   orders GROUP BY employee_id ORDER BY total DESC NULLS LAST;
```
**27.** Employee 6: 15+1+0+1+0+0 = 17 ✓ · Employee 5: 12+1+0+1+0+2 = 16 ✓ ·
Employee 7: 8+0+1+1+1+0 = 11 ✓ · Employee 12: 8+1+1+0+0+0 = 10 ✓ ·
NULL group: 4+0+0+0+2+0 = 6 ✓ · Grand total 60 ✓
**28.**
```sql
SELECT category_id, count(*) AS products,
       count(*) FILTER (WHERE stock_quantity > 0) AS in_stock,
       count(*) FILTER (WHERE stock_quantity = 0) AS out_of_stock,
       round(sum(price * stock_quantity), 2)      AS inventory_value
FROM   products GROUP BY category_id ORDER BY category_id;
```
**29.**
```sql
SELECT customer_id, count(*) AS orders,
       count(*) FILTER (WHERE status = 'delivered') AS delivered,
       round(100.0 * count(*) FILTER (WHERE status = 'delivered') / count(*), 1)
         AS delivered_pct
FROM   orders GROUP BY customer_id ORDER BY delivered_pct DESC, customer_id;
```
**30.** Same shape with `status = 'cancelled'`.
**31.**
```sql
SELECT date_trunc('month', order_date)::date AS month,
       count(*) AS orders,
       count(DISTINCT customer_id) AS customers,
       round(count(*)::numeric / count(DISTINCT customer_id), 2) AS orders_per_customer
FROM   orders GROUP BY 1 ORDER BY month;
```
**32.**
```sql
SELECT category_id, count(*) AS n, round(avg(price),2) AS mean_price,
       count(*) FILTER (WHERE price > 500) AS premium
FROM   products GROUP BY category_id ORDER BY category_id;
```
**33.**
```sql
SELECT country, count(*) AS customers,
       count(*) FILTER (WHERE is_active)     AS active,
       count(*) FILTER (WHERE NOT is_active) AS inactive
FROM   customers GROUP BY country ORDER BY customers DESC, country;
```
**34.**
```sql
SELECT EXTRACT(YEAR FROM order_date)::int AS yr, count(*) AS orders,
       count(DISTINCT customer_id) AS customers,
       round(sum(shipping_cost), 2) AS shipping
FROM   orders GROUP BY 1 ORDER BY 1;
```
**35.**
```sql
SELECT product_id, sum(quantity) AS units,
       round(sum(quantity * unit_price * (1 - discount_pct)), 2) AS revenue,
       count(DISTINCT order_id) AS orders
FROM   order_items GROUP BY product_id ORDER BY revenue DESC;
```
**36.** Monthly revenue is impossible because the money lives in `order_items`
and the date lives in `orders`, and you cannot yet read two tables in one query
— that is a **join**, Day 27. Meanwhile:
```sql
SELECT date_trunc('month', order_date)::date AS month,
       count(*) AS orders, round(sum(shipping_cost), 2) AS shipping
FROM   orders GROUP BY 1 ORDER BY month;
```
**37.**
```sql
SELECT customer_id, count(*) AS orders,
       min(order_date) AS first_order, max(order_date) AS latest_order,
       max(order_date) - min(order_date) AS days_active
FROM   orders GROUP BY customer_id ORDER BY days_active DESC;
```
**38.**
```sql
SELECT department, count(*) AS headcount, round(avg(salary),2) AS mean_salary,
       count(*) FILTER (WHERE salary > 50000) AS over_50k
FROM   employees GROUP BY department ORDER BY mean_salary DESC;
```
**39.** `SELECT rating, count(*), sum(helpful_votes), round(avg(helpful_votes),1) FROM reviews GROUP BY rating ORDER BY rating DESC;`
**40.**
```sql
SELECT product_id, count(*) AS reviews, round(avg(rating),2) AS mean_rating,
       count(*) FILTER (WHERE rating = 5) AS five_star
FROM   reviews GROUP BY product_id ORDER BY reviews DESC, product_id;
```
**41.**
```sql
SELECT method, count(*) AS n, round(sum(amount),2) AS total,
       count(*) FILTER (WHERE status = 'refunded') AS refunds
FROM   payments GROUP BY method ORDER BY total DESC;
```
**42.** You cannot compute "percentage of the whole catalogue" in a grouped
query with today's tools, because each group only knows about itself — the
denominator (25) is a property of the *whole table*, which no group can see.
Options later: a subquery (Day 36), a CTE (Day 41), or — the idiomatic answer —
a **window function**, `count(*) * 100.0 / sum(count(*)) OVER ()` (Day 46).
Writing the attempt and hitting the wall is the exercise.
**43.**
```sql
SELECT customer_id,
       count(*) FILTER (WHERE order_date <  DATE '2025-01-01') AS orders_2024,
       count(*) FILTER (WHERE order_date >= DATE '2025-01-01') AS orders_2025
FROM   orders GROUP BY customer_id ORDER BY customer_id;
```
**44.**
```sql
SELECT status, count(*) AS orders, round(avg(shipping_cost),2) AS mean_ship,
       count(*) FILTER (WHERE shipping_cost = 0) AS free_shipping
FROM   orders GROUP BY status ORDER BY orders DESC;
```
**45.**
```sql
SELECT supplier_id, count(*) AS products, round(avg(price),2) AS mean_price,
       count(*) FILTER (WHERE is_discontinued) AS discontinued
FROM   products GROUP BY supplier_id ORDER BY supplier_id NULLS LAST;
```
**46.**
```sql
SELECT EXTRACT(YEAR FROM signup_date)::int AS yr, count(*) AS customers,
       count(*) FILTER (WHERE loyalty_tier IS NOT NULL) AS with_tier
FROM   customers GROUP BY 1 ORDER BY 1;
```
**47.**
```sql
SELECT EXTRACT(ISODOW FROM order_date)::int AS weekday, count(*) AS orders,
       count(*) FILTER (WHERE status = 'delivered') AS delivered
FROM   orders GROUP BY 1 ORDER BY 1;
```
**48.**
```sql
SELECT category_id, count(*) AS products,
       count(*) FILTER (WHERE product_name ~ '[0-9]') AS with_digit
FROM   products GROUP BY category_id ORDER BY category_id;
```
**49.** `SELECT customer_id, count(*) AS orders, count(DISTINCT shipping_country) AS countries FROM orders GROUP BY customer_id ORDER BY countries DESC, customer_id;`
**50.**
```sql
SELECT date_trunc('month', order_date)::date AS month,
       count(*) AS orders,
       count(*) FILTER (WHERE status = 'delivered') AS delivered,
       round(100.0 * count(*) FILTER (WHERE status = 'delivered') / count(*), 1) AS pct
FROM   orders
WHERE  order_date >= DATE '2024-01-01' AND order_date < DATE '2025-01-01'
GROUP  BY 1 ORDER BY month;
```

### Section C

**51.** `GROUP BY customer_id HAVING count(*) > 3` → 6 rows
**52.** `GROUP BY category_id HAVING count(*) > 3` → 3 rows
**53.** `FROM` → `WHERE` → `GROUP BY` → `HAVING` → `SELECT` → `DISTINCT` →
`ORDER BY` → `LIMIT`
**54.** `HAVING` is step 4; aliases are created at `SELECT`, step 5.
**55.** 24 and 22.
**56.** 7 rows; categories 2, 5 and 8 have no products directly assigned.
**57.** `NULL`.
**58.** `WHERE paid_at >= '2024-12-01' AND paid_at < '2025-01-01';`
**59.** `2024-02-29`.
**60.** `\i 99_reset.sql`

### Section D

**61.**
```sql
SELECT sum(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) AS sum_with_else,  -- 47
       count(CASE WHEN status = 'delivered' THEN 1 END)      AS count_no_else,  -- 47
       count(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) AS count_with_else -- 60
FROM   orders;
```
The third gives 60 because `count` counts **values, not truths**. With
`ELSE 0`, every one of the 60 rows produces a non-NULL result — `1` for
delivered, `0` for everything else — and `count` dutifully counts all 60. Drop
the `ELSE` so non-matching rows become `NULL`, or use `sum`, which adds the
zeros harmlessly.

**62.** See B26/B27. Verifying that the pivot columns sum to the total is the
standard check, and it is how you discover you forgot a status.

**63.** Replace each `count(*) FILTER (WHERE status = 'x')` with
`count(CASE WHEN status = 'x' THEN 1 END)`. Run both and diff the output —
identical. The `CASE` version is what you write when the query must run on
MySQL or SQL Server.

**64.**
```sql
-- integer division: every percentage is 0 or 100
SELECT employee_id,
       100 * count(*) FILTER (WHERE status='delivered') / count(*) AS pct_wrong
FROM orders GROUP BY employee_id;

-- fixed
SELECT employee_id,
       round(100.0 * count(*) FILTER (WHERE status='delivered') / count(*), 1) AS pct
FROM orders GROUP BY employee_id;
```
`count(*)` returns `bigint`, so `100 * a / b` is integer arithmetic throughout
and truncates. `100.0` makes the first operand `numeric`, which promotes the
whole expression. Day 14's rule — cast the **operand** — applied to aggregates.

**65.**
```sql
SELECT employee_id,
       count(*) FILTER (WHERE status = 'returned')  AS returned,
       count(*) FILTER (WHERE status = 'delivered') AS delivered,
       round(100.0 * count(*) FILTER (WHERE status = 'returned')
                   / NULLIF(count(*) FILTER (WHERE status = 'delivered'), 0), 1)
         AS return_rate_pct
FROM   orders GROUP BY employee_id ORDER BY return_rate_pct DESC NULLS LAST;
```
The `NULLIF` matters here in a way it didn't in problem 64: `count(*)` is never
zero for an existing group, but a **filtered** count easily can be. A
salesperson with no deliveries would otherwise abort the entire query with
`division by zero`. Day 17's guard, still earning its keep.

**66.**
```sql
-- multi-key: 8 rows
SELECT EXTRACT(YEAR FROM order_date)::int AS yr, status, count(*)
FROM orders GROUP BY 1,2 ORDER BY 1,2;

-- pivot: 2 rows, 6 status columns
SELECT EXTRACT(YEAR FROM order_date)::int AS yr,
       count(*) FILTER (WHERE status='delivered') AS delivered,
       count(*) FILTER (WHERE status='shipped')   AS shipped,
       count(*) FILTER (WHERE status='paid')      AS paid,
       count(*) FILTER (WHERE status='pending')   AS pending,
       count(*) FILTER (WHERE status='cancelled') AS cancelled,
       count(*) FILTER (WHERE status='returned')  AS returned
FROM orders GROUP BY 1 ORDER BY 1;
```
**The pivot makes the gaps visible.** It shows `0` for 2024-paid, 2024-pending,
2025-cancelled and 2025-returned — the four combinations that simply don't
exist in the multi-key version.

Why it matters: a reader of the 8-row version cannot tell the difference between
"no cancelled orders in 2025" and "I forgot to include cancelled orders". A zero
is an assertion; an absent row is an ambiguity. For any report with a known,
fixed set of categories, prefer the pivot.

**67.**
```sql
SELECT customer_id,
       count(*)                                          AS orders,
       count(DISTINCT date_trunc('month', order_date))   AS active_months
FROM   orders GROUP BY customer_id ORDER BY active_months DESC, customer_id;
```
Customer 3 has 7 orders across 7 distinct months; customer 1 has 6 across 6.
Comparing `orders` with `active_months` tells you whether someone buys steadily
or in bursts — the germ of the cohort analysis you'll build on Day 52.

**68.**
```sql
SELECT category_id,
       count(*)                                   AS products,
       count(*) FILTER (WHERE stock_quantity = 0) AS out_of_stock,
       round(100.0 * count(*) FILTER (WHERE stock_quantity = 0) / count(*), 1)
         AS out_of_stock_pct
FROM   products GROUP BY category_id ORDER BY out_of_stock_pct DESC, category_id;
```
Category 7 (Furniture) has 1 of 3 out of stock → 33.3%; category 4 (Phones) 1 of
3 → 33.3%; category 3 (Laptops) 1 of 3 → 33.3%; category 10 has 1 of 5 → 20.0%.
Run it and read the real ordering — and note the tie-breaker, without which the
three 33.3% rows come back in arbitrary order (Day 5).

**69.**
```sql
SELECT date_trunc('month', order_date)::date              AS month,
       count(*)                                           AS orders,
       count(DISTINCT customer_id)                        AS customers,
       count(DISTINCT employee_id)                        AS salespeople,
       round(sum(shipping_cost), 2)                       AS shipping,
       count(*) FILTER (WHERE status = 'delivered')       AS delivered,
       round(100.0 * count(*) FILTER (WHERE status = 'delivered') / count(*), 1)
                                                          AS delivered_pct
FROM   orders
GROUP  BY 1
ORDER  BY month;
```
The missing piece is **order value**, which lives in `order_items` — a different
table. Every figure above is about order *volume*; none is about money beyond
shipping. Turning this into a revenue report requires joining `orders` to
`order_items`, which is **Day 27**, and doing it with aggregation is **Day 34**.

That's the single most useful thing to notice at the end of Phase 3: you have
squeezed nearly everything out of one table at a time, and the remaining
questions all have the same shape — *the data I need is in another table*.

**70.** **What breaks:** nothing errors. The `total` column still counts all
orders, but the six status columns no longer sum to it. Refunded orders become
invisible — present in the total, absent from every breakdown — and the
discrepancy is silent.

**How you'd find out:** the sanity check from problem 27. A report that
validates `total = sum of its own breakdown columns` and alerts on mismatch
catches this on the first day. Without it, someone notices in a quarterly review,
if at all. (Day 21's `HAVING`-as-assertion pattern is exactly how you'd schedule
that check.)

**Three designs that avoid it:**

1. **Add an "other" column.** `count(*) FILTER (WHERE status NOT IN (…the six…))
   AS other`. The columns now always sum to the total, and an unexpected status
   shows up as a non-zero `other` instead of vanishing. Cheapest fix, and it
   turns a silent failure into a visible one. Do this even if you also do
   something else.

2. **Return long format and pivot in the application.** `SELECT employee_id,
   status, count(*) GROUP BY 1,2` — new statuses appear automatically as new
   rows, and the presentation layer decides the columns. The SQL never changes
   again. This is my default recommendation: it puts the fixed-column decision
   where fixed columns actually belong.

3. **Drive the columns from a lookup table.** Make `order_statuses` a real table
   (as argued on Day 17) and generate the pivot dynamically — `crosstab()` from
   `tablefunc`, or PL/pgSQL building the column list. Powerful and correct, but
   dynamic SQL is harder to read, harder to test, and the result set's shape
   becomes data-dependent, which surprises callers.

The senior observation underneath all three: **a hard-coded list in a query is a
copy of the schema**, and copies drift. Either make the query not need the list
(option 2), or make the list come from the same source of truth the data does
(option 3). Option 1 doesn't remove the copy but makes its staleness loud, which
is often enough.

---

## Day 22 Checklist

- [ ] I can group by several keys and predict how many groups I'll get
- [ ] I know missing combinations vanish from multi-key grouping
- [ ] **I can use `FILTER (WHERE …)` on any aggregate**
- [ ] I know `WHERE` narrows the query and `FILTER` narrows one aggregate
- [ ] I can write the same thing with `CASE` for portability
- [ ] **I know `count(CASE … ELSE 0 END)` counts every row, and why**
- [ ] I can build a pivot with statuses as columns
- [ ] I check that pivot columns sum to the total
- [ ] I know a dynamic column list is impossible in plain SQL
- [ ] I use `100.0` not `100` when computing percentages from counts
- [ ] I guard division by a **filtered** count with `NULLIF`
- [ ] I can use `count(DISTINCT …)` per group, and I know its memory cost

---

## What's next

**Day 23 — Collection and statistical aggregates.** `string_agg` and
`array_agg` collapse a group's rows into a single list — so "every product in
this category, comma-separated" becomes one line of SQL. Plus `bool_and`/
`bool_or` for "do all/any rows satisfy this", and the ordered-set aggregates
`percentile_cont` and `mode()` — because the median is not `avg`, and knowing
the difference is what separates a report that informs from one that misleads.
