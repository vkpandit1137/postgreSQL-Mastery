# Day 08 — `AND`, `OR`, `NOT` and Operator Precedence

> **Phase** 2 · Filtering & Expressions
> **Level** Absolute Beginner
> **Time** 100–130 minutes
> **Prerequisites** Days 01–07
> **New concepts** `AND` · `OR` · `NOT` · precedence (`NOT` > `AND` > `OR`) · parentheses · De Morgan's laws · combining three or more conditions · short-circuit myths

---

## Why this matters

Yesterday every query asked one question. Real questions have several parts:
*"in-stock laptops under €1200"*, *"German or Austrian customers who signed up
this year"*, *"orders that are neither cancelled nor returned"*.

The syntax takes ten minutes. The **precedence** takes the rest of the day,
because `AND` binds tighter than `OR`, and that one fact has produced more
wrong-but-plausible reports than any other rule in SQL. A query with mixed
`AND`/`OR` and no parentheses does not error — it quietly answers a different
question than the one you asked.

---

## Part 1 — `AND`: every condition must hold

```sql
SELECT product_name, price, stock_quantity
FROM   products
WHERE  price > 500
  AND  stock_quantity > 0;
```

```
  product_name   |  price  | stock_quantity
-----------------+---------+----------------
 Laptop Pro 14   | 1899.00 |             12
 Laptop Air 13   | 1099.00 |             30
 Smartphone X    |  999.00 |             45
 Smartphone Mini |  699.00 |             20
(4 rows)
```

Yesterday `price > 500` alone gave 5 rows. Adding `AND stock_quantity > 0`
removed `Budget Laptop 15`, which is priced at 549.00 but has zero stock.

> **`AND` can only shrink a result, never grow it.** Every extra `AND`
> condition is a filter applied on top of the previous ones.

That property is worth holding on to: if adding an `AND` makes your row count go
*up*, you have made a mistake somewhere else in the query.

### Formatting

Put each condition on its own line, with the operator leading:

```sql
SELECT ...
FROM   ...
WHERE  price > 500
  AND  stock_quantity > 0
  AND  NOT is_discontinued;
```

Leading operators mean you can comment out one line without breaking the syntax,
and the conditions line up vertically so you can read them as a list. This
matters more than it sounds once a `WHERE` clause has eight conditions.

### More `AND` examples

```sql
-- German customers who are still active
SELECT first_name, last_name
FROM   customers
WHERE  country = 'Germany'
  AND  is_active;                              -- 4 rows

-- Sales employees earning over 50k
SELECT first_name, salary
FROM   employees
WHERE  department = 'Sales'
  AND  salary > 50000;                         -- 4 rows

-- Delivered orders placed in 2025
SELECT order_id, order_date, status
FROM   orders
WHERE  status = 'delivered'
  AND  order_date >= DATE '2025-01-01';        -- 2 rows
```

A range needs two conditions on the same column — perfectly normal:

```sql
SELECT product_name, price
FROM   products
WHERE  price >= 100
  AND  price <= 500;
```

Seven rows. (Tomorrow's `BETWEEN` is shorthand for exactly this.)

---

## Part 2 — `OR`: at least one condition must hold

```sql
SELECT product_name, category_id
FROM   products
WHERE  category_id = 9
   OR  category_id = 1;
```

Eight rows — the four books (category 9) plus the four Electronics items
(category 1).

> **`OR` can only grow a result, never shrink it** (relative to either branch
> alone).

```sql
-- customers in the top two tiers
SELECT first_name, loyalty_tier
FROM   customers
WHERE  loyalty_tier = 'gold'
   OR  loyalty_tier = 'platinum';              -- 7 rows

-- products that are either very cheap or out of stock
SELECT product_name, price, stock_quantity
FROM   products
WHERE  price < 40
   OR  stock_quantity = 0;
```

That last one is worth running. `price < 40` gives 4 rows, `stock_quantity = 0`
gives 4 rows, but the `OR` does **not** give 8 — `Old Phone 2020` and
`Webcam HD`… actually neither is under 40. Run it and count. The point stands
generally: `OR` returns the **union** of the two sets, and rows satisfying both
conditions appear once, not twice.

▶ **Try it** — run the three counts (`price < 40`, `stock_quantity = 0`, and
the `OR`) and confirm whether any row overlaps.

### `OR` on the same column is verbose

```sql
WHERE category_id = 1 OR category_id = 3 OR category_id = 4 OR category_id = 9
```

This works, and it is tedious. Tomorrow's `IN` collapses it to
`WHERE category_id IN (1, 3, 4, 9)`. Write the long form today so that `IN`
feels like the relief it is.

---

## Part 3 — `NOT`: invert a condition

```sql
SELECT product_name, price
FROM   products
WHERE  NOT (price > 500);
```

20 rows — the 25 products minus the 5 over 500. Identical to `WHERE price <= 500`.

`NOT` is most useful when the thing you're negating is not a simple comparison:

```sql
SELECT product_name FROM products WHERE NOT is_discontinued;     -- 23 rows
SELECT first_name  FROM customers WHERE NOT is_active;           --  2 rows
```

⚠️ **Trap** — `NOT` applies to **one** condition, the one immediately after it.

```sql
WHERE NOT price > 500 AND stock_quantity > 0
```

reads as

```sql
WHERE (NOT (price > 500)) AND (stock_quantity > 0)
```

not as `NOT (price > 500 AND stock_quantity > 0)`. If you mean the second, you
must write the parentheses. This is precedence, which is Part 4.

---

## Part 4 — Precedence: the rule that matters

When `AND` and `OR` appear in the same `WHERE` clause without parentheses,
PostgreSQL applies this order:

```
1. NOT     (binds tightest)
2. AND
3. OR      (binds loosest)
```

`AND` is effectively multiplication and `OR` is addition. Just as `2 + 3 * 4` is
14 and not 20, `a OR b AND c` is `a OR (b AND c)` and not `(a OR b) AND c`.

### Watch it happen

```sql
SELECT product_name, category_id, price
FROM   products
WHERE  category_id = 3
   OR  category_id = 4
  AND  price < 500;
```

```
   product_name   | category_id |  price
------------------+-------------+---------
 Laptop Pro 14    |           3 | 1899.00
 Laptop Air 13    |           3 | 1099.00
 Budget Laptop 15 |           3 |  549.00
 Old Phone 2020   |           4 |  299.00
(4 rows)
```

Four rows. Note that `Laptop Pro 14` costs 1899 and is in the result *despite*
`price < 500`. Because PostgreSQL read it as:

```sql
WHERE category_id = 3
   OR (category_id = 4 AND price < 500)
```

"All of category 3, **plus** the cheap items from category 4."

Now the version most people actually meant:

```sql
SELECT product_name, category_id, price
FROM   products
WHERE  (category_id = 3 OR category_id = 4)
  AND  price < 500;
```

```
  product_name  | category_id | price
----------------+-------------+--------
 Old Phone 2020 |           4 | 299.00
(1 row)
```

**One row.** Same three conditions, same operators, different parentheses —
4 rows versus 1. Neither query errors. Neither looks obviously wrong. One of
them is a report that goes to your finance team.

▶ **Try it** — run both. Then change the `AND`/`OR` order and predict the
result before running.

### The rule to adopt today

> **Whenever `AND` and `OR` appear in the same `WHERE` clause, parenthesise.
> Always. Even when the default precedence is what you want.**

The parentheses cost you two characters and remove an entire class of bug.
Nobody has ever been criticised in code review for making a boolean expression
unambiguous. Many people have shipped a wrong report for lack of two brackets.

### Full precedence table

You will mostly need the top and the bottom, but here is the whole thing:

| Precedence | Operators |
|---|---|
| highest | `::` (cast) |
| | `-` (unary minus) |
| | `^` |
| | `*` `/` `%` |
| | `+` `-` |
| | other operators (e.g. `\|\|`) |
| | `BETWEEN`, `IN`, `LIKE`, `ILIKE`, `SIMILAR` |
| | `<` `>` `=` `<=` `>=` `<>` |
| | `IS`, `ISNULL`, `NOTNULL` |
| | `NOT` |
| | `AND` |
| lowest | `OR` |

One consequence worth noting now: comparison binds tighter than `NOT`, so
`NOT price > 500` parses as `NOT (price > 500)` — which is what you want. But
arithmetic binds tighter than comparison, so `WHERE price - cost > 200` is
`WHERE (price - cost) > 200`, also what you want. The defaults are sensible
everywhere **except** `AND` versus `OR`, and that is the one place to be
disciplined.

---

## Part 5 — De Morgan's laws

Two identities that let you rewrite negations. They come up in interviews, and
more importantly they come up when you're trying to simplify a `WHERE` clause
that has grown hair.

```
NOT (a AND b)   ≡   (NOT a) OR  (NOT b)
NOT (a OR  b)   ≡   (NOT a) AND (NOT b)
```

Note the operator **flips** when you distribute the `NOT`. That flip is what
people get wrong.

In SQL:

```sql
-- "not (expensive and in stock)"
SELECT count(*) FROM products
WHERE NOT (price > 500 AND stock_quantity > 0);          -- 21

-- the same thing, distributed
SELECT count(*) FROM products
WHERE price <= 500 OR stock_quantity <= 0;               -- 21
```

```sql
-- "neither cancelled nor returned"
SELECT count(*) FROM orders
WHERE NOT (status = 'cancelled' OR status = 'returned'); -- 55

-- distributed
SELECT count(*) FROM orders
WHERE status <> 'cancelled' AND status <> 'returned';    -- 55
```

▶ **Try it** — verify all four counts yourself.

⚠️ **Trap** — the naive "distribution" people actually write is:

```sql
WHERE status <> 'cancelled' OR status <> 'returned'      -- 60 rows. Wrong.
```

Every order satisfies at least one of those — a cancelled order is not
returned, so the second half is true. The `OR` matches everything. This is
exactly the `AND`/`OR` flip that De Morgan warns about, and it is a classic
interview trip-up: *"find customers who are not in Germany or France"* is
`country <> 'Germany' AND country <> 'France'`, even though the English
sentence says "or".

🎯 **Interview** — "Find all employees not in Sales or Support." The correct
answer is `WHERE department <> 'Sales' AND department <> 'Support'` (or
`WHERE department NOT IN ('Sales','Support')`, Day 10). Candidates who write
`OR` get 12 rows instead of 4 and usually don't notice.

---

## Part 6 — Many conditions

Three or more conditions compose exactly as you'd expect, and the formatting
carries the meaning:

```sql
SELECT product_name, price, stock_quantity, category_id
FROM   products
WHERE  price BETWEEN 40 AND 300        -- (BETWEEN is tomorrow; ignore for now)
  AND  stock_quantity > 0
  AND  NOT is_discontinued
ORDER  BY price DESC;
```

With mixed operators, group explicitly and indent to show the structure:

```sql
SELECT order_id, status, order_date, shipping_cost
FROM   orders
WHERE  (status = 'delivered' OR status = 'shipped')
  AND  order_date >= DATE '2024-07-01'
  AND  shipping_cost > 0
ORDER  BY order_date;
```

Read that as: *"orders that are (delivered or shipped), and from the second half
of 2024 onwards, and that paid for shipping."* The indentation and brackets make
the sentence unambiguous to a human as well as to the parser.

### A realistic composite filter

```sql
SELECT product_name,
       price,
       stock_quantity,
       price - cost AS margin
FROM   products
WHERE  NOT is_discontinued
  AND  stock_quantity > 0
  AND  (price - cost) > 30
  AND  (category_id = 9 OR category_id = 10)
ORDER  BY margin DESC;
```

*"Sellable books and accessories with a margin over €30, best margin first."*
Four conditions, one `OR` group, all parenthesised. This is what production SQL
looks like.

---

## Part 7 — Two things people believe that aren't true

### "Put the cheapest condition first"

```sql
WHERE cheap_condition AND expensive_condition
```

PostgreSQL does **not** promise to evaluate `WHERE` conditions left to right.
The planner reorders them based on estimated cost and selectivity. Writing the
"cheap" one first has no reliable effect.

Order your conditions for **readability**, not for performance. If you genuinely
need to guarantee that one thing is evaluated before another — usually to avoid
an error, like a division by zero — the tool is `CASE` (Day 17), not clause
ordering.

### "`AND` short-circuits like in C or Python"

Related to the above: it doesn't, reliably. This bites in one specific way:

```sql
WHERE quantity <> 0 AND (total / quantity) > 10
```

You might expect the first condition to protect the second from dividing by
zero. It may — or the planner may evaluate the division first and raise
`division by zero`. Use `CASE`, or restructure, if correctness depends on the
order.

💡 **Note** — this is one of the genuine differences between SQL and imperative
languages, and it surprises experienced programmers more than beginners. SQL is
*declarative*: you describe the result, not the steps.

---

## Traps & Gotchas

| # | Trap | What happens |
|---|---|---|
| 1 | Mixing `AND`/`OR` without parentheses | `AND` binds tighter. Silently wrong result. |
| 2 | "not A or B" written as `A <> x OR A <> y` | Matches everything. Use `AND`. |
| 3 | `NOT a AND b` meaning `NOT (a AND b)` | `NOT` binds to `a` only. |
| 4 | Expecting `AND` to short-circuit | It doesn't, reliably. |
| 5 | Ordering conditions for speed | The planner reorders them anyway. |
| 6 | Adding an `AND` and seeing more rows | Impossible. Your query changed elsewhere. |
| 7 | `WHERE a = 1 OR 2` | Not a syntax error in some dialects; in Postgres it's a type error. Write `a = 1 OR a = 2`. |
| 8 | Any condition touching a nullable column | Rows with `NULL` fall out of **both** branches. **Day 9.** |

---

## Interview angles

- **Junior** — "In-stock products under €100." →
  `WHERE stock_quantity > 0 AND price < 100`
- **Junior** — "Which binds tighter, `AND` or `OR`?" → `AND`.
- **Mid** — "What's wrong with
  `WHERE country = 'DE' OR country = 'AT' AND is_active`?" → It parses as
  `country = 'DE' OR (country = 'AT' AND is_active)`, so inactive German
  customers are included. Needs brackets.
- **Mid** — "Rewrite `NOT (a AND b)` without the outer `NOT`." →
  `(NOT a) OR (NOT b)`. Name De Morgan.
- **Senior** — "Does Postgres short-circuit `AND`?" → No guarantee; the planner
  reorders quals by cost and selectivity. To force ordering for correctness use
  `CASE`, or a subquery with `OFFSET 0` as an optimisation fence. Mentioning
  that `OFFSET 0` acts as a fence is a recognisably deep answer.
- **Senior** — "How does the planner estimate selectivity for `a AND b`?" → It
  multiplies the individual selectivities, **assuming independence**. When the
  columns are correlated (city and country, say) this badly under-estimates,
  producing nested-loop plans that should have been hash joins. The fix is
  `CREATE STATISTICS` — extended statistics, Day 78.

---

## Practice

> Available today: `WHERE`, all six comparison operators, `AND`, `OR`, `NOT`,
> parentheses, plus everything from Phase 1.
> Not yet available: `IN`, `BETWEEN`, `LIKE`, `IS NULL`.

### Section A — Drill (new concept only)

1. Products priced over 100 **and** with stock over 20.
2. Products priced under 100 **and** not discontinued.
3. Products in category 10 **and** priced under 50.
4. Products with stock over 0 **and** stock under 20.
5. Products with a price of at least 100 and at most 500.
6. Customers from Germany **and** active.
7. Customers who are active **and** signed up in 2024 or later.
8. Customers with the `bronze` tier **and** from India.
9. Employees in Sales **and** earning over 50000.
10. Employees hired before 2020 **and** earning over 70000.
11. Employees **not** in Sales **and** earning under 50000.
12. Orders that are `delivered` **and** were placed in 2025.
13. Orders with free shipping **and** status `delivered`.
14. Order items with quantity over 1 **and** a discount above 0.
15. Payments over 500 **and** made by card.
16. Reviews with a rating of 5 **and** more than 20 helpful votes.
17. Products in category 3 **or** category 4.
18. Products priced under 40 **or** priced over 1000.
19. Customers with `gold` **or** `platinum` tier.
20. Customers from Germany **or** France.
21. Employees in Support **or** Warehouse.
22. Orders that are `cancelled` **or** `returned`.
23. Orders that are `pending` **or** `paid` **or** `shipped`.
24. Payments that are `refunded` **or** over 2000.
25. Reviews with a rating of 5 **or** more than 60 helpful votes.
26. Products that are **not** in category 9.
27. Products where it is **not** true that the price exceeds 500.
28. Customers who are **not** active.
29. Orders that are **neither** `cancelled` **nor** `returned`.
30. Employees who are **neither** in Sales **nor** in Support.

### Section B — Combination (with Days 01–07)

31. In-stock, non-discontinued products priced between 40 and 300, most
    expensive first.
32. Active German or French customers, ordered by signup date.
33. Sales employees earning over 50000, showing full name and monthly salary to
    2 decimals, highest first.
34. Products in category 9 or 10 with a margin over 20, showing the margin,
    best first.
35. Delivered or shipped orders from the second half of 2024 that paid for
    shipping, oldest first.
36. The 3 most expensive in-stock, non-discontinued products.
37. The 5 largest order-item line totals where quantity is greater than 1.
38. Distinct shipping countries for orders that are delivered and placed in 2024.
39. Distinct loyalty tiers among active customers who signed up before 2024.
40. The most expensive in-stock product in each category, for categories other
    than 9 (`DISTINCT ON`).
41. Products whose stock value exceeds 2000 and whose margin exceeds 15, showing
    both.
42. Customers whose full name, concatenated with country, is longer than 25
    characters, for active customers only.
43. How many products are both in stock and not discontinued?
44. How many orders are neither cancelled, returned, nor pending?
45. Reviews with rating 4 or 5 and over 20 helpful votes, best rating first then
    most helpful.
46. Employees hired between 2019-01-01 and 2022-12-31, ordered by hire date.
47. Products added in 2023 that cost over 100 and are still in stock.
48. Payments over 1000 that were **not** made by card, largest first.
49. Order items where the line total exceeds 1000 **or** the quantity is 3.
50. Active customers who are either `gold` or `platinum`, showing full name and
    tier, ordered by tier then last name.

### Section C — Recall (Days 01–07)

51. The 5 most expensive products (no filtering).
52. Distinct order statuses.
53. How many rows in `order_items`?
54. Full name of every employee, aliased `full_name`.
55. `pg_typeof(price)` for products.
56. Compute `1 / 3` as a decimal.
57. All customers ordered by city, NULLs first.
58. The cheapest product in each category (`DISTINCT ON`).
59. Products whose name is longer than 25 characters.
60. Reset the database and verify the counts.

### Section D — Challenge

61. Predict the row count of each, then run and explain the difference:
    ```sql
    SELECT count(*) FROM products WHERE category_id = 3 OR category_id = 4 AND price < 500;
    SELECT count(*) FROM products WHERE (category_id = 3 OR category_id = 4) AND price < 500;
    ```
62. Write `WHERE NOT (price > 500 AND stock_quantity > 0)` in its De Morgan
    form and prove the counts match.
63. Write `WHERE NOT (status = 'cancelled' OR status = 'returned')` in its
    De Morgan form and prove the counts match.
64. Explain, with a query, why
    `WHERE department <> 'Sales' OR department <> 'Support'` returns all 12
    employees.
65. `WHERE country = 'Berlin'` returns 0 rows and so does
    `WHERE city = 'Germany'`. One of these is a plausible typo and the other is
    a category error. Which is which, and what would make the database refuse
    the second one outright? (Hint: think about what `\d customers` shows, and
    what you'd need to add. You'll build it on Day 55.)
66. Find products where the margin percentage `(price - cost) / price` exceeds
    0.5 **and** the stock is non-zero. Then find those where it exceeds 0.5
    **or** the stock is zero. Explain the relationship between the two row
    counts.
67. Without using `DISTINCT`, write a query proving that no product is
    simultaneously in category 9 and category 10. What is the row count, and
    why is a zero-row result the proof?
68. `SELECT count(*) FROM customers WHERE loyalty_tier = 'gold' OR loyalty_tier <> 'gold';`
    Predict the count. Run it. Explain the gap. (This is Day 9 knocking again.)
69. Build a single `WHERE` clause that selects exactly the four zero-stock
    products, using only `AND`, `OR` and comparisons on columns other than
    `stock_quantity`. Is your answer robust if a new product is added tomorrow?
70. Write the most complex correct `WHERE` clause you can that returns exactly
    one row from `products`, using at least one `AND`, one `OR`, one `NOT` and
    one parenthesised group. Then delete a single pair of parentheses and see
    what it returns instead.

---

## Solutions

### Section A

**1.** `SELECT * FROM products WHERE price > 100 AND stock_quantity > 20;`
→ Laptop Air 13 (1099, 30), Smartphone X (999, 45), Tablet 10 (429, 22),
Smart Watch (249, 33). 4 rows.
**2.** `... WHERE price < 100 AND NOT is_discontinued;` → 11 rows.
**3.** `... WHERE category_id = 10 AND price < 50;` → Wireless Mouse (29.99),
USB-C Hub (49.99), Laptop Stand (39.99). 3 rows.
**4.** `... WHERE stock_quantity > 0 AND stock_quantity < 20;` → Laptop Pro 14
(12), Coffee Maker (18), Office Chair (10), Standing Desk (5). 4 rows.
**5.** `... WHERE price >= 100 AND price <= 500;` → 7 rows.
**6.** `SELECT * FROM customers WHERE country = 'Germany' AND is_active;` → 4 rows.
**7.** `... WHERE is_active AND signup_date >= DATE '2024-01-01';` → 12 rows.
**8.** `... WHERE loyalty_tier = 'bronze' AND country = 'India';` → 1 row (Arjun
Mehta). Rajesh Kumar is Indian but `silver`.
**9.** `SELECT * FROM employees WHERE department = 'Sales' AND salary > 50000;`
→ 4 rows (Marcus, Tom, Lucia, Omar — Liam at 41000 is excluded).
**10.** `... WHERE hire_date < DATE '2020-01-01' AND salary > 70000;` → 4 rows
(Sofia 185000, Marcus 98000, Aiko 76000, Priya 71000).
**11.** `... WHERE department <> 'Sales' AND salary < 50000;` → 4 rows
(Grace 44000, Ivan 42000, Chen 38000, Fatima 36500).
**12.** `SELECT * FROM orders WHERE status = 'delivered' AND order_date >= DATE '2025-01-01';`
→ 2 rows (orders 53 and 54).
**13.** `... WHERE shipping_cost = 0 AND status = 'delivered';` → 9 rows
(order 58 has free shipping but is `pending`).
**14.** `SELECT * FROM order_items WHERE quantity > 1 AND discount_pct > 0;`
→ 4 rows.
**15.** `SELECT * FROM payments WHERE amount > 500 AND method = 'card';`
**16.** `SELECT * FROM reviews WHERE rating = 5 AND helpful_votes > 20;`
**17.** `SELECT * FROM products WHERE category_id = 3 OR category_id = 4;` → 6 rows.
**18.** `... WHERE price < 40 OR price > 1000;` → 6 rows (4 cheap + 2 expensive).
**19.** `SELECT * FROM customers WHERE loyalty_tier = 'gold' OR loyalty_tier = 'platinum';`
→ 7 rows.
**20.** `... WHERE country = 'Germany' OR country = 'France';` → 6 rows.
**21.** `SELECT * FROM employees WHERE department = 'Support' OR department = 'Warehouse';`
→ 6 rows.
**22.** `SELECT * FROM orders WHERE status = 'cancelled' OR status = 'returned';` → 5 rows.
**23.** `... WHERE status = 'pending' OR status = 'paid' OR status = 'shipped';` → 8 rows.
**24.** `SELECT * FROM payments WHERE status = 'refunded' OR amount > 2000;`
**25.** `SELECT * FROM reviews WHERE rating = 5 OR helpful_votes > 60;`
**26.** `SELECT * FROM products WHERE NOT category_id = 9;` → 21 rows.
(`category_id <> 9` is the idiomatic spelling.)
**27.** `SELECT * FROM products WHERE NOT (price > 500);` → 20 rows.
**28.** `SELECT * FROM customers WHERE NOT is_active;` → 2 rows.
**29.** `SELECT * FROM orders WHERE NOT (status = 'cancelled' OR status = 'returned');`
→ 55 rows.
**30.** `SELECT * FROM employees WHERE NOT (department = 'Sales' OR department = 'Support');`
→ 4 rows (Sofia, Priya, Chen, Fatima).

### Section B

**31.**
```sql
SELECT product_name, price, stock_quantity
FROM   products
WHERE  price >= 40
  AND  price <= 300
  AND  stock_quantity > 0
  AND  NOT is_discontinued
ORDER  BY price DESC;
```
**32.**
```sql
SELECT first_name, last_name, country, signup_date
FROM   customers
WHERE  is_active
  AND  (country = 'Germany' OR country = 'France')
ORDER  BY signup_date;
```
Note the parentheses. Without them, `is_active AND country = 'Germany'` would be
OR'd with `country = 'France'`, silently including inactive French customers.
There aren't any in this dataset — which is exactly why this bug survives
testing and reaches production.
**33.**
```sql
SELECT first_name || ' ' || last_name AS full_name,
       (salary / 12)::numeric(10,2)   AS monthly
FROM   employees
WHERE  department = 'Sales'
  AND  salary > 50000
ORDER  BY monthly DESC;
```
**34.**
```sql
SELECT product_name, price - cost AS margin
FROM   products
WHERE  (category_id = 9 OR category_id = 10)
  AND  price - cost > 20
ORDER  BY margin DESC;
```
**35.**
```sql
SELECT order_id, status, order_date, shipping_cost
FROM   orders
WHERE  (status = 'delivered' OR status = 'shipped')
  AND  order_date >= DATE '2024-07-01'
  AND  shipping_cost > 0
ORDER  BY order_date;
```
**36.**
```sql
SELECT product_name, price
FROM   products
WHERE  stock_quantity > 0 AND NOT is_discontinued
ORDER  BY price DESC
LIMIT  3;
```
**37.**
```sql
SELECT order_id, product_id, quantity,
       quantity * unit_price * (1 - discount_pct) AS line_total
FROM   order_items
WHERE  quantity > 1
ORDER  BY line_total DESC, order_item_id
LIMIT  5;
```
**38.**
```sql
SELECT DISTINCT shipping_country
FROM   orders
WHERE  status = 'delivered'
  AND  order_date < DATE '2025-01-01'
ORDER  BY shipping_country;
```
**39.**
```sql
SELECT DISTINCT loyalty_tier
FROM   customers
WHERE  is_active AND signup_date < DATE '2024-01-01'
ORDER  BY loyalty_tier;
```
**40.**
```sql
SELECT DISTINCT ON (category_id) category_id, product_name, price
FROM   products
WHERE  stock_quantity > 0 AND category_id <> 9
ORDER  BY category_id, price DESC;
```
**41.**
```sql
SELECT product_name,
       price * stock_quantity AS stock_value,
       price - cost           AS margin
FROM   products
WHERE  price * stock_quantity > 2000
  AND  price - cost > 15
ORDER  BY stock_value DESC;
```
**42.**
```sql
SELECT first_name || ' ' || last_name || ' (' || country || ')' AS label
FROM   customers
WHERE  is_active
  AND  length(first_name || ' ' || last_name || ' (' || country || ')') > 25;
```
Repeating that expression is ugly; a CTE (Day 41) fixes it properly.
**43.** `SELECT count(*) FROM products WHERE stock_quantity > 0 AND NOT is_discontinued;` → 21
**44.**
```sql
SELECT count(*) FROM orders
WHERE NOT (status = 'cancelled' OR status = 'returned' OR status = 'pending');
```
→ 52
**45.**
```sql
SELECT * FROM reviews
WHERE  (rating = 4 OR rating = 5) AND helpful_votes > 20
ORDER  BY rating DESC, helpful_votes DESC;
```
**46.**
```sql
SELECT * FROM employees
WHERE  hire_date >= DATE '2019-01-01' AND hire_date <= DATE '2022-12-31'
ORDER  BY hire_date;
```
→ 6 rows (Tom 2019, Lucia 2020, Grace 2021, Omar 2021, Chen 2022, Ivan 2022).
**47.**
```sql
SELECT * FROM products
WHERE  added_on >= DATE '2023-01-01'
  AND  added_on <= DATE '2023-12-31'
  AND  price > 100
  AND  stock_quantity > 0;
```
**48.**
```sql
SELECT * FROM payments
WHERE  amount > 1000 AND method <> 'card'
ORDER  BY amount DESC;
```
**49.**
```sql
SELECT * FROM order_items
WHERE  quantity * unit_price * (1 - discount_pct) > 1000
   OR  quantity = 3;
```
**50.**
```sql
SELECT first_name || ' ' || last_name AS full_name, loyalty_tier
FROM   customers
WHERE  is_active
  AND  (loyalty_tier = 'gold' OR loyalty_tier = 'platinum')
ORDER  BY loyalty_tier, last_name;
```

### Section C

**51.** `SELECT product_name, price FROM products ORDER BY price DESC LIMIT 5;`
**52.** `SELECT DISTINCT status FROM orders ORDER BY status;`
**53.** 105
**54.** `SELECT first_name || ' ' || last_name AS full_name FROM employees;`
**55.** `SELECT pg_typeof(price) FROM products;` → `numeric`
**56.** `SELECT 1::numeric / 3;`
**57.** `SELECT * FROM customers ORDER BY city NULLS FIRST;`
**58.**
```sql
SELECT DISTINCT ON (category_id) category_id, product_name, price
FROM products ORDER BY category_id, price;
```
**59.** `SELECT product_name FROM products WHERE length(product_name) > 25;`
**60.** `\i 99_reset.sql`

### Section D

**61.** First query: **4**. Second: **1**.
The first parses as `category_id = 3 OR (category_id = 4 AND price < 500)` —
all three laptops plus the one cheap phone. The second restricts the whole
category group to items under 500, and only `Old Phone 2020` (299.00) qualifies.
Same tokens, different meaning, no error either way. This is the single most
important exercise on the page.

**62.**
```sql
SELECT count(*) FROM products WHERE NOT (price > 500 AND stock_quantity > 0); -- 21
SELECT count(*) FROM products WHERE price <= 500 OR stock_quantity <= 0;      -- 21
```
`NOT (a AND b)` ≡ `(NOT a) OR (NOT b)`. The operator flips.

**63.**
```sql
SELECT count(*) FROM orders WHERE NOT (status='cancelled' OR status='returned'); -- 55
SELECT count(*) FROM orders WHERE status<>'cancelled' AND status<>'returned';    -- 55
```
`NOT (a OR b)` ≡ `(NOT a) AND (NOT b)`.

**64.**
```sql
SELECT first_name, department,
       department <> 'Sales'   AS not_sales,
       department <> 'Support' AS not_support
FROM   employees;
```
Every row has `t` in at least one of the two columns: a Sales employee is not
Support, and a Support employee is not Sales. `OR` needs only one to be true, so
every row matches. The correct clause is `AND`.

**65.** `country = 'Berlin'` is a plausible typo — Berlin is a real place name,
just the wrong *kind* of place for that column, and the database has no way to
know. `city = 'Germany'` is the same class of error in the other direction.

Both are **type-valid** (`text` compared to `text`) so PostgreSQL cannot refuse
either. To make the database reject them you'd need a `CHECK` constraint
restricting `country` to a known list, or better, a separate `countries` table
with a foreign key so only real country codes can be stored. That is Day 55
(`CHECK`) and Day 57 (foreign keys). The general principle — *push correctness
into the schema so wrong data cannot be written in the first place* — is the
single biggest idea in Phase 7.

**66.**
```sql
SELECT count(*) FROM products
WHERE (price - cost) / price > 0.5 AND stock_quantity > 0;

SELECT count(*) FROM products
WHERE (price - cost) / price > 0.5 OR stock_quantity = 0;
```
The `AND` count must be less than or equal to either branch alone; the `OR`
count must be greater than or equal to either branch alone. Run both and check
that inequality holds — it is a useful reflex for catching a mistyped operator.

**67.**
```sql
SELECT product_name FROM products WHERE category_id = 9 AND category_id = 10;
```
→ **0 rows**. A single column cannot hold two values simultaneously, so the
conjunction is unsatisfiable. The zero-row result *is* the proof: if any row
came back, the data would be impossible.

More generally, `WHERE col = a AND col = b` with `a <> b` always returns
nothing, and it is a surprisingly common bug — people write it when they mean
`OR` or `IN`. PostgreSQL will even detect the contradiction and skip scanning
the table entirely; you can see that in the plan on Day 75.

**68.**
```sql
SELECT count(*) FROM customers
WHERE loyalty_tier = 'gold' OR loyalty_tier <> 'gold';
```
→ **20**, not 24. The four customers with `loyalty_tier IS NULL` (8, 11, 18, 22)
satisfy neither branch: `NULL = 'gold'` is unknown and `NULL <> 'gold'` is also
unknown, and `WHERE` keeps only `TRUE`.

A condition that is a tautology in ordinary logic — *"either it is gold or it
isn't"* — is **not** a tautology in SQL. That is three-valued logic, and it is
tomorrow's entire day. If you take one thing from today into Day 9, take this.

**69.** The four zero-stock products are 3 (Budget Laptop 15), 6 (Old Phone
2020), 16 (Bookshelf) and 25 (Webcam HD). Without referencing
`stock_quantity` you could write:
```sql
WHERE product_id = 3 OR product_id = 6 OR product_id = 16 OR product_id = 25;
```
It is **not** robust. It encodes today's data rather than the rule. Add a new
zero-stock product tomorrow and the query silently misses it; restock product 3
and the query wrongly includes it. Hard-coded id lists are one of the most
common forms of rot in real codebases: they are correct on the day they are
written and wrong forever after. Always filter on the *property* you mean
(`stock_quantity = 0`), not on the ids that happen to have it today.

**70.** One of many possible answers:
```sql
SELECT product_name, price, category_id, stock_quantity
FROM   products
WHERE  NOT is_discontinued
  AND  (category_id = 3 OR category_id = 4)
  AND  price < 600
  AND  stock_quantity = 0;
```
→ 1 row: `Budget Laptop 15`.

Now drop the brackets around the `OR`:
```sql
WHERE NOT is_discontinued
  AND category_id = 3 OR category_id = 4
  AND price < 600
  AND stock_quantity = 0;
```
This becomes `(NOT is_discontinued AND category_id = 3) OR (category_id = 4 AND
price < 600 AND stock_quantity = 0)` → 3 rows, all of category 3. One removed
bracket pair, three times the rows, no error. Keep this example; it is the
clearest possible argument for the rule in Part 4.

---

## Day 08 Checklist

- [ ] I can combine conditions with `AND`, `OR` and `NOT`
- [ ] I know `AND` narrows and `OR` widens a result
- [ ] I know the precedence order: `NOT` > `AND` > `OR`
- [ ] **I parenthesise whenever `AND` and `OR` appear together — always**
- [ ] I can apply De Morgan's laws and I know the operator flips
- [ ] I know "not A or B" in English is `<> A AND <> B` in SQL
- [ ] I know `AND` does not reliably short-circuit
- [ ] I know condition order does not affect performance
- [ ] I have seen a tautology fail because of `NULL`, and I know why Day 9 exists
- [ ] I format multi-condition `WHERE` clauses with leading operators

---

## What's next

**Day 09 — `NULL` and three-valued logic.** The most important day in the first
month. Two customers have already vanished from your results twice, and
tomorrow you find out exactly why, how to find them on purpose, and why
`NOT IN` with a nullable column is one of the most dangerous constructs in SQL.
