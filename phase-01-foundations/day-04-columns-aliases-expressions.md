# Day 04 — Choosing Columns, Aliases & Computed Columns

> **Phase** 1 · Foundations
> **Level** Absolute Beginner
> **Time** 100–130 minutes
> **Prerequisites** Days 01–03
> **New concepts** Explicit column lists · `AS` aliases · quoted aliases · expressions over columns · `||` on columns · computed/derived columns · comments · multi-line formatting

---

## Why this matters

`SELECT *` is how you *explore* a table. Choosing columns is how you *use* one.

More importantly, today is where SQL stops being "fetch what's stored" and
becomes "compute what I need." The `SELECT` list is not a list of columns — it
is a list of **expressions**, and a column name is merely the simplest kind of
expression. Once that clicks, most of SQL opens up.

---

## Part 1 — Naming the columns you want

```sql
SELECT supplier_name, country FROM suppliers;
```

```
    supplier_name    | country
---------------------+---------
 TechSource Global   | Germany
 Pacific Components  | Taiwan
 Nordic Home Goods   | Sweden
 Delhi Print House   | India
 Atlas Furniture Co  | Poland
 Quantum Peripherals | China
(6 rows)
```

Two things changed from `SELECT *`:

- **Fewer columns.** Only what you asked for.
- **Your order, not the table's.** The `SELECT` list controls output order:

```sql
SELECT country, supplier_name FROM suppliers;
```

Same data, columns swapped. The table's own column order is irrelevant.

You may also repeat a column, which seems pointless until Day 17:

```sql
SELECT supplier_name, supplier_name FROM suppliers;
```

Two identical columns, both named `supplier_name`. Legal. Result-set column
names need not be unique.

### Why professionals avoid `SELECT *`

| Reason | What goes wrong |
|---|---|
| Schema changes | Someone adds a column; your code receives an unexpected field and breaks |
| Bandwidth | You ship a 4 KB `description` column you never read, for every row |
| Index-only scans | `SELECT *` almost always forces a heap fetch (Day 74) |
| Readability | The reader cannot tell what the query actually uses |
| Column order | A column reorder silently changes positional access |

Use `*` interactively. Never in code that ships.

---

## Part 2 — Aliases with `AS`

Rename an output column:

```sql
SELECT supplier_name AS name, country AS location FROM suppliers;
```

```
        name         | location
---------------------+----------
 TechSource Global   | Germany
 ...
```

The table is unchanged. An alias renames the column **in this result only**.

`AS` is optional:

```sql
SELECT supplier_name name, country location FROM suppliers;
```

Identical result. But **write `AS`**. Without it, one missing comma turns into a
silent bug:

```sql
SELECT supplier_name country FROM suppliers;
```

You meant two columns and forgot the comma. PostgreSQL sees one column,
`supplier_name`, aliased to `country`, and returns supplier names under the
heading `country`. No error. Wrong data, plausibly labelled. This is a genuinely
nasty class of bug and `AS` prevents it.

### Aliases with spaces or capitals

Unquoted aliases are folded to lowercase, like all identifiers:

```sql
SELECT supplier_name AS SupplierName FROM suppliers;
```

```
    suppliername
---------------------
 TechSource Global
```

To preserve case or use spaces, quote with **double** quotes:

```sql
SELECT supplier_name AS "Supplier Name",
       country       AS "Country of Origin"
FROM   suppliers;
```

```
    Supplier Name    | Country of Origin
---------------------+-------------------
 TechSource Global   | Germany
```

⚠️ **Trap** — double quotes, not single. `AS 'Supplier Name'` is an error in
PostgreSQL. Single quotes are data; double quotes are names. Same rule as Day 2.

💡 **Note** — quoted, human-readable aliases are for the final report only. For
anything a program consumes, use plain `snake_case` so callers never need to
quote.

---

## Part 3 — Formatting a query

From now on, queries get long. Adopt this layout today:

```sql
SELECT product_name,
       price,
       stock_quantity
FROM   products;
```

Rules that will serve you for a career:

1. Keywords UPPERCASE, identifiers lowercase.
2. One clause per line (`SELECT`, `FROM`, later `WHERE`, `GROUP BY` …).
3. One expression per line in the `SELECT` list, once there are more than two.
4. Indent continuation lines.
5. Always end with `;`.

### Comments

```sql
-- A single-line comment: everything after -- is ignored.

/* A block comment.
   Spans several lines. */

SELECT product_name,   -- the customer-facing name
       price           -- what we charge, not what it costs us
FROM   products;
```

▶ **Try it** — write the query above across four lines with a comment on each.
Multi-line input in `psql` works exactly as you'd hope: keep typing, press Enter
freely, and it runs when you type `;`.

---

## Part 4 — Expressions over columns

Here is today's real idea.

```sql
SELECT product_name,
       price,
       price * 2
FROM   products;
```

```
             product_name             |  price  | ?column?
--------------------------------------+---------+----------
 Laptop Pro 14                        | 1899.00 | 3798.00
 Laptop Air 13                        | 1099.00 | 2198.00
 Budget Laptop 15                     |  549.00 | 1098.00
 ...
(25 rows)
```

`price * 2` is not a column in `products`. It never was and never will be. It is
computed, per row, at query time. This is a **derived column** (or *computed
column*, or *calculated field* — same thing).

Give it a name:

```sql
SELECT product_name,
       price,
       price * 2 AS double_price
FROM   products;
```

### The pattern to internalise

> Every item in the `SELECT` list is an expression evaluated **once per row**.
> A bare column name is just the simplest possible expression.

Once you see the `SELECT` list as a list of per-row calculations, everything
from Day 13's string functions to Day 46's window functions is a variation on
one idea.

### Realistic derived columns

**Profit margin per unit:**

```sql
SELECT product_name,
       price,
       cost,
       price - cost AS margin
FROM   products;
```

For `Laptop Pro 14`: 1899.00 − 1400.00 = **499.00**.

**Stock value — what the shelf is worth:**

```sql
SELECT product_name,
       stock_quantity,
       price,
       price * stock_quantity AS stock_value
FROM   products;
```

For `Wireless Mouse`: 29.99 × 200 = **5998.00**.

**The line total** — the single most important expression in this database:

```sql
SELECT order_id,
       product_id,
       quantity,
       unit_price,
       discount_pct,
       quantity * unit_price * (1 - discount_pct) AS line_total
FROM   order_items;
```

```
 order_id | product_id | quantity | unit_price | discount_pct | line_total
----------+------------+----------+------------+--------------+------------
        1 |          7 |        2 |      29.99 |        0.000 |  59.98000
        1 |          8 |        1 |      89.99 |        0.000 |  89.99000
        2 |          1 |        1 |    1899.00 |        0.050 |1804.05000
        2 |          9 |        1 |      49.99 |        0.000 |  49.99000
 ...
(105 rows)
```

Learn this formula now: **`quantity * unit_price * (1 - discount_pct)`**. You
will write it on at least forty of the remaining days.

⚠️ **Trap** — those trailing zeros (`59.98000`) are not a bug. `numeric`
multiplication adds the scales of its operands: `numeric(10,2) × numeric(4,3)`
gives five decimal places. You'll round it properly on Day 14.

### Text expressions on columns

```sql
SELECT first_name || ' ' || last_name AS full_name,
       country
FROM   customers;
```

```
     full_name      |   country
--------------------+-------------
 Anna Muller        | Germany
 Rajesh Kumar       | India
 Emily Carter       | USA
 ...
(24 rows)
```

And with a literal mixed in:

```sql
SELECT 'Customer: ' || first_name || ' ' || last_name || ' (' || country || ')'
         AS description
FROM   customers;
```

```
              description
----------------------------------------
 Customer: Anna Muller (Germany)
 Customer: Rajesh Kumar (India)
 ...
```

⚠️ **Trap — the NULL poisoning, now with real consequences:**

```sql
SELECT first_name || ' lives in ' || city AS location
FROM   customers;
```

24 rows, but **two are blank** — Marie Dubois and Nina Petrova have no `city`,
so the entire concatenation collapses to `NULL`. Not "Marie lives in ", but
nothing at all.

This is precisely how a customer disappears from a mailing list. Day 9 explains
the logic; Day 17 gives you `COALESCE` to fix it. For today, just see it happen
with your own eyes.

▶ **Try it** — run that query and count the blank rows.

### Boolean expressions as columns

Comparisons return booleans, and booleans are values, so they can be columns:

```sql
SELECT product_name,
       price,
       price > 500 AS is_expensive,
       stock_quantity = 0 AS is_out_of_stock
FROM   products;
```

```
             product_name             |  price  | is_expensive | is_out_of_stock
--------------------------------------+---------+--------------+-----------------
 Laptop Pro 14                        | 1899.00 | t            | f
 Budget Laptop 15                     |  549.00 | t            | t
 Wireless Mouse                       |   29.99 | f            | f
 ...
```

Notice: this does not **filter**. Every one of the 25 products is still
returned; you have simply added a true/false column. Filtering is `WHERE`, and
that is Day 7. Seeing the difference clearly now — *compute* versus *filter* —
makes Day 7 trivial.

### Mixing types

```sql
SELECT product_name || ' costs ' || price AS blurb
FROM   products;
```

Works: `||` accepts a non-text operand when the other side is text. Explicit is
still better in long queries:

```sql
SELECT product_name || ' costs ' || price::text AS blurb
FROM   products;
```

---

## Part 5 — Column names in expressions

One rule that surprises beginners:

```sql
SELECT price * 2 AS double_price,
       double_price + 10 AS more
FROM   products;
```

```
ERROR:  column "double_price" does not exist
```

**You cannot reuse an alias elsewhere in the same `SELECT` list.** All the
expressions in a `SELECT` list are conceptually evaluated together, so
`double_price` doesn't exist yet when the next expression is read.

Two ways out, both available today:

```sql
-- repeat the expression
SELECT price * 2 AS double_price,
       (price * 2) + 10 AS more
FROM   products;
```

or wait for Day 39/41, where derived tables and CTEs let you name something once
and reuse it. The repeat-the-expression version is what you use until then.

💡 **Note** — `ORDER BY` *can* use an alias (Day 5), and `GROUP BY` can too
(Day 20). `WHERE` and `SELECT` cannot. The reason is the logical evaluation
order of a query, which is the centrepiece of Day 21. File the exception away;
it'll make sense then.

---

## Traps & Gotchas

| # | Trap | Consequence |
|---|---|---|
| 1 | Forgetting a comma between columns | Silently becomes an alias. No error. Wrong result. |
| 2 | `AS 'My Name'` with single quotes | Error. Aliases use double quotes. |
| 3 | Expecting `SupplierName` to stay capitalised | Unquoted identifiers fold to lowercase. |
| 4 | Concatenating a nullable column | One NULL wipes the whole string. |
| 5 | Reusing an alias in the same `SELECT` list | `column does not exist`. Repeat the expression. |
| 6 | Expecting `price > 500` to filter | It adds a boolean column. `WHERE` filters — Day 7. |
| 7 | Trailing zeros after numeric multiplication | Expected: scales add. `round()` on Day 14. |
| 8 | `SELECT *` in application code | Breaks the day someone adds a column. |

---

## Interview angles

- **Junior** — "Why avoid `SELECT *`?" → schema fragility, wasted I/O, no
  index-only scans, unclear intent.
- **Junior** — "How do you rename a column in the output?" → `AS`, and it
  affects only the result, not the table.
- **Mid** — "Why can't I use a `SELECT` alias in the `WHERE` clause?" →
  Logical processing order: `WHERE` is evaluated before `SELECT`, so the alias
  doesn't exist yet. `ORDER BY` runs after `SELECT`, so there it works.
- **Mid** — "What's a computed/derived column?" → An expression evaluated per
  row at query time. Distinguish it from a *generated column*, which is stored
  on disk and defined in DDL (Day 71).
- **Senior** — "Would you store `line_total` or compute it?" → The real answer
  is "it depends, and here's the trade-off": computing keeps one source of
  truth and can never drift; storing is a denormalization that buys read
  performance and, crucially, **preserves history** — if prices change, a stored
  total keeps what the customer actually paid. In practice you store
  `unit_price` on the line (as this schema does, capturing price at sale time)
  and compute the total. Day 64.

---

## Practice

### Section A — Drill (new concept only)

1. Show only `product_name` and `price` from `products`.
2. Show `price` before `product_name`.
3. Show `first_name`, `last_name` and `country` from `customers`.
4. Show `order_id`, `order_date` and `status` from `orders`.
5. Show `supplier_name` aliased as `vendor`.
6. Show `product_name` as `"Product"` and `price` as `"Price (EUR)"`.
7. Show `category_name` from `categories` aliased as `label`.
8. Show `first_name` and `last_name` from `employees`, aliased `given` and
   `family`.
9. Show every product's name and its price doubled, aliased `double_price`.
10. Show every product's name and price increased by 10%, aliased `new_price`.
11. Show every product's name, price, cost and `price - cost` as `margin`.
12. Show every product's name and `price * stock_quantity` as `stock_value`.
13. Show `order_id`, `quantity`, `unit_price` and `quantity * unit_price` as
    `gross_line` from `order_items`.
14. Now add the discount: `quantity * unit_price * (1 - discount_pct)` as
    `line_total`.
15. Show each employee's `salary` and `salary / 12` as `monthly_salary`. Is the
    result exact? Why?
16. Show each customer's full name as one column called `full_name`.
17. Show each employee's full name plus their `job_title`, as
    `'Name — Title'` in a single column.
18. Show each product's name and `price > 100` as `is_premium`.
19. Show each product's name and `is_discontinued` as `retired`.
20. Show each customer's name and `is_active` as `active`.
21. Show `product_name` and `stock_quantity = 0` as `out_of_stock`.
22. Show each supplier's name and `rating >= 4.0` as `is_preferred`.
23. Show `order_id` and `shipping_cost = 0` as `free_shipping`.
24. Show `product_name` twice in one result, aliased `a` and `b`.
25. Write a four-line, commented query returning `product_name` and `price`.

### Section B — Combination (with Days 01–03)

26. For every product, show name, price, cost, and profit margin **as a
    percentage** of price: `(price - cost) / price * 100`. Alias it
    `margin_pct`. Look at the numbers — do they look right, or are they all
    zero? Explain. (Hint: Day 2, integer division… or is it? Check
    `pg_typeof(price)`.)
27. For every order item, show `order_id`, `product_id` and the line total
    rounded to a sensible number of decimals by casting:
    `(quantity * unit_price * (1 - discount_pct))::numeric(10,2)`.
28. For every customer, show a single column:
    `'Customer #' || customer_id || ': ' || first_name || ' ' || last_name`.
29. For every customer, show `first_name || ' from ' || city`. How many rows
    come back blank, and which customers are they?
30. For every product, show name and `price::integer`. Which products change
    value, and did it round or truncate?
31. For every employee, show name, salary, and salary with a 7% raise applied,
    to two decimals.
32. For every order, show `order_id`, `order_date`, and
    `'Order ' || order_id || ' placed on ' || order_date`.
33. For every product, show name, `weight_kg`, and `weight_kg * 1000` as
    `weight_grams`. Which rows are blank and why?
34. For every review, show `rating`, `helpful_votes`, and
    `rating * helpful_votes` as `impact_score`.
35. For every payment, show `amount` and `amount * 0.029 + 0.30` as
    `est_processor_fee`, to two decimals.
36. For every product, show name and three booleans: `price > 1000` as
    `premium`, `stock_quantity > 50` as `well_stocked`, and `cost > 100` as
    `expensive_to_source`.
37. For every customer, show `country` and whether `country = 'Germany'` as
    `is_german`. How many `t` values are there? (Count by eye.)
38. For every order item, show `order_id` and `discount_pct * 100` as
    `discount_percent_display`.
39. Show `count(*)` from `order_items` and confirm it matches the derived-column
    query from problem 14.
40. Using no table at all, compute the line total for 3 units of a 199.00 item
    at a 10% discount, and confirm by finding that exact line in `order_items`.

### Section C — Recall (Days 01–03)

41. Which database are you connected to?
42. List all nine tables.
43. Describe `payments`. Which columns can be NULL?
44. How many rows are in `customers`, `orders` and `payments`?
45. Return the text `'Day 4 complete'` with no table.
46. What is `pg_typeof(price)`? (You'll need a table for this one — think about
    which.)
47. What does `7 / 2` return, and how do you get `3.5`?
48. Turn expanded display on, show one wide table, turn it off.
49. Reset the database and verify all nine row counts.

### Section D — Challenge

50. Predict, then run:
    ```sql
    SELECT product_name price FROM products;
    ```
    What is the column heading? What happened? Why is this dangerous?
51. Predict, then run:
    ```sql
    SELECT price * 2 AS dbl, dbl * 2 AS quad FROM products;
    ```
52. Build a single text column describing each product completely, e.g.
    `Laptop Pro 14 (Electronics/Computers/Laptops) — 1899.00, 12 in stock`.
    You only have `category_id`, not the category names — so use the id, and
    note what you'd need to do it properly. (You'll do it properly on Day 27.)
53. For every order item, compute the line total two ways —
    `quantity * unit_price * (1 - discount_pct)` and
    `quantity * (unit_price - unit_price * discount_pct)` — and a third column
    comparing them with `=`. Are they always equal? What does that tell you
    about `numeric` arithmetic versus floating point?
54. Without `WHERE`, produce a result that makes it obvious at a glance which
    products are out of stock. (More than one good answer.)

---

## Solutions

**1.** `SELECT product_name, price FROM products;`
**2.** `SELECT price, product_name FROM products;`
**3.** `SELECT first_name, last_name, country FROM customers;`
**4.** `SELECT order_id, order_date, status FROM orders;`
**5.** `SELECT supplier_name AS vendor FROM suppliers;`
**6.** `SELECT product_name AS "Product", price AS "Price (EUR)" FROM products;`
**7.** `SELECT category_name AS label FROM categories;`
**8.** `SELECT first_name AS given, last_name AS family FROM employees;`
**9.** `SELECT product_name, price * 2 AS double_price FROM products;`
**10.** `SELECT product_name, price * 1.1 AS new_price FROM products;`
**11.** `SELECT product_name, price, cost, price - cost AS margin FROM products;`
**12.** `SELECT product_name, price * stock_quantity AS stock_value FROM products;`
**13.** `SELECT order_id, quantity, unit_price, quantity * unit_price AS gross_line FROM order_items;`
**14.**
```sql
SELECT order_id,
       quantity,
       unit_price,
       quantity * unit_price * (1 - discount_pct) AS line_total
FROM   order_items;
```
**15.** `SELECT salary, salary / 12 AS monthly_salary FROM employees;` — exact,
because `salary` is `numeric(10,2)`, and `numeric / integer` stays `numeric`.
You get many decimal places (e.g. 185000.00 / 12 = 15416.666…), not truncation.
Integer division only happens when **both** operands are integers.
**16.** `SELECT first_name || ' ' || last_name AS full_name FROM customers;`
**17.** `SELECT first_name || ' ' || last_name || ' — ' || job_title FROM employees;`
**18.** `SELECT product_name, price > 100 AS is_premium FROM products;`
**19.** `SELECT product_name, is_discontinued AS retired FROM products;`
**20.** `SELECT first_name, is_active AS active FROM customers;`
**21.** `SELECT product_name, stock_quantity = 0 AS out_of_stock FROM products;`
**22.** `SELECT supplier_name, rating >= 4.0 AS is_preferred FROM suppliers;`
**23.** `SELECT order_id, shipping_cost = 0 AS free_shipping FROM orders;`
**24.** `SELECT product_name AS a, product_name AS b FROM products;`
**25.**
```sql
-- All products and what we charge for them
SELECT product_name,   -- customer-facing name
       price           -- retail price, EUR
FROM   products;
```

**26.**
```sql
SELECT product_name,
       price,
       cost,
       (price - cost) / price * 100 AS margin_pct
FROM   products;
```
The numbers are correct, not zero — because `price` and `cost` are `numeric`,
not `integer`, so no integer division occurs. `Laptop Pro 14`:
(1899 − 1400) / 1899 × 100 ≈ 26.28. The trap you were braced for doesn't fire
here, and knowing *why* is the lesson: check the column's type, don't assume.
`SELECT pg_typeof(price) FROM products;` confirms `numeric`.

**27.**
```sql
SELECT order_id,
       product_id,
       (quantity * unit_price * (1 - discount_pct))::numeric(10,2) AS line_total
FROM   order_items;
```
Casting to `numeric(10,2)` rounds to two decimals. `round()` is the idiomatic
way and arrives on Day 14.

**28.**
```sql
SELECT 'Customer #' || customer_id || ': ' || first_name || ' ' || last_name
         AS label
FROM   customers;
```
**29.** Two blank rows — Marie Dubois (7) and Nina Petrova (18), both with
`city IS NULL`.
**30.** `SELECT product_name, price::integer FROM products;` — every product
with a fractional price changes. `29.99 → 30`, `34.95 → 35`, `39.99 → 40`. It
**rounds to nearest**, it does not truncate. `trunc(29.99)` gives 29.
**31.**
```sql
SELECT first_name, salary, (salary * 1.07)::numeric(10,2) AS raised
FROM   employees;
```
**32.**
```sql
SELECT order_id,
       order_date,
       'Order ' || order_id || ' placed on ' || order_date AS summary
FROM   orders;
```
**33.** `SELECT product_name, weight_kg, weight_kg * 1000 AS weight_grams FROM products;`
— no blanks here; every product has a weight in this dataset. (Had any been
NULL, both `weight_kg` and `weight_grams` would be blank: arithmetic on NULL
yields NULL, just like concatenation.)
**34.** `SELECT rating, helpful_votes, rating * helpful_votes AS impact_score FROM reviews;`
**35.**
```sql
SELECT amount, (amount * 0.029 + 0.30)::numeric(10,2) AS est_processor_fee
FROM   payments;
```
**36.**
```sql
SELECT product_name,
       price > 1000          AS premium,
       stock_quantity > 50   AS well_stocked,
       cost > 100            AS expensive_to_source
FROM   products;
```
**37.** `SELECT country, country = 'Germany' AS is_german FROM customers;` —
four `t`: customers 1, 17, 21, 22.
**38.** `SELECT order_id, discount_pct * 100 AS discount_percent_display FROM order_items;`
**39.** Both return 105 rows. Adding derived columns never changes the row
count — a useful invariant to hold on to.
**40.** `SELECT 2 * 199.00 * (1 - 0.100);` → 358.200. That is order 45's line:
2 × Noise Cancelling Headphones at 10% off.

**41.** `\conninfo` or `SELECT current_database();`
**42.** `\dt`
**43.** `\d payments` — only `payment_id`… actually every column in `payments`
is `NOT NULL`. That's worth noticing: not all tables have nullable columns.
**44.** 24, 60, 56.
**45.** `SELECT 'Day 4 complete';`
**46.** `SELECT pg_typeof(price) FROM products;` → `numeric`, repeated 25 times
(once per row, since it is a per-row expression like any other).
**47.** `3`; use `7::numeric / 2` or `7.0 / 2`.
**48.** `\x`, query, `\x`.
**49.** `\i 99_reset.sql` — 10, 6, 25, 24, 12, 60, 105, 56, 36.

**50.** The heading is `price`, and the values are **product names**. The
missing comma turned `price` into an alias for `product_name`. No error, no
warning, and a report that looks plausible and is wrong. This is exactly why
you always write `AS`: `SELECT product_name AS price FROM products;` is at
least obviously deliberate.

**51.**
```
ERROR:  column "dbl" does not exist
LINE 1: SELECT price * 2 AS dbl, dbl * 2 AS quad FROM products;
                                 ^
```
Aliases are not visible to other expressions in the same `SELECT` list. Repeat
the expression, or wait for CTEs on Day 41.

**52.**
```sql
SELECT product_name || ' (category ' || category_id || ') — '
       || price || ', ' || stock_quantity || ' in stock' AS description
FROM   products;
```
To print `Laptops` instead of `3` you need to reach into the `categories` table
from a query over `products`. That is a **join**, and it is Day 27. Worth noting
the limitation consciously now: everything you have built so far touches exactly
one table.

**53.**
```sql
SELECT quantity * unit_price * (1 - discount_pct)                  AS method_a,
       quantity * (unit_price - unit_price * discount_pct)         AS method_b,
       quantity * unit_price * (1 - discount_pct)
         = quantity * (unit_price - unit_price * discount_pct)     AS same
FROM   order_items;
```
Every row returns `t`. Because `numeric` is **exact decimal** arithmetic, the
two algebraically equivalent forms give bit-identical results. Repeat the same
experiment with `float8` and you will find rows where it returns `f`, because
binary floating point is not associative or distributive. This is the whole
argument for `numeric` in financial code, in three lines of SQL — and it is a
strong thing to be able to demonstrate in an interview.

**54.** Several good answers:
```sql
-- a boolean flag column
SELECT product_name, stock_quantity, stock_quantity = 0 AS out_of_stock
FROM   products;

-- or a text marker that stands out when scanning
SELECT product_name || CASE WHEN stock_quantity = 0 THEN '  <-- OUT OF STOCK'
                            ELSE '' END
FROM   products;      -- CASE is Day 17; the boolean version is today's tool
```
The honest Day-4 answer is the first one. Filtering to *only* the out-of-stock
rows needs `WHERE` — tomorrow's neighbour, Day 7.

---

## Day 04 Checklist

- [ ] I can select specific columns in any order I choose
- [ ] I always write `AS`, and I know what a forgotten comma does
- [ ] I know aliases use double quotes, never single
- [ ] I can write a derived column and name it
- [ ] I know `quantity * unit_price * (1 - discount_pct)` by heart
- [ ] I can concatenate columns and literals with `||`
- [ ] I have seen a NULL wipe out a concatenated string, in real data
- [ ] I know a boolean expression adds a column, it does not filter
- [ ] I know I cannot reuse an alias inside the same `SELECT` list
- [ ] My queries are formatted across multiple lines

---

## What's next

**Day 05 — `ORDER BY`, `LIMIT` and `DISTINCT`.** You take control of the order
rows come back in, ask for just the top few, and strip duplicates — which
together answer questions like "what are the five most expensive products?" and
"which countries do we sell to?" without any filtering at all.
