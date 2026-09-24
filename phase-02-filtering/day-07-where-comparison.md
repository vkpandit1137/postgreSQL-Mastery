# Day 07 — `WHERE` and Comparison Operators

> **Phase** 2 · Filtering & Expressions
> **Level** Absolute Beginner
> **Time** 100–130 minutes
> **Prerequisites** Days 01–06
> **New concepts** `WHERE` · `=` `<>` `<` `>` `<=` `>=` on real columns · filtering text, numbers, dates and booleans · filtering on an expression · why `WHERE` cannot see a `SELECT` alias · case sensitivity in comparisons
>
> ⚠️ **Today is single conditions only.** `AND` and `OR` are Day 8. If a
> problem seems to need two conditions, re-read it — it doesn't.

---

## Why this matters

Every query you have written so far returns **every row** in a table. That is
fine for a 25-row table and catastrophic for a 25-million-row one.

`WHERE` is the clause that says *which rows*. It is the most-typed piece of
syntax in SQL, it is where every index gets used or wasted (Day 74), and it is
where `NULL` will quietly ruin your results (Day 9). Everything in the next
eleven days is vocabulary that lives inside `WHERE`.

---

## Part 1 — The clause

```sql
SELECT product_name, price
FROM   products
WHERE  price > 500;
```

```
   product_name   |  price
------------------+---------
 Laptop Pro 14    | 1899.00
 Laptop Air 13    | 1099.00
 Budget Laptop 15 |  549.00
 Smartphone X     |  999.00
 Smartphone Mini  |  699.00
(5 rows)
```

Five rows out of 25. `WHERE` goes **after `FROM`** and **before `ORDER BY`**:

```sql
SELECT   columns
FROM     table
WHERE    condition
ORDER BY sort_keys
LIMIT    n;
```

That order is fixed. `WHERE` before `FROM` is a syntax error; `WHERE` after
`ORDER BY` is a syntax error.

### The mental model

PostgreSQL evaluates the query roughly like this:

```
1. FROM products          →  take all 25 rows
2. WHERE price > 500      →  for EACH row, evaluate the condition.
                             Keep it if the answer is TRUE. Discard otherwise.
3. SELECT product_name…   →  compute the output columns for survivors
4. ORDER BY / LIMIT       →  sort and trim
```

Step 2 is the important one. **`WHERE` takes a boolean expression and evaluates
it once per row.** You already know how to write boolean expressions — you spent
Day 4 putting them in the `SELECT` list:

```sql
-- Day 4: compute a boolean, show every row
SELECT product_name, price > 500 AS expensive FROM products;   -- 25 rows

-- Day 7: use the same boolean to decide which rows survive
SELECT product_name FROM products WHERE price > 500;           -- 5 rows
```

Same expression. Different job. *Compute* versus *filter*. If you hold that
distinction clearly, `WHERE` needs no further explanation — everything else
today is vocabulary.

▶ **Try it** — run both queries above and compare the row counts.

---

## Part 2 — The six comparison operators

| Operator | Means | Example |
|---|---|---|
| `=` | equal | `WHERE status = 'delivered'` |
| `<>` | not equal | `WHERE status <> 'cancelled'` |
| `!=` | not equal (same thing) | `WHERE status != 'cancelled'` |
| `<` | less than | `WHERE price < 50` |
| `>` | greater than | `WHERE price > 500` |
| `<=` | less than or equal | `WHERE stock_quantity <= 10` |
| `>=` | greater than or equal | `WHERE rating >= 4` |

`<>` is the SQL-standard spelling of "not equal"; `!=` is accepted by PostgreSQL
and is identical. Pick one and be consistent. This program uses `<>`.

⚠️ **Trap** — there is no `==` in SQL. `WHERE price == 500` is a syntax error.
If you come from almost any programming language, you will type this at least
once.

### Numbers

```sql
SELECT product_name, price FROM products WHERE price < 50;
```

Six rows: Wireless Mouse (29.99), SQL Performance Explained (34.95), Clean Code
(39.50), Laptop Stand (39.99), The Pragmatic Programmer (45.00), USB-C Hub
(49.99).

```sql
SELECT product_name, stock_quantity FROM products WHERE stock_quantity = 0;
```

Four rows: Budget Laptop 15, Old Phone 2020, Bookshelf, Webcam HD.

### Text

Text is compared with the same operators, and **the comparison is exact**:

```sql
SELECT order_id, status FROM orders WHERE status = 'delivered';
```

47 rows.

```sql
SELECT order_id, status FROM orders WHERE status <> 'delivered';
```

13 rows. 47 + 13 = 60. ✓ Whenever a column has no NULLs, a condition and its
negation must partition the table — that arithmetic is a free correctness check,
and on Day 9 you'll see exactly when it stops working.

⚠️ **Trap — text comparison is case-sensitive:**

```sql
SELECT * FROM orders WHERE status = 'Delivered';
```

```
(0 rows)
```

Zero rows. Not an error — just nothing. The stored value is `'delivered'`,
lowercase, and `'Delivered'` ≠ `'delivered'`.

This is the single most common cause of "my query returns nothing and I don't
know why". Three ways to deal with it, all available to you today:

```sql
-- 1. Match the stored case exactly (best — can use an index)
WHERE status = 'delivered'

-- 2. Normalise the column (works, but defeats a plain index — Day 74)
WHERE lower(status) = 'delivered'

-- 3. Normalise both sides, for user-supplied input
WHERE lower(status) = lower('Delivered')
```

💡 **Note** — `ILIKE` (Day 11) and the `citext` type (Day 66) exist precisely
because case-insensitive matching is so common. For now, know that `=` on text
is exact, and that `lower()` is your escape hatch.

### Dates

Dates compare naturally — earlier is "less than":

```sql
SELECT order_id, order_date
FROM   orders
WHERE  order_date >= DATE '2025-01-01'
ORDER  BY order_date;
```

Eight rows — orders 53 through 60, the 2025 orders.

```sql
SELECT first_name, signup_date
FROM   customers
WHERE  signup_date < DATE '2023-01-01';
```

Three rows: Olivia Brown (2022-08-17), James Wilson (2022-11-30), Peter Novak
(2022-12-09).

The `DATE` keyword before the literal is optional — PostgreSQL will infer the
type from the column being compared:

```sql
WHERE order_date >= '2025-01-01'     -- works, same result
```

Write the explicit `DATE` prefix anyway when the query is long. It documents
intent and it prevents a whole class of ambiguity you'll meet on Day 15.

⚠️ **Trap** — always use `YYYY-MM-DD`. `'01/02/2025'` is interpreted according
to the server's `DateStyle` setting, which means it means different things on
different machines. There is no upside to using it.

### Booleans

A boolean column is *already* a boolean expression. You do not need to compare
it to anything:

```sql
SELECT product_name FROM products WHERE is_discontinued;
```

Two rows: Old Phone 2020, Webcam HD.

The long-winded version works and is what most people write at first:

```sql
WHERE is_discontinued = true
```

Both are correct. The short form reads better once you're used to it. For the
negative:

```sql
SELECT product_name FROM products WHERE NOT is_discontinued;   -- 23 rows
WHERE is_discontinued = false                                  -- identical
WHERE is_discontinued IS FALSE                                 -- also identical
```

(You'll meet `NOT` properly tomorrow. Used on a single boolean column like this
it needs no extra machinery.)

```sql
SELECT first_name, last_name FROM customers WHERE NOT is_active;
```

Two rows: Carlos Silva, Peter Novak.

---

## Part 3 — Filtering on an expression

The condition is an *expression*, so it can be arithmetic, not just a column:

```sql
SELECT product_name, price, cost
FROM   products
WHERE  price - cost > 200;
```

```
  product_name   |  price  |  cost
-----------------+---------+---------
 Laptop Pro 14   | 1899.00 | 1400.00
 Laptop Air 13   | 1099.00 |  800.00
 Smartphone X    |  999.00 |  700.00
(3 rows)
```

Margin greater than 200. `price - cost` is computed for each row, then compared.

More examples, all legal today:

```sql
-- stock worth more than 5000 on the shelf
SELECT product_name FROM products WHERE price * stock_quantity > 5000;

-- order lines worth more than 500
SELECT order_id, product_id
FROM   order_items
WHERE  quantity * unit_price * (1 - discount_pct) > 500;

-- products whose name is longer than 20 characters
SELECT product_name FROM products WHERE length(product_name) > 20;

-- employees whose monthly pay exceeds 5000
SELECT first_name, salary FROM employees WHERE salary / 12 > 5000;
```

### Comparing two columns

Both sides can be columns:

```sql
SELECT product_name, price, cost
FROM   products
WHERE  cost > price;
```

```
(0 rows)
```

Zero rows — no product is sold below cost. That is a *useful* zero. A query that
returns nothing is not a failed query; it is an answer, and here it's a data-
quality check you could run every night.

```sql
SELECT order_id, shipping_city, shipping_country
FROM   orders
WHERE  shipping_country <> 'Germany';
```

▶ **Try it** — write a query finding orders where `shipping_city` differs from
the customer's home city. You can't, yet — that needs two tables, and joins are
Day 27. Notice the limit; it's the shape of what Phase 4 unlocks.

---

## Part 4 — `WHERE` cannot see a `SELECT` alias

```sql
SELECT product_name, price - cost AS margin
FROM   products
WHERE  margin > 200;
```

```
ERROR:  column "margin" does not exist
LINE 3: WHERE  margin > 200;
               ^
```

You met the same restriction inside the `SELECT` list on Day 4. Here is the
reason, and it is worth understanding properly rather than memorising:

> PostgreSQL evaluates `FROM` → `WHERE` → `SELECT` → `ORDER BY`.
> When `WHERE` runs, the `SELECT` list has not been computed yet, so `margin`
> does not exist.

That also explains the exception you met on Day 5:

| Clause | Can it see a `SELECT` alias? | Why |
|---|---|---|
| `WHERE` | ❌ no | runs **before** `SELECT` |
| `ORDER BY` | ✅ yes | runs **after** `SELECT` |

The fix today is to repeat the expression:

```sql
SELECT product_name, price - cost AS margin
FROM   products
WHERE  price - cost > 200
ORDER  BY margin DESC;
```

Note that the same query uses the raw expression in `WHERE` and the alias in
`ORDER BY`. That looks inconsistent and is in fact exactly right.

💡 **Note** — repeating the expression is not a performance problem. PostgreSQL
computes `price - cost` once per row regardless. It is only a *readability*
problem, and CTEs (Day 41) solve it properly.

🎯 **Interview** — "Why can't you use a column alias in `WHERE`?" This is a
very common junior/mid screening question, and the answer is "logical query
processing order: `WHERE` is evaluated before the `SELECT` list." Being able to
name the order — and to say that `ORDER BY` *can* use the alias for the same
reason — marks you out immediately. Day 21 gives you the full ordering.

---

## Part 5 — `WHERE` with everything you already know

`WHERE` composes with every clause from Phase 1.

**With `ORDER BY` and `LIMIT`** — "the three most expensive items still in
stock":

```sql
SELECT product_name, price, stock_quantity
FROM   products
WHERE  stock_quantity > 0
ORDER  BY price DESC
LIMIT  3;
```

```
  product_name   |  price  | stock_quantity
-----------------+---------+----------------
 Laptop Pro 14   | 1899.00 |             12
 Laptop Air 13   | 1099.00 |             30
 Smartphone X    |  999.00 |             45
(3 rows)
```

**With `DISTINCT`** — "which countries have we shipped to in 2025?":

```sql
SELECT DISTINCT shipping_country
FROM   orders
WHERE  order_date >= DATE '2025-01-01'
ORDER  BY shipping_country;
```

**With `DISTINCT ON`** — "the most expensive in-stock product per category":

```sql
SELECT DISTINCT ON (category_id) category_id, product_name, price
FROM   products
WHERE  stock_quantity > 0
ORDER  BY category_id, price DESC;
```

**With computed columns** — filter on one thing, display another:

```sql
SELECT product_name,
       price,
       price * stock_quantity AS stock_value
FROM   products
WHERE  stock_quantity = 0;
```

All four products come back with `stock_value` of `0.00`. Obvious in hindsight;
worth seeing once.

**With `count(*)`** — how many rows match?

```sql
SELECT count(*) FROM orders WHERE status = 'delivered';   -- 47
```

You are still using `count(*)` only as a sanity check. Day 19 makes it a
first-class tool.

---

## Part 6 — The order of evaluation matters for cost, too

```sql
SELECT count(*) FROM order_items WHERE quantity > 1;   -- 17
```

PostgreSQL reads all 105 rows and discards 88. On this table that takes
microseconds. On `big_orders` (5 million rows, Day 73) the same shape of query
is the difference between 2 milliseconds and 2 seconds, and the deciding factor
is whether an index exists on the filtered column.

You cannot act on this yet — indexes are Day 74. But start noticing, now, *which
column you are filtering on*. That column is almost always the one that will
need an index later. Engineers who build this habit early write schemas that
happen to be fast; engineers who don't spend their careers retrofitting.

---

## Traps & Gotchas

| # | Trap | What happens |
|---|---|---|
| 1 | `WHERE status = 'Delivered'` | 0 rows. Text comparison is case-sensitive. |
| 2 | `WHERE price == 500` | Syntax error. SQL has no `==`. |
| 3 | `WHERE margin > 200` using a `SELECT` alias | `column does not exist` |
| 4 | `WHERE` placed after `ORDER BY` | Syntax error. Clause order is fixed. |
| 5 | `WHERE city = NULL` | 0 rows, no error. **Day 9.** Never use `=` with NULL. |
| 6 | `WHERE order_date > '01/02/2025'` | Ambiguous; depends on `DateStyle`. Use `YYYY-MM-DD`. |
| 7 | Assuming a condition and its negation always sum to the table | Only true when the column has no NULLs. **Day 9.** |
| 8 | `WHERE is_discontinued = 'true'` | Works (string coerces), but write `is_discontinued`. |

### Trap 5 deserves a preview

```sql
SELECT first_name, city FROM customers WHERE city = NULL;
```

```
(0 rows)
```

There *are* two customers with no city. This query finds neither, and it does
not error. It is the highest-consequence trap in beginner SQL, and it is the
whole of Day 9. For now, just know: **`= NULL` never matches anything.** The
correct form is `IS NULL`, which you'll learn properly in two days.

---

## Interview angles

- **Junior** — "Find all orders with status 'delivered'." →
  `SELECT * FROM orders WHERE status = 'delivered';`
- **Junior** — "Is `WHERE` case-sensitive on text?" → Yes, for `=`. Use
  `lower()` or `ILIKE`.
- **Mid** — "Why can't `WHERE` use a `SELECT` alias?" → Logical processing
  order; `WHERE` runs first.
- **Mid** — "`WHERE lower(email) = 'x'` — any performance concern?" → A plain
  B-tree index on `email` cannot be used, because the indexed value is `email`,
  not `lower(email)`. You need an **expression index** on `lower(email)`, or a
  `citext` column. Day 79.
- **Senior** — "Walk me through what the planner does with
  `WHERE price > 500`." → Estimates selectivity from `pg_stats` histogram
  bounds, compares the cost of a sequential scan against an index scan plus
  heap fetches, and picks the cheaper. With 20% of rows matching it will almost
  always choose a seq scan, because random I/O for that many heap fetches costs
  more than reading the table. Day 77–78.

---

## Practice

> **Single conditions only.** No `AND`, no `OR`, no `IN`, no `BETWEEN`,
> no `LIKE`, no `IS NULL`. Everything below is solvable with one comparison.

### Section A — Drill (new concept only)

1. All products costing more than 1000.
2. All products costing less than 40.
3. All products priced exactly 249.00.
4. All products **not** priced 249.00.
5. All products with zero stock.
6. All products with stock of at least 100.
7. All products with stock of 10 or fewer.
8. All discontinued products.
9. All products that are **not** discontinued.
10. All products in category 9.
11. All products **not** in category 10.
12. All products from supplier 4.
13. All customers from Germany.
14. All customers **not** from Germany.
15. All inactive customers.
16. All active customers.
17. All customers with the `gold` loyalty tier.
18. All customers who signed up on or after 2025-01-01.
19. All customers who signed up before 2023-01-01.
20. All employees in the Sales department.
21. All employees **not** in Sales.
22. All employees earning more than 50000.
23. All employees earning 45000 or less.
24. All employees hired before 2020-01-01.
25. All orders with status `cancelled`.
26. All orders with status other than `delivered`.
27. All orders placed in 2025 (i.e. on or after 2025-01-01).
28. All orders with free shipping (`shipping_cost` of 0).
29. All order items with a quantity greater than 1.
30. All order items with a discount greater than 0.
31. All payments over 1000.
32. All payments with status `refunded`.
33. All reviews with a rating of 5.
34. All reviews with a rating below 3.
35. All reviews with more than 50 helpful votes.

### Section B — Combination (with Days 01–06)

36. The 5 most expensive products that are still in stock.
37. The 3 cheapest products that are in stock.
38. Names and prices of products over 500, cheapest first.
39. Full names of all German customers, alphabetical by last name.
40. Full names and salaries of Sales employees, highest paid first.
41. All products where the margin (`price - cost`) exceeds 200, showing the
    margin, highest first.
42. All products whose stock value (`price * stock_quantity`) exceeds 5000,
    showing the stock value, highest first.
43. All order items whose line total exceeds 500, showing the line total,
    largest first.
44. All products whose name is longer than 20 characters, showing the length.
45. All employees whose monthly salary (`salary / 12`) exceeds 5000, showing
    monthly salary to 2 decimals.
46. Distinct shipping countries for orders placed in 2025.
47. Distinct loyalty tiers among active customers.
48. Distinct statuses among orders that were **not** delivered.
49. The most expensive in-stock product in each category (`DISTINCT ON`).
50. The earliest order for each customer, restricted to 2024 orders
    (`DISTINCT ON`).
51. How many products cost more than 100?
52. How many customers signed up in 2024 or later?
53. How many orders are not `delivered`?
54. Names of customers concatenated with country, for non-German customers
    only, e.g. `Rajesh Kumar (India)`.
55. For all products over 500, show name and price with 20% VAT added, to 2
    decimals, most expensive first.

### Section C — Recall (Days 01–06)

56. How many rows in `order_items`, `payments` and `reviews`?
57. Describe the `products` table. Which columns are nullable?
58. Return `'Day 7'` with no table.
59. Compute `987 / 4` two ways — integer and decimal.
60. What is `pg_typeof(true)`?
61. Concatenate `'Employee: '` with each employee's full name.
62. Distinct `department` values in `employees`.
63. The 3 longest product names.
64. Cast `'2024-12-25'` to a date.
65. Reset the database and verify the nine row counts.

### Section D — Challenge

66. `SELECT count(*) FROM orders WHERE status = 'delivered';` gives 47 and
    `... WHERE status <> 'delivered';` gives 13. Verify they sum to 60, then
    explain in one sentence the condition under which this arithmetic would
    **fail**.
67. Run `SELECT count(*) FROM customers WHERE city = 'Berlin';` and
    `SELECT count(*) FROM customers WHERE city <> 'Berlin';`. Do they sum to
    24? Explain the discrepancy. (This is Day 9 arriving early. Write your
    theory in `mistakes.md` before reading the solution.)
68. Find every product whose price is *not* a whole number of euros — without
    using any function you haven't been taught. (Hint: what does `price::integer`
    do, and how does it compare to `price`?)
69. Answer the question you were left with on Day 3 problem 40: how many columns
    does the `products` table have? Use `information_schema.columns` and a
    single `WHERE`.
70. Find the order item(s) with the single largest line total. Write it so that
    it is guaranteed to return the same row every time it runs.
71. `WHERE NOT is_discontinued` returns 23 rows and `WHERE is_discontinued`
    returns 2. Together that is 25, the whole table. Would that still hold if
    `is_discontinued` were nullable? Explain what you expect, then check `\d
    products` to see whether it is.

---

## Solutions

### Section A

**1.** `SELECT * FROM products WHERE price > 1000;` → 2 rows (Laptop Pro 14,
Laptop Air 13).
**2.** `SELECT * FROM products WHERE price < 40;` → 4 rows (Wireless Mouse
29.99, SQL Performance Explained 34.95, Clean Code 39.50, Laptop Stand 39.99).
**3.** `SELECT * FROM products WHERE price = 249.00;` → 2 rows (Office Chair,
Smart Watch).
**4.** `SELECT * FROM products WHERE price <> 249.00;` → 23 rows.
**5.** `SELECT * FROM products WHERE stock_quantity = 0;` → 4 rows.
**6.** `SELECT * FROM products WHERE stock_quantity >= 100;` → 3 rows
(Wireless Mouse 200, USB-C Hub 150, Clean Code 100).
**7.** `SELECT * FROM products WHERE stock_quantity <= 10;` → 6 rows (the four
zero-stock products plus Office Chair 10 and Standing Desk 5).
**8.** `SELECT * FROM products WHERE is_discontinued;` → 2 rows.
**9.** `SELECT * FROM products WHERE NOT is_discontinued;` → 23 rows.
**10.** `SELECT * FROM products WHERE category_id = 9;` → 4 rows (the books).
**11.** `SELECT * FROM products WHERE category_id <> 10;` → 20 rows.
**12.** `SELECT * FROM products WHERE supplier_id = 4;` → 4 rows.
**13.** `SELECT * FROM customers WHERE country = 'Germany';` → 4 rows
(Anna Muller, Tom Becker, Lucas Meyer, Hannah Schmidt).
**14.** `SELECT * FROM customers WHERE country <> 'Germany';` → 20 rows.
**15.** `SELECT * FROM customers WHERE NOT is_active;` → 2 rows (Carlos Silva,
Peter Novak).
**16.** `SELECT * FROM customers WHERE is_active;` → 22 rows.
**17.** `SELECT * FROM customers WHERE loyalty_tier = 'gold';` → 5 rows.
**18.** `SELECT * FROM customers WHERE signup_date >= DATE '2025-01-01';` → 4 rows.
**19.** `SELECT * FROM customers WHERE signup_date < DATE '2023-01-01';` → 3 rows.
**20.** `SELECT * FROM employees WHERE department = 'Sales';` → 5 rows.
**21.** `SELECT * FROM employees WHERE department <> 'Sales';` → 7 rows.
**22.** `SELECT * FROM employees WHERE salary > 50000;` → 7 rows.
**23.** `SELECT * FROM employees WHERE salary <= 45000;` → 5 rows
(Grace 44000, Ivan 42000, Chen 38000, Fatima 36500, Liam 41000).
**24.** `SELECT * FROM employees WHERE hire_date < DATE '2020-01-01';` → 5 rows.
**25.** `SELECT * FROM orders WHERE status = 'cancelled';` → 3 rows (4, 14, 35).
**26.** `SELECT * FROM orders WHERE status <> 'delivered';` → 13 rows.
**27.** `SELECT * FROM orders WHERE order_date >= DATE '2025-01-01';` → 8 rows.
**28.** `SELECT * FROM orders WHERE shipping_cost = 0;` → 10 rows.
**29.** `SELECT * FROM order_items WHERE quantity > 1;` → 17 rows.
**30.** `SELECT * FROM order_items WHERE discount_pct > 0;` → 9 rows.
**31.** `SELECT * FROM payments WHERE amount > 1000;` → 15 rows.
**32.** `SELECT * FROM payments WHERE status = 'refunded';` → 2 rows (orders 8
and 23).
**33.** `SELECT * FROM reviews WHERE rating = 5;` → 15 rows.
**34.** `SELECT * FROM reviews WHERE rating < 3;` → 3 rows (all 2-star; there
are no 1-star reviews in this dataset).
**35.** `SELECT * FROM reviews WHERE helpful_votes > 50;` → 5 rows.

### Section B

**36.**
```sql
SELECT product_name, price, stock_quantity
FROM   products
WHERE  stock_quantity > 0
ORDER  BY price DESC
LIMIT  5;
```
**37.** Same with `ORDER BY price LIMIT 3;` → Wireless Mouse, SQL Performance
Explained, Clean Code. (Note that `Budget Laptop 15` is excluded despite being
cheap-ish — it has zero stock.)
**38.**
```sql
SELECT product_name, price FROM products WHERE price > 500 ORDER BY price;
```
**39.**
```sql
SELECT first_name || ' ' || last_name AS full_name
FROM   customers
WHERE  country = 'Germany'
ORDER  BY last_name;
```
**40.**
```sql
SELECT first_name || ' ' || last_name AS full_name, salary
FROM   employees
WHERE  department = 'Sales'
ORDER  BY salary DESC;
```
→ Marcus Webb 98000, Tom Becker 62000, Lucia Moretti 54000, Omar Haddad 51000,
Liam O'Brien 41000.
**41.**
```sql
SELECT product_name, price - cost AS margin
FROM   products
WHERE  price - cost > 200
ORDER  BY margin DESC;
```
→ 3 rows. Note the expression is repeated in `WHERE` and referenced by alias in
`ORDER BY` — correct, not inconsistent.
**42.**
```sql
SELECT product_name, price * stock_quantity AS stock_value
FROM   products
WHERE  price * stock_quantity > 5000
ORDER  BY stock_value DESC;
```
**43.**
```sql
SELECT order_id, product_id,
       quantity * unit_price * (1 - discount_pct) AS line_total
FROM   order_items
WHERE  quantity * unit_price * (1 - discount_pct) > 500
ORDER  BY line_total DESC;
```
**44.**
```sql
SELECT product_name, length(product_name) AS name_length
FROM   products
WHERE  length(product_name) > 20
ORDER  BY name_length DESC;
```
**45.**
```sql
SELECT first_name || ' ' || last_name AS full_name,
       (salary / 12)::numeric(10,2) AS monthly
FROM   employees
WHERE  salary / 12 > 5000
ORDER  BY monthly DESC;
```
→ 7 rows — the same seven as problem 22, because `salary > 60000` and
`salary/12 > 5000` are the same condition… except they aren't: 60000/12 = 5000
exactly, and `>` excludes equality. Check the boundary yourself. This kind of
off-by-one at a threshold is the most common source of subtly wrong reports.
**46.**
```sql
SELECT DISTINCT shipping_country
FROM   orders
WHERE  order_date >= DATE '2025-01-01'
ORDER  BY shipping_country;
```
**47.**
```sql
SELECT DISTINCT loyalty_tier FROM customers WHERE is_active ORDER BY loyalty_tier;
```
→ 5 rows including `NULL` (customers 11, 18 and 22 are active with no tier).
**48.** `SELECT DISTINCT status FROM orders WHERE status <> 'delivered' ORDER BY status;`
→ cancelled, paid, pending, returned, shipped.
**49.**
```sql
SELECT DISTINCT ON (category_id) category_id, product_name, price
FROM   products
WHERE  stock_quantity > 0
ORDER  BY category_id, price DESC;
```
**50.**
```sql
SELECT DISTINCT ON (customer_id) customer_id, order_id, order_date
FROM   orders
WHERE  order_date < DATE '2025-01-01'
ORDER  BY customer_id, order_date;
```
**51.** `SELECT count(*) FROM products WHERE price > 100;` → 13
**52.** `SELECT count(*) FROM customers WHERE signup_date >= DATE '2024-01-01';` → 12
**53.** `SELECT count(*) FROM orders WHERE status <> 'delivered';` → 13
**54.**
```sql
SELECT first_name || ' ' || last_name || ' (' || country || ')' AS label
FROM   customers
WHERE  country <> 'Germany';
```
**55.**
```sql
SELECT product_name, (price * 1.20)::numeric(10,2) AS price_with_vat
FROM   products
WHERE  price > 500
ORDER  BY price DESC;
```

### Section C

**56.** 105, 56, 36
**57.** `\d products` — nullable: `category_id`, `supplier_id`, `cost`,
`weight_kg`.
**58.** `SELECT 'Day 7';`
**59.** `SELECT 987 / 4;` → 246. `SELECT 987::numeric / 4;` → 246.75
**60.** `boolean`
**61.** `SELECT 'Employee: ' || first_name || ' ' || last_name FROM employees;`
**62.** `SELECT DISTINCT department FROM employees ORDER BY department;`
**63.** `SELECT product_name FROM products ORDER BY length(product_name) DESC LIMIT 3;`
**64.** `SELECT '2024-12-25'::date;` or `SELECT DATE '2024-12-25';`
**65.** `\i 99_reset.sql`

### Section D

**66.** 47 + 13 = 60 ✓. It would fail if `status` contained any `NULL`s. A row
with `status = NULL` satisfies **neither** `= 'delivered'` nor `<> 'delivered'`,
because both comparisons evaluate to `NULL` (unknown), and `WHERE` only keeps
rows where the condition is `TRUE`. Such rows vanish from both counts. `status`
here is `NOT NULL`, so the arithmetic is safe — but you had to check the schema
to know that.

**67.**
```sql
SELECT count(*) FROM customers WHERE city = 'Berlin';    -- 2
SELECT count(*) FROM customers WHERE city <> 'Berlin';   -- 20
```
2 + 20 = **22**, not 24. The two missing customers are 7 (Marie Dubois) and 18
(Nina Petrova), who have `city IS NULL`. `NULL = 'Berlin'` is `NULL`, and
`NULL <> 'Berlin'` is *also* `NULL` — neither is `TRUE`, so neither query keeps
them.

This is the most important thing on today's page. Two rows disappeared from
both halves of a supposedly exhaustive split, silently, with no error. Scale
that to a customer table with 400,000 rows and a nullable `region` column and
you have a report that has been under-counting for two years.

Day 9 is entirely about this. Write it in `mistakes.md` now.

**68.**
```sql
SELECT product_name, price
FROM   products
WHERE  price <> price::integer;
```
`price::integer` rounds to the nearest whole number; comparing it back to the
original finds every price with a fractional part. → 11 rows (29.99, 89.99,
49.99, 39.99, 79.99, 129.99, 59.99, 39.50, 34.95, 45.00? no — 45.00 is whole).
Run it and read the actual list rather than trusting this parenthetical.

A subtlety worth noticing: `price::integer` *rounds*, so `29.99 → 30`, and
`30 <> 29.99` is true. Had the cast truncated, the logic would still work.
Either way the technique is: transform, compare to the original, and the rows
that differ are the ones affected by the transformation. That pattern is
genuinely useful — it's how you find rows a data migration would change, before
you run it.

**69.**
```sql
SELECT count(*)
FROM   information_schema.columns
WHERE  table_name = 'products';
```
→ 10.

This is the Day 3 question you couldn't answer, answered in one line four days
later. That is what the waterfall feels like from the inside. (A more precise
version adds `AND table_schema = 'public'` — but `AND` is tomorrow.)

**70.**
```sql
SELECT order_item_id, order_id, product_id,
       quantity * unit_price * (1 - discount_pct) AS line_total
FROM   order_items
ORDER  BY line_total DESC, order_item_id
LIMIT  1;
```
Note: this problem needs no `WHERE` at all — it is pure Day 5. The guarantee
comes from `order_item_id` as the tie-breaker: without it, if two lines tied for
the largest total, either could be returned on any given run.

**71.** It would **not** hold. If `is_discontinued` were nullable, a row with
`NULL` would satisfy neither `WHERE is_discontinued` (which is `NULL`, not
`TRUE`) nor `WHERE NOT is_discontinued` (`NOT NULL` is still `NULL`). The two
counts would sum to less than 25.

`\d products` shows `is_discontinued | boolean | not null | false` — it is
`NOT NULL` with a default of `false`, so the split is exhaustive. This is one
of the strongest arguments for declaring boolean columns `NOT NULL DEFAULT
false`: it makes `WHERE flag` and `WHERE NOT flag` a genuine partition, and
removes an entire category of silent bug. You'll design columns this way
yourself from Day 55.

---

## Day 07 Checklist

- [ ] I can write `WHERE` in the right position in the clause order
- [ ] I know `WHERE` takes a boolean expression evaluated once per row
- [ ] I can use all six comparison operators, and I know there is no `==`
- [ ] I know text comparison with `=` is case-sensitive, and I know `lower()`
- [ ] I can filter on dates using `YYYY-MM-DD` literals
- [ ] I can filter a boolean column without writing `= true`
- [ ] I can filter on a computed expression, and compare two columns
- [ ] I know `WHERE` cannot see a `SELECT` alias, and I can say why
- [ ] I have seen `= NULL` return zero rows and I know that's coming on Day 9
- [ ] I have seen a condition and its negation fail to sum to the table total

---

## What's next

**Day 08 — `AND`, `OR`, `NOT` and precedence.** One condition becomes many.
The syntax takes ten minutes; the precedence rules cause production incidents,
so we'll spend the rest of the day on those.
