# Day 23 — Collection and Statistical Aggregates

> **Phase** 3 · Aggregation
> **Level** Confident Beginner
> **Time** 110–140 minutes
> **Prerequisites** Days 01–22
> **New concepts** `string_agg` · `array_agg` · `ORDER BY` inside an aggregate · `bool_and` / `bool_or` / `every` · ordered-set aggregates · `percentile_cont` · `percentile_disc` · `mode()` · `stddev` / `variance` · median vs mean · `jsonb_agg` (preview)

---

## Why this matters

Every aggregate so far has collapsed a group into a **number**. Today you meet
two that collapse a group into a **list** — so "every product in this category,
comma-separated" becomes one line of SQL instead of a loop in your application.

And you meet the median. `avg` is the aggregate everyone reaches for and it is
frequently the wrong one: our 25 products have a mean price of €325 and a median
of €130. One of those numbers describes a typical product and the other
describes a laptop. Knowing which to report — and being able to compute both —
is the difference between a report that informs and one that misleads.

---

## Part 1 — `string_agg`: a group as text

```sql
SELECT category_id,
       count(*) AS n,
       string_agg(product_name, ', ') AS products
FROM   products
WHERE  category_id = 9
GROUP  BY category_id;
```

```
 category_id | n |                                products
-------------+---+------------------------------------------------------------
           9 | 4 | Clean Code, The Pragmatic Programmer, SQL Performance Ex…
```

`string_agg(expression, delimiter)` concatenates every value in the group.

⚠️ **But the order is undefined.** Run it twice and you may get a different
order. That's Day 2's rule — rows have no inherent order — surfacing inside an
aggregate.

### `ORDER BY` inside the aggregate

```sql
SELECT category_id,
       string_agg(product_name, ', ' ORDER BY product_name) AS products
FROM   products
GROUP  BY category_id
ORDER  BY category_id;
```

```
 category_id | products
-------------+-------------------------------------------------------------------
           1 | Bluetooth Speaker, Noise Cancelling Headphones, Smart Watch, Tablet 10
           3 | Budget Laptop 15, Laptop Air 13, Laptop Pro 14
           4 | Old Phone 2020, Smartphone Mini, Smartphone X
           6 | Blender 500W, Chef Knife, Coffee Maker
           7 | Bookshelf, Office Chair, Standing Desk
           9 | Clean Code, Designing Data-Intensive Applications, SQL Performa…
          10 | Laptop Stand, Mechanical Keyboard, USB-C Hub, Webcam HD, Wireles…
```

**That `ORDER BY` goes inside the parentheses**, and it is not the query's
`ORDER BY` — it orders the values *within each group*. This syntax is unique to
aggregates and it surprises people the first time.

```sql
-- sort the list by price instead of name
string_agg(product_name, ', ' ORDER BY price DESC)

-- multiple sort keys work as usual
string_agg(product_name, ', ' ORDER BY price DESC, product_name)
```

> **Always put `ORDER BY` inside `string_agg` and `array_agg`.** Without it the
> output is non-deterministic, which makes it useless for comparing two runs,
> for tests, and for anything a human will read twice.

### Useful shapes

```sql
-- numbered list per order
SELECT order_id,
       string_agg(product_id::text, ' + ' ORDER BY product_id) AS product_ids
FROM   order_items GROUP BY order_id ORDER BY order_id LIMIT 5;

-- one line per department
SELECT department,
       count(*) AS n,
       string_agg(first_name || ' ' || last_name, '; ' ORDER BY last_name) AS team
FROM   employees GROUP BY department ORDER BY department;

-- distinct values only
SELECT country, string_agg(DISTINCT COALESCE(loyalty_tier, 'none'), ', ') AS tiers
FROM   customers GROUP BY country ORDER BY country;
```

⚠️ `string_agg(DISTINCT x, ', ' ORDER BY x)` works, but the `ORDER BY` must
then sort by the **same expression** as the `DISTINCT`. `string_agg(DISTINCT
name, ',' ORDER BY price)` is an error — PostgreSQL can't de-duplicate on one
key and order by another.

⚠️ **NULLs are skipped**, like every aggregate:

```sql
SELECT string_agg(city, ', ' ORDER BY city) FROM customers;
```

The two city-less customers contribute nothing — no empty entry, no double
comma. That is usually what you want, and unlike `||` (Day 4) it does not
destroy the whole string.

💡 **Size warning.** `string_agg` over a large group builds one enormous text
value in memory. Aggregating a million names into one cell will work and will
be a terrible idea. It is for small groups and human-readable summaries.

---

## Part 2 — `array_agg`: a group as an array

```sql
SELECT category_id,
       array_agg(product_name ORDER BY price DESC) AS products
FROM   products
GROUP  BY category_id
ORDER  BY category_id;
```

```
 category_id |                     products
-------------+--------------------------------------------------
           3 | {"Laptop Pro 14","Laptop Air 13","Budget Laptop 15"}
           4 | {"Smartphone X","Smartphone Mini","Old Phone 2020"}
```

Same idea, but the result is a real **array**, not text. `{…}` is PostgreSQL's
array literal syntax.

Why prefer it to `string_agg`?

- The application gets a genuine list rather than a string it has to split.
- Elements keep their type — `array_agg(price)` gives you numbers.
- You can operate on it: `array_length`, indexing, `unnest` to turn it back into
  rows.

```sql
SELECT category_id,
       array_agg(price ORDER BY price)         AS prices,
       array_length(array_agg(price), 1)       AS n,
       (array_agg(product_name ORDER BY price DESC))[1] AS most_expensive
FROM   products
GROUP  BY category_id
ORDER  BY category_id;
```

That last column is a "top-1 per group" trick: build the array sorted
descending, take element 1. Legal, and occasionally handy — but `DISTINCT ON`
(Day 5) or a window function (Day 47) express the intent far better. Reach for
those first.

🐘 Arrays are PostgreSQL-specific and get a full day on **Day 69**. Today you
only need `array_agg` as the typed sibling of `string_agg`.

💡 **Preview: `jsonb_agg` and `jsonb_object_agg`** build JSON instead of arrays,
which is how you return nested structures to an application in one query:

```sql
SELECT category_id, jsonb_agg(product_name ORDER BY product_name) AS products
FROM   products GROUP BY category_id;
```

Day 68.

---

## Part 3 — `bool_and` and `bool_or`

Two aggregates that answer "do **all** / **any** rows in this group satisfy
something?"

```sql
SELECT category_id,
       count(*)                          AS products,
       bool_and(stock_quantity > 0)      AS all_in_stock,
       bool_or(stock_quantity = 0)       AS any_out_of_stock,
       bool_and(NOT is_discontinued)     AS all_current
FROM   products
GROUP  BY category_id
ORDER  BY category_id;
```

```
 category_id | products | all_in_stock | any_out_of_stock | all_current
-------------+----------+--------------+------------------+-------------
           1 |        4 | t            | f                | t
           3 |        3 | f            | t                | t
           4 |        3 | f            | t                | f
           6 |        3 | t            | f                | t
           7 |        3 | f            | t                | t
           9 |        4 | t            | f                | t
          10 |        5 | f            | t                | f
```

| Aggregate | Returns true when |
|---|---|
| `bool_and(cond)` | **every** row in the group satisfies `cond` |
| `bool_or(cond)` | **at least one** row satisfies `cond` |
| `every(cond)` | exact synonym for `bool_and` (SQL standard spelling) |

Compare with yesterday's workaround:

```sql
-- Day 21/22 way
HAVING sum(CASE WHEN stock_quantity = 0 THEN 1 ELSE 0 END) = 0

-- Day 23 way
HAVING bool_and(stock_quantity > 0)
```

Both mean "every product in this category is in stock". The second reads like
the sentence.

They work beautifully in `HAVING`:

```sql
-- categories where everything is in stock
SELECT category_id, count(*) FROM products
GROUP BY category_id HAVING bool_and(stock_quantity > 0);

-- customers who have never had an order cancelled
SELECT customer_id, count(*) AS orders FROM orders
GROUP BY customer_id HAVING bool_and(status <> 'cancelled')
ORDER BY orders DESC, customer_id;
```

⚠️ **NULL handling is the usual story**: NULL inputs are skipped. So
`bool_and` over a group where *every* value is NULL returns `NULL`, not `true` —
the vacuous-truth case is a NULL, not a yes. Guard with `COALESCE` if a NULL
would be misread as false downstream.

---

## Part 4 — Median, and why `avg` misleads

```sql
SELECT count(*)                                              AS n,
       round(avg(price), 2)                                  AS mean,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY price)    AS median,
       min(price)                                            AS lo,
       max(price)                                            AS hi
FROM   products;
```

```
 n  |  mean  | median |  lo   |   hi
----+--------+--------+-------+---------
 25 | 325.22 | 129.99 | 29.99 | 1899.00
```

**The mean is €325. The median is €130.** Two and a half times apart, from the
same 25 rows.

The mean is dragged upward by a handful of expensive items — a €1899 laptop
counts as much as fourteen mice. The median — the middle value when sorted — is
unmoved by them. If someone asks "what does a typical product cost?", €130 is
the honest answer and €325 is the one most reports give.

Same story with salaries:

```sql
SELECT round(avg(salary), 2)                                AS mean,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY salary)  AS median
FROM   employees;
```

```
   mean   | median
----------+---------
 66541.67 | 52500.0
```

One CEO at €185,000 moves the mean by €14,000. The median says what most people
earn.

> **Rule: for anything with a long tail — prices, salaries, response times,
> order values, session durations — report the median, or report both.** Mean
> alone is how dashboards mislead honestly.

### The `WITHIN GROUP` syntax

```sql
percentile_cont(fraction) WITHIN GROUP (ORDER BY expression)
```

This is an **ordered-set aggregate**: it needs its input sorted to mean
anything, so the sort is part of the call. The `WITHIN GROUP (ORDER BY …)` is
mandatory and is not the query's `ORDER BY`.

### `percentile_cont` vs `percentile_disc`

```sql
SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY salary) AS cont_median,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY salary) AS disc_median
FROM   employees;
```

```
 cont_median | disc_median
-------------+-------------
     52500.0 |    51000.00
```

| Function | Behaviour |
|---|---|
| `percentile_cont` | **Continuous** — interpolates between values. May return a number that is not in the data. |
| `percentile_disc` | **Discrete** — returns an actual value from the data. |

With 12 salaries, the median sits between the 6th (51,000) and 7th (54,000).
`percentile_cont` interpolates to 52,500 — which nobody earns.
`percentile_disc` picks 51,000 — a real salary.

**Which to use:** `cont` for continuous quantities (money, durations, weights)
where an interpolated value is meaningful. `disc` when the result must be a
real, existing value — a real date, a real category, an actual row's value.

⚠️ `percentile_cont` only works on numeric and interval types, because it has to
interpolate. `percentile_disc` works on anything sortable, including text and
dates.

### Other percentiles

```sql
SELECT percentile_cont(0.25) WITHIN GROUP (ORDER BY price) AS p25,
       percentile_cont(0.50) WITHIN GROUP (ORDER BY price) AS median,
       percentile_cont(0.75) WITHIN GROUP (ORDER BY price) AS p75,
       percentile_cont(0.95) WITHIN GROUP (ORDER BY price) AS p95
FROM   products;
```

Or several at once by passing an array:

```sql
SELECT percentile_cont(ARRAY[0.25, 0.5, 0.75, 0.95])
         WITHIN GROUP (ORDER BY price) AS quartiles
FROM   products;
```

💡 **p95 and p99 are how latency is reported**, everywhere. "Average response
time 120ms" tells you nothing; "p99 response time 4 seconds" tells you one
request in a hundred is awful. When you reach Day 80 and start measuring query
performance, percentiles are the vocabulary.

### Per group

```sql
SELECT department,
       count(*)                                               AS n,
       round(avg(salary), 2)                                  AS mean,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY salary)    AS median
FROM   employees
GROUP  BY department
ORDER  BY median DESC;
```

---

## Part 5 — `mode()`

The most frequent value:

```sql
SELECT mode() WITHIN GROUP (ORDER BY rating) AS most_common_rating
FROM   reviews;
```

```
 most_common_rating
--------------------
                  5
```

Note the empty parentheses — `mode()` takes no argument; the column comes from
the `WITHIN GROUP (ORDER BY …)`.

```sql
SELECT mode() WITHIN GROUP (ORDER BY loyalty_tier) AS most_common_tier
FROM   customers;                                       -- bronze

SELECT mode() WITHIN GROUP (ORDER BY status) AS most_common_status
FROM   orders;                                          -- delivered

SELECT category_id,
       mode() WITHIN GROUP (ORDER BY supplier_id) AS usual_supplier
FROM   products GROUP BY category_id ORDER BY category_id;
```

⚠️ On a tie, `mode()` returns the **first** value in the sort order. It does not
tell you a tie occurred. If ties matter, use `GROUP BY … ORDER BY count(*) DESC`
and look at the top few.

---

## Part 6 — Spread: `stddev` and `variance`

```sql
SELECT round(avg(price), 2)            AS mean,
       round(stddev(price), 2)         AS std_dev,
       round(variance(price), 2)       AS variance,
       max(price) - min(price)         AS range
FROM   products;
```

| Function | Meaning |
|---|---|
| `stddev(x)` / `stddev_samp(x)` | **sample** standard deviation (divides by n−1) |
| `stddev_pop(x)` | **population** standard deviation (divides by n) |
| `variance(x)` / `var_samp(x)` | sample variance |
| `var_pop(x)` | population variance |

`stddev` defaults to the **sample** version. Use `_pop` only when your rows are
the entire population rather than a sample of one — which, for a table of all
your products, they arguably are. In practice the difference is negligible
unless n is tiny.

⚠️ `stddev` of a single row returns `NULL` (you cannot divide by n−1 = 0), while
`stddev_pop` returns `0`. That bites on grouped queries with small groups:

```sql
SELECT category_id, count(*), round(stddev(price), 2)
FROM products GROUP BY category_id;
```

Every group here has ≥3 rows so all are fine — but a one-product category would
show a blank, not a zero.

💡 A high standard deviation relative to the mean means the mean is not
describing the data well — which is your cue to reach for the median.

---

## Part 7 — Putting it together

```sql
SELECT category_id,
       count(*)                                                AS products,
       round(avg(price), 2)                                    AS mean_price,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY price)      AS median_price,
       round(stddev(price), 2)                                 AS std_dev,
       bool_and(stock_quantity > 0)                            AS all_in_stock,
       count(*) FILTER (WHERE is_discontinued)                 AS discontinued,
       string_agg(product_name, ', ' ORDER BY price DESC)      AS items
FROM   products
GROUP  BY category_id
HAVING count(*) > 2
ORDER  BY median_price DESC;
```

Everything from Phase 3 in one query: grouping, filtering groups, a filtered
count, two measures of centre, a measure of spread, a boolean summary, and a
readable list. This is what a real analytical query looks like.

▶ **Try it.** Then read down the `mean_price` and `median_price` columns and
find the category where they diverge most.

---

## Traps & Gotchas

| # | Trap | What happens |
|---|---|---|
| 1 | `string_agg`/`array_agg` without `ORDER BY` | Non-deterministic output |
| 2 | Putting the `ORDER BY` outside the aggregate | Orders the result rows, not the list |
| 3 | `string_agg(DISTINCT a ORDER BY b)` | Error — must order by the same expression |
| 4 | `string_agg` over a huge group | One giant value; memory |
| 5 | Forgetting `WITHIN GROUP` on `percentile_*`/`mode()` | Syntax error |
| 6 | `percentile_cont` on text | Error — use `percentile_disc` |
| 7 | Reporting `avg` for skewed data | Misleads; use the median |
| 8 | `percentile_cont(0.5)` returning a value nobody has | Expected — it interpolates |
| 9 | `mode()` on a tie | Silently returns the first in sort order |
| 10 | `stddev` of a one-row group | `NULL`, not `0` |
| 11 | `bool_and` over all-NULL group | `NULL`, not `true` |

---

## Interview angles

- **Junior** — "List all products in each category, comma-separated." →
  `string_agg(product_name, ', ' ORDER BY product_name)`
- **Junior** — "Median salary." →
  `percentile_cont(0.5) WITHIN GROUP (ORDER BY salary)`
- **Mid** — "Mean vs median — when does it matter?" → Skewed distributions;
  give the price or salary example with real numbers.
- **Mid** — "`percentile_cont` vs `percentile_disc`?" → Interpolated vs an
  actual data value; `disc` when the answer must exist in the data.
- **Mid** — "Find categories where every product is in stock." →
  `HAVING bool_and(stock_quantity > 0)`
- **Mid** — "Why is `string_agg` output different between runs?" → No
  `ORDER BY` inside the aggregate; row order is not guaranteed.
- **Senior** — "Report API latency." → p50/p95/p99 via `percentile_cont`, and
  explain why the mean hides tail latency. Mention that percentiles are **not
  mergeable** — you cannot average yesterday's p95 and today's p95 to get the
  two-day p95 — which is why latency rollups store histograms (t-digest,
  `tdigest` extension) rather than percentiles.
- **Senior** — "`percentile_cont` over 500 million rows is slow." → It is an
  ordered-set aggregate: it must sort or fully materialise the group. Options:
  approximate via `tdigest`/`hdr_histogram` extensions, pre-aggregate into
  buckets, or sample. Day 80, Day 103.

---

## Practice

> Available: everything from Days 1–22, plus `string_agg`, `array_agg`,
> `bool_and`/`bool_or`, `percentile_cont`/`percentile_disc`, `mode()`,
> `stddev`/`variance`.

### Section A — Drill (new concept only)

1. All product names in category 9, comma-separated, ordered by name.
2. All product names per category, comma-separated, ordered by name.
3. All product names per category, ordered by price descending.
4. All employee full names per department, semicolon-separated, ordered by
   last name.
5. All distinct loyalty tiers per country, comma-separated.
6. All order ids per customer, comma-separated, ordered numerically.
7. All product ids per order as text, joined with ` + `.
8. All product names per category as an **array**, ordered by name.
9. All prices per category as an array, ordered ascending.
10. The array length of the product array per category.
11. The most expensive product per category, via `(array_agg(… ORDER BY price DESC))[1]`.
12. Per category: is every product in stock?
13. Per category: is any product out of stock?
14. Per category: is every product current (not discontinued)?
15. Per customer: has every order avoided cancellation?
16. Per department: does everyone earn over 35000?
17. The whole-table median product price.
18. The whole-table mean product price. Compare with 17.
19. The whole-table median salary.
20. The whole-table mean salary. Compare with 19.
21. `percentile_cont(0.5)` and `percentile_disc(0.5)` of salary, side by side.
    Explain the difference.
22. The 25th, 50th, 75th and 95th percentiles of product price.
23. The same four, returned as a single array.
24. The most common review rating.
25. The most common loyalty tier.
26. The most common order status.
27. The standard deviation and variance of product price.
28. `stddev` and `stddev_pop` of salary, side by side.
29. Median price per category.
30. Median salary per department.

### Section B — Combination (with Days 01–22)

31. Per category: count, mean price, median price, and the difference between
    them, largest difference first.
32. Per department: headcount, mean salary, median salary, standard deviation.
33. Per category: product list (name, ordered by price descending) and total
    inventory value.
34. Per customer: order count and a comma-separated list of their order
    statuses, ordered by order date.
35. Per order: a comma-separated list of product ids and the order total.
36. Per category: products, and whether every one of them costs over 30.
37. Categories where every product is in stock (use `HAVING`).
38. Categories where at least one product is discontinued.
39. Customers who have never had an order cancelled or returned.
40. Departments where everybody earns over 40000.
41. Per month: order count, distinct customers, and a list of statuses seen.
42. Per rating: count and a list of the product ids reviewed at that rating.
43. Per supplier: product count, median price, and the product list.
44. Per loyalty tier: customer count, median age at 2025-01-01, and country
    list.
45. Per category: mean price, median price, and a flag saying whether the mean
    exceeds the median by more than 50%.
46. Per payment method: count, median amount, and mean amount.
47. Per year: order count, median shipping cost, and the list of distinct
    shipping countries.
48. Per product: review count, mean rating, median rating, and modal rating.
49. Per category: count and a list of only the out-of-stock product names.
    (Hint: `FILTER` works on `string_agg` too.)
50. Per department: headcount, and a list of only those employees who earn
    commission.

### Section C — Recall (Days 01–22)

51. Customers with more than 3 orders.
52. Pivot: orders per salesperson by status.
53. Recite the eight-step logical processing order.
54. Why does `count(CASE WHEN x THEN 1 ELSE 0 END)` count every row?
55. `count(*)` vs `count(city)` on `customers`.
56. Products per category — how many rows, which categories missing?
57. `sum(price)` over an empty set.
58. Monthly active customers.
59. Delivered percentage per salesperson, correctly avoiding integer division.
60. Reset the database and verify the nine row counts.

### Section D — Challenge

61. Run `string_agg(product_name, ', ')` on `products` grouped by category
    **without** an inner `ORDER BY`, several times. Does the order change? Why
    is relying on it a bug even if it doesn't?
62. Show the mean and median product price side by side, compute the ratio, and
    write one sentence explaining which you would put on a dashboard labelled
    "typical product price".
63. Do the same for salary, and identify which single row is responsible for the
    gap.
64. Show `percentile_cont(0.5)` and `percentile_disc(0.5)` of salary and explain
    why one of them returns a value no employee earns.
65. Compute the median product price per category and find the category where
    mean and median diverge most. Explain what that tells you about its
    contents.
66. Write a query listing, per category, only the **out-of-stock** product
    names, using `FILTER` on `string_agg`. What do categories with no
    out-of-stock products show, and why?
67. Find customers all of whose orders were delivered, two ways — once with
    `bool_and`, once with conditional aggregation — and confirm they agree.
68. `stddev` of a one-row group returns `NULL` while `stddev_pop` returns `0`.
    Construct a query over `products` that demonstrates this. (Hint: group by
    something almost unique.)
69. Build a one-query "category health report": category id, product count,
    median price, percentage out of stock to 1 decimal, whether all are current,
    and the product list ordered by price descending — restricted to categories
    with at least 3 products, sorted by median price descending.
70. Design question: your monitoring team stores one row per minute containing
    the p95 response time for that minute. They ask you to compute the p95 for
    the whole day by averaging the 1,440 values. Explain why that is wrong, what
    they should store instead, and what you would do with the data they already
    have.

---

## Solutions

### Section A

**1.** `SELECT string_agg(product_name, ', ' ORDER BY product_name) FROM products WHERE category_id = 9;`
**2.** `SELECT category_id, string_agg(product_name, ', ' ORDER BY product_name) FROM products GROUP BY category_id ORDER BY category_id;`
**3.** Same with `ORDER BY price DESC` inside.
**4.** `SELECT department, string_agg(first_name || ' ' || last_name, '; ' ORDER BY last_name) FROM employees GROUP BY department ORDER BY department;`
**5.** `SELECT country, string_agg(DISTINCT COALESCE(loyalty_tier,'none'), ', ') FROM customers GROUP BY country ORDER BY country;`
**6.** `SELECT customer_id, string_agg(order_id::text, ', ' ORDER BY order_id) FROM orders GROUP BY customer_id ORDER BY customer_id;`
**7.** `SELECT order_id, string_agg(product_id::text, ' + ' ORDER BY product_id) FROM order_items GROUP BY order_id ORDER BY order_id;`
**8.** `SELECT category_id, array_agg(product_name ORDER BY product_name) FROM products GROUP BY category_id ORDER BY category_id;`
**9.** `SELECT category_id, array_agg(price ORDER BY price) FROM products GROUP BY category_id ORDER BY category_id;`
**10.** `SELECT category_id, array_length(array_agg(product_name), 1) AS n FROM products GROUP BY category_id;` — equals `count(*)` in every row.
**11.** `SELECT category_id, (array_agg(product_name ORDER BY price DESC))[1] AS dearest FROM products GROUP BY category_id ORDER BY category_id;`
**12.** `SELECT category_id, bool_and(stock_quantity > 0) FROM products GROUP BY category_id ORDER BY category_id;`
**13.** `SELECT category_id, bool_or(stock_quantity = 0) FROM products GROUP BY category_id ORDER BY category_id;`
**14.** `SELECT category_id, bool_and(NOT is_discontinued) FROM products GROUP BY category_id ORDER BY category_id;`
**15.** `SELECT customer_id, bool_and(status <> 'cancelled') FROM orders GROUP BY customer_id ORDER BY customer_id;`
**16.** `SELECT department, bool_and(salary > 35000) FROM employees GROUP BY department;` → all `t`
**17.** `SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY price) FROM products;` → 129.99
**18.** `SELECT round(avg(price),2) FROM products;` → 325.22. **Two and a half
times the median.**
**19.** `SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY salary) FROM employees;` → 52500.0
**20.** `SELECT round(avg(salary),2) FROM employees;` → 66541.67
**21.**
```sql
SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY salary) AS cont,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY salary) AS disc
FROM   employees;
```
→ 52500.0 and 51000.00. With an even number of rows the true middle lies between
the 6th and 7th values; `cont` interpolates to the midpoint, `disc` returns the
actual 6th value.
**22.**
```sql
SELECT percentile_cont(0.25) WITHIN GROUP (ORDER BY price) AS p25,
       percentile_cont(0.50) WITHIN GROUP (ORDER BY price) AS p50,
       percentile_cont(0.75) WITHIN GROUP (ORDER BY price) AS p75,
       percentile_cont(0.95) WITHIN GROUP (ORDER BY price) AS p95
FROM   products;
```
**23.** `SELECT percentile_cont(ARRAY[0.25,0.5,0.75,0.95]) WITHIN GROUP (ORDER BY price) FROM products;`
**24.** `SELECT mode() WITHIN GROUP (ORDER BY rating) FROM reviews;` → 5
**25.** `SELECT mode() WITHIN GROUP (ORDER BY loyalty_tier) FROM customers;` → bronze
**26.** `SELECT mode() WITHIN GROUP (ORDER BY status) FROM orders;` → delivered
**27.** `SELECT round(stddev(price),2), round(variance(price),2) FROM products;`
**28.** `SELECT round(stddev(salary),2) AS samp, round(stddev_pop(salary),2) AS pop FROM employees;`
**29.** `SELECT category_id, percentile_cont(0.5) WITHIN GROUP (ORDER BY price) AS median FROM products GROUP BY category_id ORDER BY median DESC;`
**30.** `SELECT department, percentile_cont(0.5) WITHIN GROUP (ORDER BY salary) AS median FROM employees GROUP BY department ORDER BY median DESC;`

### Section B

**31.**
```sql
SELECT category_id, count(*) AS n,
       round(avg(price), 2)                               AS mean,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY price) AS median,
       round(avg(price) - percentile_cont(0.5) WITHIN GROUP (ORDER BY price), 2)
         AS mean_minus_median
FROM   products GROUP BY category_id ORDER BY mean_minus_median DESC;
```
**32.**
```sql
SELECT department, count(*) AS n, round(avg(salary),2) AS mean,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY salary) AS median,
       round(stddev(salary),2) AS std_dev
FROM   employees GROUP BY department ORDER BY median DESC;
```
**33.**
```sql
SELECT category_id,
       string_agg(product_name, ', ' ORDER BY price DESC) AS items,
       round(sum(price * stock_quantity), 2)              AS inventory_value
FROM   products GROUP BY category_id ORDER BY inventory_value DESC;
```
**34.**
```sql
SELECT customer_id, count(*) AS orders,
       string_agg(status, ', ' ORDER BY order_date) AS status_history
FROM   orders GROUP BY customer_id ORDER BY orders DESC, customer_id;
```
**35.**
```sql
SELECT order_id,
       string_agg(product_id::text, ', ' ORDER BY product_id) AS products,
       round(sum(quantity * unit_price * (1 - discount_pct)), 2) AS total
FROM   order_items GROUP BY order_id ORDER BY total DESC LIMIT 10;
```
**36.** `SELECT category_id, count(*), bool_and(price > 30) FROM products GROUP BY category_id ORDER BY category_id;`
**37.** `SELECT category_id, count(*) FROM products GROUP BY category_id HAVING bool_and(stock_quantity > 0);` → categories 1, 6, 9
**38.** `SELECT category_id, count(*) FROM products GROUP BY category_id HAVING bool_or(is_discontinued);` → categories 4 and 10
**39.**
```sql
SELECT customer_id, count(*) AS orders FROM orders
GROUP  BY customer_id
HAVING bool_and(status NOT IN ('cancelled','returned'))
ORDER  BY orders DESC, customer_id;
```
**40.** `SELECT department, count(*) FROM employees GROUP BY department HAVING bool_and(salary > 40000);`
**41.**
```sql
SELECT date_trunc('month', order_date)::date AS month, count(*) AS orders,
       count(DISTINCT customer_id) AS customers,
       string_agg(DISTINCT status, ', ') AS statuses
FROM   orders GROUP BY 1 ORDER BY month;
```
**42.** `SELECT rating, count(*), string_agg(DISTINCT product_id::text, ', ') FROM reviews GROUP BY rating ORDER BY rating DESC;`
**43.**
```sql
SELECT supplier_id, count(*) AS n,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY price) AS median,
       string_agg(product_name, ', ' ORDER BY product_name) AS items
FROM   products GROUP BY supplier_id ORDER BY supplier_id NULLS LAST;
```
**44.**
```sql
SELECT COALESCE(loyalty_tier, 'none') AS tier, count(*) AS customers,
       percentile_cont(0.5) WITHIN GROUP (
         ORDER BY EXTRACT(YEAR FROM age(DATE '2025-01-01', birth_date))) AS median_age,
       string_agg(DISTINCT country, ', ') AS countries
FROM   customers GROUP BY loyalty_tier ORDER BY customers DESC;
```
**45.**
```sql
SELECT category_id,
       round(avg(price), 2)                                AS mean,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY price)  AS median,
       avg(price) > 1.5 * percentile_cont(0.5) WITHIN GROUP (ORDER BY price)
         AS heavily_skewed
FROM   products GROUP BY category_id ORDER BY category_id;
```
**46.**
```sql
SELECT method, count(*) AS n,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY amount) AS median,
       round(avg(amount), 2) AS mean
FROM   payments GROUP BY method ORDER BY n DESC;
```
**47.**
```sql
SELECT EXTRACT(YEAR FROM order_date)::int AS yr, count(*) AS orders,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY shipping_cost) AS median_ship,
       string_agg(DISTINCT shipping_country, ', ') AS countries
FROM   orders GROUP BY 1 ORDER BY 1;
```
**48.**
```sql
SELECT product_id, count(*) AS reviews,
       round(avg(rating), 2)                               AS mean_rating,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY rating) AS median_rating,
       mode() WITHIN GROUP (ORDER BY rating)               AS modal_rating
FROM   reviews GROUP BY product_id ORDER BY reviews DESC, product_id;
```
Note `percentile_disc` here, not `cont` — a "median rating" of 4.5 stars is not
a rating anyone gave.
**49.**
```sql
SELECT category_id, count(*) AS products,
       string_agg(product_name, ', ' ORDER BY product_name)
         FILTER (WHERE stock_quantity = 0) AS out_of_stock_items
FROM   products GROUP BY category_id ORDER BY category_id;
```
**50.**
```sql
SELECT department, count(*) AS headcount,
       string_agg(first_name, ', ' ORDER BY first_name)
         FILTER (WHERE commission_pct IS NOT NULL) AS commissioned
FROM   employees GROUP BY department ORDER BY department;
```

### Section C

**51.** `GROUP BY customer_id HAVING count(*) > 3` → 6 rows
**52.** The six `count(*) FILTER (WHERE status = …)` columns from Day 22.
**53.** `FROM` → `WHERE` → `GROUP BY` → `HAVING` → `SELECT` → `DISTINCT` →
`ORDER BY` → `LIMIT`
**54.** Because `count` counts non-NULL **values**, and `ELSE 0` gives every row
a non-NULL value.
**55.** 24 and 22.
**56.** 7 rows; categories 2, 5, 8 missing.
**57.** `NULL`.
**58.** `SELECT date_trunc('month', order_date)::date, count(DISTINCT customer_id) FROM orders GROUP BY 1 ORDER BY 1;`
**59.** `round(100.0 * count(*) FILTER (WHERE status='delivered') / count(*), 1)`
**60.** `\i 99_reset.sql`

### Section D

**61.** In practice the order will probably look stable, because the planner
scans the table the same way each time and nothing has moved. It is still a bug:
the moment the table is updated, vacuumed, indexed, or the plan goes parallel,
the order can change — and a parallel plan in particular can interleave groups
arbitrarily. You would then have a report whose text changed with no code change
and no data change, which is close to undebuggable.

The rule from Day 5 — *if the order matters, say so* — applies inside aggregates
too.

**62.**
```sql
SELECT round(avg(price), 2)                                AS mean,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY price)  AS median,
       round(avg(price) / percentile_cont(0.5) WITHIN GROUP (ORDER BY price), 2)
         AS ratio
FROM   products;
```
→ 325.22, 129.99, ratio ≈ 2.50.

A dashboard labelled "typical product price" should show **€129.99**. The mean
is not wrong as a statistic — total catalogue value divided by item count is a
real quantity — but it answers a different question, and no reader interprets
"typical" as "arithmetic mean of a right-skewed distribution".

**63.**
```sql
SELECT round(avg(salary), 2)                                 AS mean,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY salary)   AS median
FROM   employees;                                     -- 66541.67 vs 52500.0

SELECT first_name, last_name, job_title, salary
FROM   employees ORDER BY salary DESC LIMIT 1;        -- Sofia Lindqvist, CEO, 185000
```
One row — the CEO at €185,000, nearly twice the next-highest salary — lifts the
mean by roughly €14,000 across twelve people. This is exactly why published
"average salary" figures are usually medians, and why the mean/median gap is
itself a useful statistic.

**64.** See A21. `percentile_cont` interpolates between the 6th (51,000) and 7th
(54,000) salaries to produce 52,500 — a salary **nobody earns**. That is correct
behaviour for a continuous quantity: it estimates where the true middle of the
distribution lies. `percentile_disc` refuses to invent a value and returns
51,000, which is a real employee's real salary. Choose `disc` whenever the
output will be read as "an actual value from the data".

**65.**
```sql
SELECT category_id, count(*) AS n,
       round(avg(price), 2)                               AS mean,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY price) AS median,
       round(avg(price) - percentile_cont(0.5) WITHIN GROUP (ORDER BY price), 2)
         AS gap
FROM   products GROUP BY category_id ORDER BY gap DESC;
```
Category **3** (Laptops: 1899, 1099, 549) leads — mean 1182.33, median 1099.00.
Category **4** (Phones: 999, 699, 299) is close behind — mean 665.67, median
699.00, a *negative* gap, meaning it is left-skewed: one unusually cheap item
drags the mean below the middle.

The general reading: a positive gap means a few expensive outliers; a negative
gap means a few cheap ones; a gap near zero means the group is symmetric and the
mean is safe to quote.

**66.**
```sql
SELECT category_id, count(*) AS products,
       string_agg(product_name, ', ' ORDER BY product_name)
         FILTER (WHERE stock_quantity = 0) AS out_of_stock_items
FROM   products GROUP BY category_id ORDER BY category_id;
```
Categories with nothing out of stock (1, 6, 9) show **`NULL`**, not an empty
string. The `FILTER` removed every row from that aggregate's input, and
`string_agg` over an empty set returns `NULL` — the same empty-set rule as `sum`
on Day 19. Wrap it if a blank reads better:
`COALESCE(string_agg(…) FILTER (…), 'none')`.

**67.**
```sql
-- with bool_and
SELECT customer_id, count(*) AS orders FROM orders
GROUP BY customer_id HAVING bool_and(status = 'delivered')
ORDER BY customer_id;

-- with conditional aggregation
SELECT customer_id, count(*) AS orders FROM orders
GROUP BY customer_id
HAVING count(*) FILTER (WHERE status <> 'delivered') = 0
ORDER BY customer_id;
```
Identical results. The first says "every order was delivered"; the second says
"zero orders were not delivered". `bool_and` is the clearer expression of
intent; the `FILTER` form is what you'd write on a database without `bool_and`.

**68.**
```sql
SELECT product_id,
       count(*)              AS n,
       stddev(price)         AS samp,
       stddev_pop(price)     AS pop
FROM   products GROUP BY product_id ORDER BY product_id LIMIT 5;
```
Grouping by the primary key gives 25 groups of exactly one row. Every `samp`
column is `NULL` (sample standard deviation divides by n−1 = 0) and every `pop`
column is `0` (a single point has no spread from itself).

This matters in real reports: group by something with a long tail of
single-member groups — a per-customer statistic, say — and half your standard
deviations come back blank. Use `stddev_pop`, or filter to groups with
`HAVING count(*) > 1`, and say which you chose.

**69.**
```sql
SELECT category_id,
       count(*)                                                   AS products,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY price)         AS median_price,
       round(100.0 * count(*) FILTER (WHERE stock_quantity = 0)
                   / count(*), 1)                                 AS out_of_stock_pct,
       bool_and(NOT is_discontinued)                              AS all_current,
       string_agg(product_name, ', ' ORDER BY price DESC)         AS items
FROM   products
GROUP  BY category_id
HAVING count(*) >= 3
ORDER  BY median_price DESC;
```
Seven rows (every category has at least 3 products). Read the
`out_of_stock_pct` column against `all_current` — a category that is fully
current but 33% out of stock is a restocking problem, not a discontinuation
problem, and the two columns together tell you that at a glance. That is what a
good summary query does: put the numbers that get compared next to each other.

**70.** **Why averaging p95s is wrong:** percentiles are **not linearly
mergeable**. The 95th percentile of a day is the value below which 95% of the
day's *requests* fall — but averaging 1,440 per-minute p95s weights every minute
equally regardless of how many requests it contained, and, more fundamentally,
there is no arithmetic that recovers a combined percentile from two component
percentiles. A minute with 3 requests and a minute with 30,000 contribute
equally. During an incident, the quiet minutes dilute the busy ones and the
daily figure looks better than the day felt.

The classic illustration: if half your minutes have p95 = 10ms and half have
p95 = 1000ms, the average is 505ms — a number that may correspond to no
percentile of the actual distribution at all.

**What they should store:** a **histogram** or sketch per minute, not a
percentile — t-digest, HDR histogram, or fixed latency buckets (a count of
requests in 0–10ms, 10–20ms, …). Those *are* mergeable: add the bucket counts
across minutes and compute the percentile from the combined histogram. In
PostgreSQL that's the `tdigest` extension, or a plain table of bucket counts,
which needs no extension at all and is often the better engineering choice.

**What to do with the data they already have:** you cannot recover the true
daily p95 from stored p95s — the information is gone. What you *can* honestly
report from it:

- `max()` of the per-minute p95 — "the worst minute of the day", which is a
  real and useful number.
- The per-minute p95 series itself, plotted, which shows *when* it was bad
  rather than pretending to a single summary.
- A **percentile of the per-minute p95s** (`percentile_cont(0.95) WITHIN GROUP
  (ORDER BY p95)`) — but label it precisely as "the 95th-percentile minute",
  not "the daily p95". They are different quantities and conflating them is the
  original error in a new costume.

The senior move is to say all three things: the requested number is not
computable, here is what the existing data *can* honestly tell you, and here is
the one-line change to the collector that makes it computable from tomorrow.

---

## Day 23 Checklist

- [ ] I can use `string_agg` and `array_agg` to collapse a group into a list
- [ ] **I always put `ORDER BY` inside the aggregate**
- [ ] I know `FILTER` works on `string_agg` too, and returns `NULL` when empty
- [ ] I can use `bool_and` / `bool_or` for "all" and "any" questions
- [ ] I can write `percentile_cont(0.5) WITHIN GROUP (ORDER BY x)` from memory
- [ ] **I know the median and the mean differ, and when to report which**
- [ ] I know `percentile_cont` interpolates and `percentile_disc` doesn't
- [ ] I can use `mode()`, and I know it hides ties
- [ ] I know `stddev` of a one-row group is `NULL`
- [ ] I know percentiles are not mergeable

---

## What's next

**Day 24 — `GROUPING SETS`, `ROLLUP` and `CUBE`.** Every report that shows
subtotals and a grand total — by category, by category *and* supplier, and the
whole catalogue — currently needs three separate queries stitched together.
Tomorrow it becomes one, and you meet the `GROUPING()` function that tells you
which level of subtotal a row belongs to.
