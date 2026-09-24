# Day 21 — `HAVING` and the Logical Order of Query Processing

> **Phase** 3 · Aggregation
> **Level** Confident Beginner
> **Time** 120–150 minutes
> **Prerequisites** Days 01–20
> **New concepts** `HAVING` · `WHERE` vs `HAVING` · **the eight-step logical processing order** · `HAVING` without `GROUP BY` · why `WHERE` can't see aliases or aggregates · why `ORDER BY` can · performance implications of filtering in the wrong place
>
> 🎯 **This is the single most useful mental model in SQL.** Nine of the last
> twenty days' traps become obvious once you hold it. Do not skim Part 3.

---

## Why this matters

You can now produce groups. You cannot yet *filter* them.

*"Which customers have placed more than three orders?"* — you can compute orders
per customer, but you cannot keep only the ones above three, because
`WHERE count(*) > 3` is an error.

`HAVING` fixes that in one clause and takes ten minutes to learn. The rest of
the day is the payload: **the order in which PostgreSQL logically evaluates a
query**. That single diagram explains, all at once, why `WHERE` can't see
aggregates, why `WHERE` can't see `SELECT` aliases, why `ORDER BY` can, why
`GROUP BY` sits between them, and what `HAVING` is actually for.

Every confusing rule from the last three weeks collapses into one picture today.

---

## Part 1 — `HAVING`

```sql
SELECT customer_id, count(*) AS orders
FROM   orders
GROUP  BY customer_id
HAVING count(*) > 3
ORDER  BY orders DESC, customer_id;
```

```
 customer_id | orders
-------------+--------
           3 |      7
           1 |      6
           6 |      6
           5 |      4
          10 |      4
          19 |      4
(6 rows)
```

Six customers out of the twenty who have ordered at all.

`HAVING` filters **groups**, using conditions on aggregates. It sits between
`GROUP BY` and `ORDER BY`:

```sql
SELECT   columns and aggregates
FROM     table
WHERE    row condition
GROUP BY grouping keys
HAVING   group condition
ORDER BY sort keys
LIMIT    n;
```

More examples:

```sql
-- categories with more than 3 products
SELECT category_id, count(*) AS n
FROM   products
GROUP  BY category_id
HAVING count(*) > 3
ORDER  BY n DESC;                                    -- 3 rows: 10, 1, 9

-- departments whose average salary exceeds 55,000
SELECT department, round(avg(salary), 2) AS mean_salary
FROM   employees
GROUP  BY department
HAVING avg(salary) > 55000
ORDER  BY mean_salary DESC;                          -- 2 rows: Management, Sales

-- orders with more than one line
SELECT order_id, count(*) AS items
FROM   order_items
GROUP  BY order_id
HAVING count(*) > 1
ORDER  BY items DESC, order_id;                      -- 39 rows

-- products with more than two reviews
SELECT product_id, count(*) AS reviews, round(avg(rating), 2) AS mean_rating
FROM   reviews
GROUP  BY product_id
HAVING count(*) > 2
ORDER  BY reviews DESC, product_id;                  -- 4 rows: products 1, 2, 4, 7
```

▶ **Try it** — run all four and check the row counts against the comments.

### `HAVING` conditions can be anything about the group

```sql
-- groups where the total exceeds a threshold
HAVING sum(price) > 1000

-- groups with a spread
HAVING max(price) - min(price) > 500

-- combinations, with the Day 8 rules about AND/OR intact
HAVING count(*) > 2 AND avg(price) > 100

-- conditions on the grouping key itself (legal, but see Part 4)
HAVING category_id <> 9
```

---

## Part 2 — `WHERE` vs `HAVING`

The distinction in one line:

> **`WHERE` filters rows *before* grouping. `HAVING` filters groups *after*.**

They are not alternatives. A single query often needs both:

```sql
SELECT category_id,
       count(*)             AS n,
       round(avg(price), 2) AS mean_price
FROM   products
WHERE  NOT is_discontinued          -- drop rows first
GROUP  BY category_id
HAVING count(*) > 2                 -- then drop small groups
ORDER  BY mean_price DESC;
```

Read it as a pipeline:

```
25 products
   │  WHERE NOT is_discontinued
   ▼
23 products                          ← 2 discontinued rows removed
   │  GROUP BY category_id
   ▼
7 groups                             ← note: still 7; both discontinued
   │  HAVING count(*) > 2              products were in categories that
   ▼                                   have other products too
n groups
```

**The order matters and changes the answer.** Filtering rows out before grouping
changes every count, sum and average. Filtering groups afterwards does not touch
the aggregates at all — it only decides which already-computed groups survive.

### Getting them the wrong way round

```sql
-- These two are NOT the same query.

-- (A) average price per category, among cheap products only
SELECT category_id, avg(price) FROM products
WHERE price < 500 GROUP BY category_id;

-- (B) average price per category, for categories whose average is under 500
SELECT category_id, avg(price) FROM products
GROUP BY category_id HAVING avg(price) < 500;
```

(A) throws away expensive products, then averages what's left — so every average
it reports is below 500 by construction.
(B) averages **everything**, then keeps categories whose average happens to be
below 500 — and those averages include expensive products.

Run both. Category 3 (the laptops, average 1182.33) vanishes from (B) entirely,
but appears in (A) with an average of 549.00, computed from the single laptop
under 500... except there isn't one, so it vanishes from (A) too. Category 4 is
the interesting one: it appears in (A) with an average of 299.00 (only
`Old Phone 2020` survives the filter) and is absent from (B) (its true average
is 665.67).

**Same tables, same numbers, completely different questions.** Being able to
articulate which one a stakeholder meant is most of the skill of reporting.

🎯 **Interview** — "`WHERE` vs `HAVING`?" The one-liner is "rows vs groups", but
the answer that lands is the worked example above: the same threshold applied in
the two places produces different results, and you can say which is which.

---

## Part 3 — The logical order of query processing

Here it is. Memorise it.

```
1. FROM        pick the tables, apply JOINs            (Day 27)
2. WHERE       filter individual rows
3. GROUP BY    sort surviving rows into groups
4. HAVING      filter the groups
5. SELECT      evaluate the output expressions
               ← aliases are created HERE
6. DISTINCT    remove duplicate output rows
7. ORDER BY    sort the result
8. LIMIT/OFFSET   trim the result
```

You **write** the query in the order `SELECT … FROM … WHERE … GROUP BY …
HAVING … ORDER BY … LIMIT`. PostgreSQL **evaluates** it in the order above. The
mismatch between those two orders is the source of almost every confusing rule
you have met.

> ⚠️ This is the **logical** order — a semantic model, not an execution plan.
> The actual executor reorders freely for speed (Day 77), and is allowed to, as
> long as the answer matches what this model would produce. Think of it as the
> contract, not the implementation.

### Everything it explains

**Why can't `WHERE` use an aggregate?**

```sql
SELECT * FROM products WHERE price > avg(price);   -- ERROR
```

`WHERE` is step 2. Aggregates are computed at step 3–4. When `WHERE` runs, no
group exists and no average has been computed. ✅ Explained.

**Why can't `WHERE` use a `SELECT` alias?**

```sql
SELECT price - cost AS margin FROM products WHERE margin > 200;   -- ERROR
```

`WHERE` is step 2. Aliases are created at step 5. The name doesn't exist yet.
✅ Explained. (Day 7, Part 4.)

**Why *can* `ORDER BY` use a `SELECT` alias?**

```sql
SELECT price - cost AS margin FROM products ORDER BY margin DESC;   -- works
```

`ORDER BY` is step 7, after step 5. The alias exists by then. ✅ Explained.
(Day 5, Part 4.)

**Why can `HAVING` use aggregates?**

`HAVING` is step 4, after `GROUP BY` at step 3. The groups and their aggregates
exist. ✅ Explained.

**Why can't `HAVING` use a `SELECT` alias?**

```sql
SELECT customer_id, count(*) AS orders FROM orders
GROUP BY customer_id HAVING orders > 3;
```

```
ERROR:  column "orders" does not exist
```

`HAVING` is step 4; aliases arrive at step 5. Repeat the aggregate instead:
`HAVING count(*) > 3`. ✅ Explained.

**Why can `GROUP BY` use an alias in PostgreSQL?**

```sql
SELECT category_id AS cat, count(*) FROM products GROUP BY cat;   -- works 🐘
```

This one is a **PostgreSQL extension**, not the standard — the standard would
require `GROUP BY category_id`. Postgres resolves output names in `GROUP BY` as
a convenience. It does *not* extend the same courtesy to `WHERE` or `HAVING`.
Don't rely on it in portable SQL.

**Why does `DISTINCT` come after `SELECT`?**

Because `SELECT DISTINCT` removes duplicates from the **output** rows, which
only exist once the expressions have been evaluated. That's why
`SELECT DISTINCT price - cost FROM products` de-duplicates margins, not rows.

**Why does `LIMIT` come last?**

Because "the top 5" means the top 5 of the *finished, sorted* result. That's why
`LIMIT` without `ORDER BY` is meaningless (Day 5).

### The summary table

| Clause | Step | Sees `SELECT` aliases? | Sees aggregates? |
|---|---|---|---|
| `FROM` | 1 | no | no |
| `WHERE` | 2 | **no** | **no** |
| `GROUP BY` | 3 | yes 🐘 (Postgres only) | no |
| `HAVING` | 4 | **no** | **yes** |
| `SELECT` | 5 | no (not its own siblings) | yes |
| `DISTINCT` | 6 | yes | yes |
| `ORDER BY` | 7 | **yes** | **yes** |
| `LIMIT` | 8 | n/a | n/a |

▶ **Try it** — copy this table into `mistakes.md`. You will refer to it for the
next three phases, and by Phase 6 you will know it cold.

---

## Part 4 — `HAVING` without `GROUP BY`

Legal, and occasionally useful:

```sql
SELECT count(*) AS n, round(avg(price), 2) AS mean_price
FROM   products
HAVING count(*) > 20;
```

```
 n  | mean_price
----+------------
 25 |     325.22
```

With no `GROUP BY`, **the whole table is one group**. The `HAVING` then decides
whether that single row is returned at all.

```sql
SELECT count(*) FROM products HAVING count(*) > 100;
```

```
(0 rows)
```

Zero rows — not a row containing 0. That's different from Day 19's empty-set
behaviour, and worth understanding: the group *was* formed and counted (25), the
`HAVING` rejected it, and so nothing is emitted.

This pattern is genuinely used for assertions: *"return a row only if the count
is wrong"* is a data-quality check you can schedule.

---

## Part 5 — Putting a row condition in `HAVING`

This works:

```sql
SELECT category_id, count(*) AS n
FROM   products
GROUP  BY category_id
HAVING category_id <> 9;
```

You can reference the **grouping key** in `HAVING`, because it has one value per
group. But compare:

```sql
-- (A) filter rows first
SELECT category_id, count(*) FROM products
WHERE category_id <> 9 GROUP BY category_id;

-- (B) filter groups after
SELECT category_id, count(*) FROM products
GROUP BY category_id HAVING category_id <> 9;
```

Both return the same six rows. But (A) discards category-9 rows *before* doing
any grouping work, while (B) builds the category-9 group, computes its count,
and then throws the whole thing away.

> **Rule: if a condition can be expressed in `WHERE`, put it in `WHERE`.**
> Reserve `HAVING` for conditions that genuinely need an aggregate.

On 25 rows this is invisible. On 200 million rows it is the difference between
a query that finishes and one that doesn't — filtering early means fewer rows
to sort, fewer groups to build, and less memory for the hash table.

💡 In fairness, PostgreSQL's planner is often smart enough to push a simple
`HAVING` condition on a grouping key down into `WHERE` itself. But it cannot
always do so, it gives you no warning when it doesn't, and writing the intent
correctly costs nothing. Don't outsource clarity to the optimiser.

⚠️ **What you cannot do** is reference a non-grouped, non-aggregated column:

```sql
SELECT category_id, count(*) FROM products
GROUP BY category_id HAVING price > 100;
```

```
ERROR:  column "products.price" must appear in the GROUP BY clause
        or be used in an aggregate function
```

The familiar error. Within a group, `price` has many values — so "is price
greater than 100?" has no single answer. You meant either
`WHERE price > 100` (rows) or `HAVING max(price) > 100` / `HAVING avg(price) >
100` (groups), and they are three different questions.

---

## Part 6 — Worked business questions

These are the shapes you will reuse constantly.

**Customers who ordered more than three times in 2024:**

```sql
SELECT customer_id, count(*) AS orders
FROM   orders
WHERE  order_date >= DATE '2024-01-01'
  AND  order_date <  DATE '2025-01-01'
GROUP  BY customer_id
HAVING count(*) > 3
ORDER  BY orders DESC, customer_id;
```

`WHERE` narrows to 2024 first; `HAVING` then applies to the 2024 counts. Getting
this order wrong — filtering the year in `HAVING` — is impossible here, because
`order_date` isn't a grouping key. The database protects you.

**Orders worth more than €1000:**

```sql
SELECT order_id,
       round(sum(quantity * unit_price * (1 - discount_pct)), 2) AS order_total
FROM   order_items
GROUP  BY order_id
HAVING sum(quantity * unit_price * (1 - discount_pct)) > 1000
ORDER  BY order_total DESC;
```

Note the expression is repeated — `HAVING` cannot use the `order_total` alias.
Ugly. A CTE (Day 41) fixes it properly; today you repeat it.

**Products reviewed more than twice with an average rating below 4:**

```sql
SELECT product_id,
       count(*)              AS reviews,
       round(avg(rating), 2) AS mean_rating
FROM   reviews
GROUP  BY product_id
HAVING count(*) > 2
  AND  avg(rating) < 4
ORDER  BY mean_rating;
```

Two aggregate conditions, joined with `AND` — all of Day 8's precedence rules
apply unchanged inside `HAVING`.

**Categories where the price spread exceeds €500:**

```sql
SELECT category_id,
       min(price) AS cheapest,
       max(price) AS dearest,
       max(price) - min(price) AS spread
FROM   products
GROUP  BY category_id
HAVING max(price) - min(price) > 500
ORDER  BY spread DESC;
```

**Months with more than three orders:**

```sql
SELECT date_trunc('month', order_date)::date AS month,
       count(*) AS orders
FROM   orders
GROUP  BY 1
HAVING count(*) > 3
ORDER  BY month;
```

**Finding duplicates — the classic `HAVING` idiom:**

```sql
SELECT email, count(*) AS n
FROM   customers
GROUP  BY email
HAVING count(*) > 1;
```

Zero rows, because `customers.email` has a `UNIQUE` constraint. But **this is
the query you run on any table where you suspect duplicates**, and it is worth
committing to memory:

```sql
SELECT <the columns that should be unique>, count(*)
FROM   <table>
GROUP  BY <those columns>
HAVING count(*) > 1;
```

🎯 **Interview** — "How do you find duplicate rows?" That exact pattern. The
follow-up — "now delete all but one of each" — needs `ROW_NUMBER()` (Day 47) or
`ctid` (Day 73), and saying so is a good answer even before you can write it.

---

## Traps & Gotchas

| # | Trap | What happens |
|---|---|---|
| 1 | `WHERE count(*) > 3` | Error — aggregates aren't available at step 2 |
| 2 | `HAVING orders > 3` using a `SELECT` alias | `column does not exist` — repeat the aggregate |
| 3 | Row condition in `HAVING` instead of `WHERE` | Works, but does needless grouping work |
| 4 | Non-grouped column in `HAVING` | `must appear in the GROUP BY clause` |
| 5 | Confusing (A) `WHERE x < 500` with (B) `HAVING avg(x) < 500` | Different questions, different answers |
| 6 | Expecting `HAVING` without `GROUP BY` to return a zero row | It returns **no** row |
| 7 | Repeating a long aggregate in `HAVING` | Unavoidable until CTEs (Day 41) |
| 8 | Assuming the logical order is the execution order | It's a semantic contract; the planner reorders |

---

## Interview angles

- **Junior** — "Customers with more than 3 orders." →
  `GROUP BY customer_id HAVING count(*) > 3`
- **Junior** — "`WHERE` vs `HAVING`?" → rows before grouping vs groups after.
- **Mid** — "Recite the logical processing order." → `FROM` → `WHERE` →
  `GROUP BY` → `HAVING` → `SELECT` → `DISTINCT` → `ORDER BY` → `LIMIT`.
- **Mid** — "Why can `ORDER BY` use an alias but `WHERE` can't?" → Aliases are
  created at the `SELECT` step, which is after `WHERE` and before `ORDER BY`.
- **Mid** — "Find duplicate emails." → the `GROUP BY … HAVING count(*) > 1`
  idiom.
- **Mid** — "Is there a performance difference between filtering in `WHERE` and
  `HAVING`?" → Yes when the condition doesn't need an aggregate: `WHERE` cuts
  rows before the sort/hash, so less work and less memory. The planner may push
  it down, but don't rely on that.
- **Senior** — "Explain why `SELECT DISTINCT` and `GROUP BY` sit at different
  steps." → `GROUP BY` (step 3) partitions the input so aggregates can be
  computed; `DISTINCT` (step 6) de-duplicates the finished output rows. They
  coincide only when there are no aggregates, which is why they often produce
  the same plan for de-duplication.
- **Senior** — "A `HAVING` on a 100-million-row aggregation is slow. What do you
  look at?" → Whether any of the condition can move to `WHERE`; whether the
  `GROUP BY` is hashing or sorting and whether it spills (`work_mem`); whether
  the group count is enormous (high-cardinality key); whether a pre-aggregated
  rollup or materialized view is the real answer. Days 77, 78, 90, 98.

---

## Practice

> Available: everything from Days 1–20, plus `HAVING`.
> **Not yet:** `FILTER` (Day 22), joins (Day 27), subqueries (Day 36).
> For every problem, decide **before writing it** whether the condition belongs
> in `WHERE` or `HAVING`.

### Section A — Drill (new concept only)

1. Categories with more than 3 products.
2. Categories with fewer than 4 products.
3. Categories whose average price exceeds 300.
4. Categories whose total price exceeds 1000.
5. Categories whose maximum price exceeds 500.
6. Categories where the price spread (`max - min`) exceeds 400.
7. Countries with more than one customer.
8. Countries with exactly one customer.
9. Loyalty tiers with more than 4 customers.
10. Departments with more than 2 employees.
11. Departments whose average salary exceeds 55000.
12. Departments whose total salary exceeds 150000.
13. Order statuses with more than 3 orders.
14. Customers with more than 3 orders.
15. Customers with exactly one order.
16. Salespeople (`employee_id`) with more than 10 orders.
17. Orders with more than one line item.
18. Orders with exactly one line item.
19. Orders with 3 or more line items.
20. Products ordered more than 3 times.
21. Products with more than 2 reviews.
22. Products whose average rating is below 4.
23. Ratings given more than 5 times.
24. Payment methods used more than 5 times.
25. Payment methods whose total exceeds 5000.

### Section B — Combination (with Days 01–20)

26. Categories with more than 2 in-stock, non-discontinued products.
27. Categories whose average price among in-stock products exceeds 200.
28. Customers with more than 2 orders placed in 2024.
29. Customers with more than 1 order placed in 2025.
30. Months with more than 3 orders, sorted chronologically.
31. Months whose total shipping cost exceeds 30.
32. Orders whose total value exceeds 1000, rounded, highest first.
33. Orders whose total value is under 100, rounded, lowest first.
34. Products whose total units sold exceeds 3.
35. Products whose total revenue exceeds 2000, rounded, highest first.
36. Shipping countries with more than 3 orders.
37. Signup years with more than 5 customers.
38. Price bands (`premium`/`mid-range`/`budget`/`accessory`) with more than 4
    products.
39. Departments with more than 2 employees hired before 2022.
40. Products with more than 2 reviews **and** an average rating below 4.5.
41. Products whose total helpful votes exceed 50.
42. Customers who have written more than 2 reviews.
43. Categories with more than 3 products, showing count, average price and
    total inventory value.
44. Months in 2024 with more than 4 orders.
45. Order statuses whose average shipping cost exceeds 5.
46. Suppliers supplying more than 3 products.
47. Commission rates shared by more than one employee.
48. ISO weekdays with more than 8 orders.
49. Customers whose total shipping cost paid exceeds 25.
50. Categories where every product is in stock — expressed as
    "the count of out-of-stock products in the group is zero".

### Section C — Recall (Days 01–20)

51. Whole-table count, sum, avg, min, max of `products.price`.
52. `count(*)` vs `count(loyalty_tier)` on `customers`, explained.
53. Number of products per category — how many rows, and which three
    categories are missing?
54. Number of customers per loyalty tier — how many rows, and why?
55. `sum(price)` over an empty set.
56. Products in categories 3 or 4 priced under 700.
57. Payments in December 2024, half-open range.
58. `concat_ws('-', 'a', NULL, 'b')` versus `'a' || NULL || 'b'`.
59. The last day of the month containing `2024-02-10`.
60. Reset the database and verify the nine row counts.

### Section D — Challenge

61. Write the two queries from Part 2 — `WHERE price < 500 GROUP BY category_id`
    and `GROUP BY category_id HAVING avg(price) < 500` — run both, and explain
    in two sentences why category 4 appears in one and not the other.
62. Run `SELECT customer_id, count(*) AS orders FROM orders GROUP BY customer_id
    HAVING orders > 3;`. Read the error, explain it using the processing order,
    and fix it.
63. Run `SELECT category_id, count(*) FROM products GROUP BY category_id
    HAVING price > 100;`. Read the error and write **three** different queries
    that each fix it, saying what each one now asks.
64. Write `SELECT count(*) FROM products HAVING count(*) > 100;`. How many rows
    come back? How is that different from `SELECT sum(price) FROM products
    WHERE false;`?
65. Write the duplicate-finder idiom against `customers.email`. Why does it
    return nothing? Now run it against `orders.customer_id` and explain why that
    one *does* return rows.
66. Express "categories with more than 3 products" twice — once with `HAVING
    count(*) > 3` and once by putting the condition in `WHERE`. Show that the
    second is impossible, and say why in one sentence.
67. Find every order whose total value exceeds €1000 **and** which has more than
    one line item. Note how many times you have to repeat the sum expression,
    and write one sentence about what Day 41 will give you.
68. Using `HAVING` on the whole table with no `GROUP BY`, write a data-quality
    assertion that returns a row **only if** `products` does not contain exactly
    25 rows. Then break the data (delete a product), confirm the assertion
    fires, and reset.
69. Reproduce the summary table from Part 3 from memory — for each of `WHERE`,
    `GROUP BY`, `HAVING`, `SELECT`, `ORDER BY`, state whether it can see a
    `SELECT` alias and whether it can see an aggregate. Then verify each cell
    with an actual query.
70. Design question: a colleague's dashboard query filters `WHERE status =
    'delivered'` and reports "average order value". The finance team's figure is
    higher. Give three distinct reasons the two numbers could legitimately
    differ, using only concepts from Days 19–21.

---

## Solutions

### Section A

**1.** `SELECT category_id, count(*) AS n FROM products GROUP BY category_id HAVING count(*) > 3 ORDER BY n DESC;` → 3 rows (10, 1, 9)
**2.** `... HAVING count(*) < 4;` → 4 rows (3, 4, 6, 7)
**3.** `... HAVING avg(price) > 300;` → 3 rows (3, 4, 1 — run it)
**4.** `... HAVING sum(price) > 1000;` → categories 3 and 4
**5.** `... HAVING max(price) > 500;` → categories 3, 4
**6.** `... HAVING max(price) - min(price) > 400;`
**7.** `SELECT country, count(*) FROM customers GROUP BY country HAVING count(*) > 1;` → 2 rows? No — Germany (4), India (2), France (2) → **3 rows**
**8.** `... HAVING count(*) = 1;` → 16 rows
**9.** `SELECT loyalty_tier, count(*) FROM customers GROUP BY loyalty_tier HAVING count(*) > 4;` → bronze (7), silver (6), gold (5)
**10.** `SELECT department, count(*) FROM employees GROUP BY department HAVING count(*) > 2;` → Sales, Support, Warehouse
**11.** `... HAVING avg(salary) > 55000;` → Management (185000), Sales (61200)
**12.** `... HAVING sum(salary) > 150000;` → Management (185000), Sales (306000), Support (162000)
**13.** `SELECT status, count(*) FROM orders GROUP BY status HAVING count(*) > 3;` → delivered only
**14.** `SELECT customer_id, count(*) FROM orders GROUP BY customer_id HAVING count(*) > 3;` → 6 rows
**15.** `... HAVING count(*) = 1;` → 5 rows (customers 7, 8, 15, 21, 24)
**16.** `SELECT employee_id, count(*) FROM orders GROUP BY employee_id HAVING count(*) > 10;` → employees 5 (16), 6 (17), 7 (11)
**17.** `SELECT order_id, count(*) FROM order_items GROUP BY order_id HAVING count(*) > 1;` → 39 rows
**18.** `... HAVING count(*) = 1;` → 21 rows
**19.** `... HAVING count(*) >= 3;` → 4 rows (orders 3, 13, 30, 38)
**20.** `SELECT product_id, count(*) FROM order_items GROUP BY product_id HAVING count(*) > 3;`
**21.** `SELECT product_id, count(*) FROM reviews GROUP BY product_id HAVING count(*) > 2;` → 4 rows (products 1, 2, 4, 7)
**22.** `SELECT product_id, round(avg(rating),2) FROM reviews GROUP BY product_id HAVING avg(rating) < 4;`
**23.** `SELECT rating, count(*) FROM reviews GROUP BY rating HAVING count(*) > 5;` → ratings 5 (15) and 4 (13)
**24.** `SELECT method, count(*) FROM payments GROUP BY method HAVING count(*) > 5;` → card (37), paypal (9)
**25.** `SELECT method, round(sum(amount),2) FROM payments GROUP BY method HAVING sum(amount) > 5000;`

### Section B

**26.**
```sql
SELECT category_id, count(*) AS n FROM products
WHERE  stock_quantity > 0 AND NOT is_discontinued
GROUP  BY category_id HAVING count(*) > 2 ORDER BY n DESC;
```
**27.**
```sql
SELECT category_id, round(avg(price),2) AS mean_price FROM products
WHERE  stock_quantity > 0
GROUP  BY category_id HAVING avg(price) > 200 ORDER BY mean_price DESC;
```
**28.**
```sql
SELECT customer_id, count(*) AS orders FROM orders
WHERE  order_date >= DATE '2024-01-01' AND order_date < DATE '2025-01-01'
GROUP  BY customer_id HAVING count(*) > 2 ORDER BY orders DESC, customer_id;
```
**29.** Same with the 2025 range and `HAVING count(*) > 1` → customers 1, 3, 6
(run it).
**30.**
```sql
SELECT date_trunc('month', order_date)::date AS month, count(*) AS orders
FROM   orders GROUP BY 1 HAVING count(*) > 3 ORDER BY month;
```
**31.** Same with `HAVING sum(shipping_cost) > 30`.
**32.**
```sql
SELECT order_id, round(sum(quantity*unit_price*(1-discount_pct)),2) AS total
FROM   order_items GROUP BY order_id
HAVING sum(quantity*unit_price*(1-discount_pct)) > 1000
ORDER  BY total DESC;
```
**33.** Same with `< 100` and `ORDER BY total`.
**34.** `SELECT product_id, sum(quantity) AS units FROM order_items GROUP BY product_id HAVING sum(quantity) > 3 ORDER BY units DESC;`
**35.**
```sql
SELECT product_id, round(sum(quantity*unit_price*(1-discount_pct)),2) AS revenue
FROM   order_items GROUP BY product_id
HAVING sum(quantity*unit_price*(1-discount_pct)) > 2000
ORDER  BY revenue DESC;
```
**36.** `SELECT shipping_country, count(*) AS n FROM orders GROUP BY 1 HAVING count(*) > 3 ORDER BY n DESC;`
**37.** `SELECT EXTRACT(YEAR FROM signup_date)::int AS yr, count(*) FROM customers GROUP BY 1 HAVING count(*) > 5 ORDER BY 1;` → 2023 (9), 2024 (8)
**38.**
```sql
SELECT CASE WHEN price >= 1000 THEN 'premium'
            WHEN price >= 300  THEN 'mid-range'
            WHEN price >= 50   THEN 'budget'
            ELSE                    'accessory' END AS band,
       count(*) AS n
FROM   products GROUP BY 1 HAVING count(*) > 4 ORDER BY n DESC;
```
**39.**
```sql
SELECT department, count(*) AS n FROM employees
WHERE  hire_date < DATE '2022-01-01'
GROUP  BY department HAVING count(*) > 2;
```
**40.**
```sql
SELECT product_id, count(*) AS reviews, round(avg(rating),2) AS mean_rating
FROM   reviews GROUP BY product_id
HAVING count(*) > 2 AND avg(rating) < 4.5
ORDER  BY mean_rating;
```
**41.** `SELECT product_id, sum(helpful_votes) AS votes FROM reviews GROUP BY product_id HAVING sum(helpful_votes) > 50 ORDER BY votes DESC;`
**42.** `SELECT customer_id, count(*) AS n FROM reviews GROUP BY customer_id HAVING count(*) > 2 ORDER BY n DESC;`
**43.**
```sql
SELECT category_id, count(*) AS n, round(avg(price),2) AS mean_price,
       round(sum(price*stock_quantity),2) AS inventory_value
FROM   products GROUP BY category_id HAVING count(*) > 3 ORDER BY n DESC;
```
**44.**
```sql
SELECT date_trunc('month', order_date)::date AS month, count(*) AS orders
FROM   orders
WHERE  order_date >= DATE '2024-01-01' AND order_date < DATE '2025-01-01'
GROUP  BY 1 HAVING count(*) > 4 ORDER BY month;
```
**45.** `SELECT status, round(avg(shipping_cost),2) AS mean_ship FROM orders GROUP BY status HAVING avg(shipping_cost) > 5 ORDER BY mean_ship DESC;`
**46.** `SELECT supplier_id, count(*) AS n FROM products GROUP BY supplier_id HAVING count(*) > 3 ORDER BY n DESC;` → suppliers 2 (6), 6 (5), 4 (4)
**47.** `SELECT commission_pct, count(*) FROM employees GROUP BY commission_pct HAVING count(*) > 1;` → 0.040 (2 employees) and the NULL group (7)
**48.** `SELECT EXTRACT(ISODOW FROM order_date)::int AS wd, count(*) FROM orders GROUP BY 1 HAVING count(*) > 8 ORDER BY 1;`
**49.** `SELECT customer_id, round(sum(shipping_cost),2) AS ship FROM orders GROUP BY customer_id HAVING sum(shipping_cost) > 25 ORDER BY ship DESC;`
**50.**
```sql
SELECT category_id, count(*) AS n
FROM   products
GROUP  BY category_id
HAVING sum(CASE WHEN stock_quantity = 0 THEN 1 ELSE 0 END) = 0
ORDER  BY category_id;
```
"Every product in stock" expressed as "zero out-of-stock products". Conditional
aggregation inside `HAVING` — a very useful pattern. Day 23's `bool_and` says
the same thing more directly.

### Section C

**51.** `SELECT count(*), sum(price), avg(price), min(price), max(price) FROM products;`
**52.** 24 and 20 — `count(*)` counts rows; `count(loyalty_tier)` skips the four NULLs.
**53.** 7 rows. Categories 2, 5 and 8 are missing — they are parent categories with no products directly assigned.
**54.** 5 rows — the four tiers plus a `NULL` group. `GROUP BY` buckets NULLs together.
**55.** `NULL`.
**56.** `WHERE (category_id = 3 OR category_id = 4) AND price < 700;`
**57.** `WHERE paid_at >= '2024-12-01' AND paid_at < '2025-01-01';`
**58.** `a-b` and `NULL`.
**59.** `2024-02-29`.
**60.** `\i 99_reset.sql`

### Section D

**61.**
```sql
SELECT category_id, round(avg(price),2) FROM products
WHERE price < 500 GROUP BY category_id ORDER BY category_id;      -- (A)

SELECT category_id, round(avg(price),2) FROM products
GROUP BY category_id HAVING avg(price) < 500 ORDER BY category_id; -- (B)
```
Category 4 (Phones: 999, 699, 299) appears in **(A)** with an average of 299.00,
because `WHERE` discarded the two expensive phones before averaging and only
`Old Phone 2020` survived. It is absent from **(B)**, because (B) averages all
three phones — 665.67 — which fails the `< 500` test.

(A) asks "among cheap products, what's the average per category?" (B) asks
"which categories are cheap on average?" Both are reasonable; they are not the
same question, and a stakeholder saying "average price under 500" has not told
you which one they mean.

**62.**
```
ERROR:  column "orders" does not exist
```
`HAVING` is step 4 in the logical order; `SELECT` aliases are created at step 5.
The name `orders` does not exist yet when `HAVING` is evaluated. Fix by
repeating the aggregate:
```sql
SELECT customer_id, count(*) AS orders FROM orders
GROUP BY customer_id HAVING count(*) > 3;
```
(Note the confusing collision: the alias `orders` and the table `orders` share a
name. PostgreSQL resolves `orders` in `HAVING` as neither — it looks for a
column and fails.)

**63.**
```
ERROR:  column "products.price" must appear in the GROUP BY clause
```
Three fixes, three different questions:
```sql
-- (a) rows: count only the products priced over 100
SELECT category_id, count(*) FROM products WHERE price > 100 GROUP BY category_id;

-- (b) groups by their maximum: categories containing at least one product over 100
SELECT category_id, count(*) FROM products GROUP BY category_id HAVING max(price) > 100;

-- (c) groups by their average: categories whose average price exceeds 100
SELECT category_id, count(*) FROM products GROUP BY category_id HAVING avg(price) > 100;
```
(a) changes the counts. (b) and (c) leave the counts alone and select different
groups. The error is PostgreSQL refusing to guess which of the three you meant,
which is the correct behaviour.

**64.** `SELECT count(*) FROM products HAVING count(*) > 100;` → **0 rows**.

The whole table formed one group, `count(*)` evaluated to 25, the `HAVING`
rejected the group, and nothing was emitted.

`SELECT sum(price) FROM products WHERE false;` → **1 row containing `NULL`**.
Here the group was formed from zero rows and *not* rejected, so a row is emitted
with `NULL` in it (Day 19, Part 5).

The distinction: `HAVING` removes the row; an empty aggregate keeps the row and
fills it with `NULL`. This trips people up when a query that "should return a
zero" returns nothing at all.

**65.**
```sql
SELECT email, count(*) FROM customers GROUP BY email HAVING count(*) > 1;  -- 0 rows
SELECT customer_id, count(*) FROM orders GROUP BY customer_id HAVING count(*) > 1; -- 15 rows
```
The first returns nothing because `customers.email` carries a `UNIQUE`
constraint — duplicates are impossible by construction, and the query is
effectively an assertion that the constraint is doing its job.

The second returns rows because `orders.customer_id` is a **foreign key**, not a
unique key: a customer is *supposed* to have many orders. Same query shape,
completely different meaning — which is the point. The idiom finds "more than
one row per key"; whether that's a bug depends entirely on whether the key was
meant to be unique.

**66.**
```sql
SELECT category_id, count(*) FROM products GROUP BY category_id HAVING count(*) > 3;
SELECT category_id, count(*) FROM products WHERE count(*) > 3 GROUP BY category_id;  -- ERROR
```
The second is impossible because `WHERE` is evaluated at step 2, before any
group exists — there is nothing for `count(*)` to count yet, and the condition
refers to a property of a group that has not been formed.

**67.**
```sql
SELECT order_id,
       count(*) AS items,
       round(sum(quantity * unit_price * (1 - discount_pct)), 2) AS total
FROM   order_items
GROUP  BY order_id
HAVING sum(quantity * unit_price * (1 - discount_pct)) > 1000
  AND  count(*) > 1
ORDER  BY total DESC;
```
The sum expression appears **twice** — once in `SELECT` for display, once in
`HAVING` for filtering — because `HAVING` cannot see the alias. On Day 41 a CTE
lets you compute it once, name it, and then filter and display the name:
```sql
WITH totals AS (
    SELECT order_id, count(*) AS items,
           sum(quantity * unit_price * (1 - discount_pct)) AS total
    FROM order_items GROUP BY order_id
)
SELECT order_id, items, round(total, 2) FROM totals
WHERE total > 1000 AND items > 1 ORDER BY total DESC;
```
Note that in the CTE version the filter is a plain `WHERE`, because by then
`total` is just a column of a finished result. That's the real reason CTEs feel
like a relief.

**68.**
```sql
SELECT 'products row count is wrong: ' || count(*) AS alert
FROM   products
HAVING count(*) <> 25;
```
Returns **0 rows** when the data is correct — which is exactly what you want
from an assertion: silence means healthy. Now break it:
```sql
DELETE FROM products WHERE product_id = 25;
-- rerun the assertion → 1 row: "products row count is wrong: 24"
\i 99_reset.sql
```
(The `DELETE` may fail with a foreign-key error if the product is referenced;
product 25 was never ordered and has no reviews, which is why it's the safe one
to pick. That itself is a preview of Day 57.)

This "return a row only on failure" shape is how scheduled data-quality checks
are written in practice — a monitoring job runs the query and alerts if it
returns anything.

**69.**

| Clause | Sees alias? | Sees aggregate? | Verify with |
|---|---|---|---|
| `WHERE` | no | no | `WHERE margin > 200` → error; `WHERE count(*) > 1` → error |
| `GROUP BY` | **yes** 🐘 | no | `SELECT category_id AS c … GROUP BY c` → works |
| `HAVING` | no | **yes** | `HAVING orders > 3` → error; `HAVING count(*) > 3` → works |
| `SELECT` | no (siblings) | yes | `SELECT price*2 AS d, d*2` → error |
| `ORDER BY` | **yes** | **yes** | `ORDER BY margin DESC` → works; `ORDER BY count(*)` → works |

Run every cell. Producing five errors on purpose in five minutes is worth more
than reading the table ten times.

**70.** Three legitimate reasons, all from Days 19–21:

1. **Different denominators (`avg` vs NULLs).** If "order value" is computed
   from a column that can be `NULL` for some orders, `avg` divides by
   `count(that column)`, not `count(*)`. Finance may be dividing total revenue
   by *all* delivered orders while the dashboard's `avg` silently excludes the
   ones with no value. Day 19, Part 4.

2. **Different row sets before aggregation.** The dashboard filters
   `status = 'delivered'` in `WHERE`. If finance includes `shipped` and `paid`
   orders — revenue they consider booked — they are averaging a different
   population. Nothing is wrong with either; they answer different questions.
   Day 21, Part 2.

3. **Different grain.** "Average order value" computed over `order_items`
   (average *line* value) is not the same as computed over per-order totals
   (average *order* value). An order with four cheap lines drags the first down
   and the second up. This is the most common version of the bug in practice,
   and it is invisible unless someone asks "average of what?"

A fourth, worth mentioning if you want to sound like you've lived it: **shipping
and refunds.** Does "order value" include `shipping_cost`? Does it net off the
two refunded orders? Two teams will answer differently and both will be sure
they're right.

The professional move is not to guess which is correct — it's to write both
queries, show the two numbers side by side, and make the definitional choice
explicit and documented.

---

## Day 21 Checklist

- [ ] I can filter groups with `HAVING`
- [ ] **I know `WHERE` filters rows before grouping and `HAVING` filters groups
      after**
- [ ] I can recite the eight-step logical processing order
- [ ] I can explain *from that order* why `WHERE` sees no aliases and no
      aggregates
- [ ] I can explain why `ORDER BY` sees both
- [ ] I know `HAVING` cannot use a `SELECT` alias, and I repeat the aggregate
- [ ] I put a condition in `WHERE` whenever it doesn't need an aggregate
- [ ] I know `HAVING` without `GROUP BY` treats the table as one group and can
      return **zero** rows
- [ ] I know the duplicate-finder idiom by heart
- [ ] I can state three reasons two teams' "average order value" might differ

---

## What's next

**Day 22 — Multi-key grouping, `FILTER`, and conditional aggregation.** You have
been writing `sum(CASE WHEN … THEN 1 ELSE 0 END)` since Day 19. Tomorrow
PostgreSQL's `FILTER (WHERE …)` clause makes that pattern readable, and
`count(DISTINCT …)` per group unlocks questions like "how many distinct products
did each customer buy?" It is the most immediately practical day in the phase.
