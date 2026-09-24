# Day 05 — `ORDER BY`, `LIMIT` and `DISTINCT`

> **Phase** 1 · Foundations
> **Level** Absolute Beginner
> **Time** 110–140 minutes
> **Prerequisites** Days 01–04
> **New concepts** `ORDER BY` · `ASC`/`DESC` · multi-key sorting · `NULLS FIRST`/`NULLS LAST` · sorting by expression, alias and position · `LIMIT` · `OFFSET` · `FETCH FIRST` · `DISTINCT` · `DISTINCT ON` · collation's effect on sorting

---

## Why this matters

Yesterday you could show data. Today you can answer questions:

- *What are our five most expensive products?*
- *Which countries do we ship to?*
- *Who are our longest-serving employees?*

None of these need `WHERE`. They need **ordering**, **limiting** and
**de-duplication** — the three operations that turn a dump of rows into an
answer. `ORDER BY` in particular is the clause people get subtly wrong for
years: unstable sorts, mishandled NULLs, and pagination that silently skips
rows. We'll get it right the first time.

---

## Part 1 — `ORDER BY`

Recall Day 2: rows in a table have **no inherent order**. If you want an order,
you must ask.

```sql
SELECT product_name, price
FROM   products
ORDER BY price;
```

```
             product_name             |  price
--------------------------------------+---------
 Wireless Mouse                       |   29.99
 SQL Performance Explained            |   34.95
 Clean Code                           |   39.50
 Laptop Stand                         |   39.99
 The Pragmatic Programmer             |   45.00
 ...
 Laptop Pro 14                        | 1899.00
(25 rows)
```

`ORDER BY` goes **after** `FROM`. Ascending is the default.

### `ASC` and `DESC`

```sql
SELECT product_name, price
FROM   products
ORDER BY price DESC;
```

```
             product_name             |  price
--------------------------------------+---------
 Laptop Pro 14                        | 1899.00
 Laptop Air 13                        | 1099.00
 Smartphone X                         |  999.00
 Smartphone Mini                      |  699.00
 Budget Laptop 15                     |  549.00
 ...
```

`ASC` is the default and is usually omitted. Write `DESC` explicitly when you
want it.

### Sorting text

```sql
SELECT product_name
FROM   products
ORDER BY product_name;
```

Alphabetical — but *how* alphabetical depends on the database's **collation**.
This practice database was created with `LC_COLLATE 'C'`, which sorts by raw
byte value. The consequence:

```sql
SELECT country FROM customers ORDER BY country;
```

All capitals sort before all lowercase. Since every country here starts with a
capital, you won't notice — but try:

```sql
SELECT unnest(ARRAY['banana','Apple','cherry','Date']) AS word ORDER BY word;
```

```
  word
--------
 Apple
 Date
 banana
 cherry
```

Under `C` collation, `Apple` and `Date` (uppercase first letters, bytes 65–90)
sort before `banana` and `cherry` (bytes 97–122). Under a locale collation like
`en_US.UTF-8` you'd get the "natural" `Apple, banana, cherry, Date`.

🎯 **Interview** — "Why might `ORDER BY name` give different results on staging
and production?" → Different `LC_COLLATE` on the two databases, or different
glibc/ICU versions. This is not theoretical: a glibc 2.28 collation change in
2018 silently corrupted B-tree indexes on text columns across the industry
during OS upgrades. Day 66 covers it properly.

### Sorting dates and booleans

```sql
SELECT order_id, order_date FROM orders ORDER BY order_date;
```

Oldest first (2024-01-08). `DESC` gives newest first (2025-07-07).

```sql
SELECT product_name, is_discontinued FROM products ORDER BY is_discontinued;
```

`false` sorts before `true`.

---

## Part 2 — Sorting by more than one column

```sql
SELECT first_name, last_name, country
FROM   customers
ORDER BY country, last_name;
```

Sort by `country` first. **Within** each country, sort by `last_name`. The
second key only breaks ties in the first.

```
 first_name | last_name  |   country
------------+------------+-------------
 Carlos     | Silva      | Brazil
 Olivia     | Brown      | Canada
 Liu        | Yang       | China
 Peter      | Novak      | Czechia
 Ahmed      | Hassan     | Egypt
 Marie      | Dubois     | France
 Chloe      | Martin     | France
 Anna       | Muller     | Germany
 Lucas      | Meyer      | Germany
 ...
```

Hmm — look at France: `Dubois` then `Martin`, correct. But Germany shows
`Muller` before `Meyer`, which is wrong alphabetically. Is it?

`SELECT 'Muller' < 'Meyer';` → under `C` collation, compare byte by byte:
`M`=`M`, then `u` (117) vs `e` (101). So `Meyer` < `Muller`. The listing above
is illustrative rather than exact — **run it yourself and read the real
output.** That habit, checking rather than trusting a printed example, is worth
more than the example.

### Each key gets its own direction

```sql
SELECT department, salary, first_name
FROM   employees
ORDER BY department ASC, salary DESC;
```

Departments A→Z; within each department, highest paid first.

```
 department |  salary   | first_name
------------+-----------+------------
 Management | 185000.00 | Sofia
 Sales      |  98000.00 | Marcus
 Sales      |  62000.00 | Tom
 Sales      |  54000.00 | Lucia
 Sales      |  51000.00 | Omar
 Sales      |  41000.00 | Liam
 Support    |  76000.00 | Aiko
 Support    |  44000.00 | Grace
 Support    |  42000.00 | Ivan
 Warehouse  |  71000.00 | Priya
 Warehouse  |  38000.00 | Chen
 Warehouse  |  36500.00 | Fatima
(12 rows)
```

⚠️ **Trap** — `ORDER BY a, b DESC` applies `DESC` to `b` **only**. `a` is still
ascending. If you want both descending you must write
`ORDER BY a DESC, b DESC`.

---

## Part 3 — `NULL`s in sorting

Where does "no value" go?

```sql
SELECT first_name, city FROM customers ORDER BY city;
```

PostgreSQL's default: **`NULL`s sort as if larger than everything**. So:

- `ORDER BY city` (ascending) → NULLs **last**
- `ORDER BY city DESC` → NULLs **first**

Override explicitly:

```sql
SELECT first_name, city
FROM   customers
ORDER BY city NULLS FIRST;
```

```sql
SELECT first_name, city
FROM   customers
ORDER BY city DESC NULLS LAST;
```

⚠️ **Trap** — the default differs between database systems. MySQL and SQL
Server sort NULLs *first* on ascending; PostgreSQL and Oracle sort them *last*.
If a query must behave identically across engines, **always** write `NULLS
FIRST` or `NULLS LAST` explicitly. In practice, write it whenever the column is
nullable — it documents your intent to the next reader.

▶ **Try it** — run all three versions above and compare where customers 7 and
18 (the two with no city) appear.

---

## Part 4 — Sorting by an expression, an alias, or a position

### By expression

```sql
SELECT product_name, price, cost, price - cost AS margin
FROM   products
ORDER BY price - cost DESC;
```

### By alias — this works, unlike in `SELECT` or `WHERE`

```sql
SELECT product_name, price - cost AS margin
FROM   products
ORDER BY margin DESC;
```

```
             product_name             | margin
--------------------------------------+--------
 Laptop Pro 14                        | 499.00
 Laptop Air 13                        | 299.00
 Smartphone X                         | 299.00
 Smartphone Mini                      | 199.00
 Standing Desk                        | 179.00
 ...
```

Why does the alias work here when it failed yesterday inside `SELECT`? Because
`ORDER BY` is evaluated **after** the `SELECT` list, so by then `margin` exists.
This is your first concrete encounter with logical processing order, which gets
its full treatment on Day 21.

### By position number

```sql
SELECT product_name, price
FROM   products
ORDER BY 2 DESC;
```

`2` means "the second column in the `SELECT` list", i.e. `price`.

⚠️ **Trap** — positional sorting is compact and fragile. Insert a column into
the `SELECT` list and every position shifts, silently changing the sort. Fine
for a throwaway query at the prompt; never in code that ships. Prefer the alias.

### Sorting by something you didn't select

Perfectly legal:

```sql
SELECT product_name
FROM   products
ORDER BY price DESC;
```

You get names ordered by price, without showing the price. Useful, and
occasionally confusing to the reader — so show the sort column unless you have
a reason not to.

---

## Part 5 — `LIMIT` and `OFFSET`

```sql
SELECT product_name, price
FROM   products
ORDER BY price DESC
LIMIT 5;
```

```
       product_name       |  price
--------------------------+---------
 Laptop Pro 14            | 1899.00
 Laptop Air 13            | 1099.00
 Smartphone X             |  999.00
 Smartphone Mini          |  699.00
 Budget Laptop 15         |  549.00
(5 rows)
```

That's a complete, useful business answer built from two clauses.

### `OFFSET` — skip rows

```sql
SELECT product_name, price
FROM   products
ORDER BY price DESC
LIMIT 5 OFFSET 5;
```

Rows 6–10. Combined, `LIMIT`/`OFFSET` is the classic pagination pattern:

| Page | Clause |
|---|---|
| 1 | `LIMIT 10 OFFSET 0` |
| 2 | `LIMIT 10 OFFSET 10` |
| 3 | `LIMIT 10 OFFSET 20` |
| *n* | `LIMIT 10 OFFSET (n-1)*10` |

### ⚠️ Two serious traps with `LIMIT`

**Trap 1 — `LIMIT` without `ORDER BY` is meaningless.**

```sql
SELECT product_name FROM products LIMIT 5;
```

Five rows. *Which* five? Undefined. It will look stable today and change the day
the table is updated or the plan changes. "Give me 5 rows" is never the
question; "give me the top 5 by something" always is.

**Trap 2 — an unstable sort makes pagination skip and repeat rows.**

```sql
SELECT product_name, category_id
FROM   products
ORDER BY category_id
LIMIT 5 OFFSET 0;
```

There are 25 products across 10 categories, so ties are everywhere. Within
`category_id = 9` there are four books, and their relative order is
**undefined**. Page 1 might show `Clean Code`; page 2, run a second later, might
show it again — and drop another book entirely. Users see duplicates and miss
records, and the bug report says "the list is flickering".

**The fix: always end `ORDER BY` with a unique tie-breaker.**

```sql
SELECT product_name, category_id
FROM   products
ORDER BY category_id, product_id      -- product_id is unique
LIMIT 5 OFFSET 0;
```

Now the order is **total** — no ties remain — and pagination is correct.

🎯 **Interview** — "How do you paginate correctly in Postgres?" Two points get
you full marks:
1. `ORDER BY` must be deterministic — append a unique column.
2. `OFFSET` is O(n): `OFFSET 100000` makes the server fetch and discard 100,000
   rows on every page. For deep pagination use **keyset pagination** (a.k.a.
   seek method): `WHERE (sort_key, id) > (last_sort_key, last_id) ORDER BY
   sort_key, id LIMIT 10`. You'll build that on Day 74 once `WHERE` and indexes
   are in hand.

### `FETCH FIRST` — the standard spelling

```sql
SELECT product_name, price
FROM   products
ORDER BY price DESC
FETCH FIRST 5 ROWS ONLY;
```

Identical to `LIMIT 5`. `LIMIT` is a PostgreSQL/MySQL extension; `FETCH FIRST`
is ANSI SQL. Everyone writes `LIMIT`. Recognise `FETCH FIRST` when you read it.

🐘 There's a variant worth knowing:

```sql
SELECT product_name, price
FROM   products
ORDER BY price DESC
FETCH FIRST 5 ROWS WITH TIES;
```

`WITH TIES` also returns any rows tied with the last one — so you might get 6
or 7 rows. `LIMIT` cannot do this.

---

## Part 6 — `DISTINCT`

Remove duplicate rows from the result.

```sql
SELECT country FROM customers;             -- 24 rows, many repeats
SELECT DISTINCT country FROM customers;    -- 19 rows
```

```
   country
-------------
 Brazil
 Canada
 China
 Czechia
 Egypt
 France
 Germany
 India
 Ireland
 Italy
 Japan
 Kenya
 Russia
 South Korea
 Spain
 Sweden
 UAE
 UK
 USA
(19 rows)
```

(Add `ORDER BY country` to get them sorted — `DISTINCT` does not sort, even
though it often looks like it does.)

### `DISTINCT` applies to the whole row

This is the point everyone gets wrong:

```sql
SELECT DISTINCT country, city FROM customers;
```

This does **not** mean "distinct countries, plus a city". It means "distinct
*combinations* of country and city". Germany appears four times — Berlin (×2
collapses to 1), Munich, Hamburg — so you get three German rows.

```sql
SELECT DISTINCT department FROM employees;          -- 4 rows
SELECT DISTINCT department, job_title FROM employees; -- 9 rows
```

⚠️ **Trap** — `DISTINCT` is not a function and takes no parentheses.
`SELECT DISTINCT(country), city FROM customers;` *looks* like it de-duplicates
only `country`. It doesn't — the parentheses are just grouping the expression
`country`, and the `DISTINCT` still applies to both columns. This mistake is
extremely common and produces silently wrong results.

### `DISTINCT` and `NULL`

```sql
SELECT DISTINCT loyalty_tier FROM customers;
```

```
 loyalty_tier
--------------
 bronze
 gold
 platinum
 silver
 ␀
(5 rows)
```

Five rows, not four: `NULL` counts as one distinct value. `DISTINCT` treats all
NULLs as equal to each other — which, as you'll learn on Day 9, is *not* how `=`
behaves. `DISTINCT`, `GROUP BY` and `UNION` all use "is not distinct from"
semantics rather than `=`. That asymmetry is a favourite interview question.

### `DISTINCT` is not free

`DISTINCT` requires sorting or hashing the entire result. On 5 million rows
that's expensive. Beginners sprinkle it on to "fix" duplicate rows that were
actually caused by a wrong join — and hide the bug instead of fixing it.

> **Rule of thumb:** if you needed `DISTINCT` to make a join return the right
> number of rows, your join is wrong. Fix the join.

You'll revisit this on Day 30, where duplicate rows from fan-out joins are the
central hazard.

---

## Part 7 — `DISTINCT ON` 🐘

PostgreSQL-only, and genuinely useful.

```sql
SELECT DISTINCT ON (category_id)
       category_id,
       product_name,
       price
FROM   products
ORDER BY category_id, price DESC;
```

```
 category_id |             product_name             |  price
-------------+--------------------------------------+---------
           1 | Tablet 10                            |  429.00
           3 | Laptop Pro 14                        | 1899.00
           4 | Smartphone X                         |  999.00
           6 | Coffee Maker                         |  129.99
           7 | Standing Desk                        |  499.00
           9 | Designing Data-Intensive Applications|   55.00
          10 | USB-C Hub                            |   49.99
(7 rows)
```

That is **the most expensive product in each category** — a "top-1 per group"
query, in four lines, with no subquery and no window function.

How it works:

1. `ORDER BY` sorts all rows.
2. `DISTINCT ON (expr)` keeps the **first** row of each distinct `expr` value.

**The rule that makes or breaks it:** the `ORDER BY` must start with exactly the
`DISTINCT ON` expressions, in the same order. Then whatever you sort by *next*
decides which row wins.

```sql
ORDER BY category_id, price DESC   -- most expensive per category
ORDER BY category_id, price ASC    -- cheapest per category
ORDER BY category_id, added_on ASC -- oldest per category
```

Omit the `ORDER BY` and you get an arbitrary row per category — technically
legal, always a bug.

🎯 **Interview** — "Get the latest order per customer." The portable answer is
a window function (`ROW_NUMBER() OVER (PARTITION BY ...)`, Day 47). The
Postgres-native answer is `DISTINCT ON`, which is shorter and usually faster.
Giving both, and naming the trade-off (portability vs. concision), is a strong
mid-level answer.

---

## Part 8 — Clause order

You now know four clauses. They must be written in exactly this order:

```sql
SELECT   [DISTINCT] columns
FROM     table
ORDER BY sort_keys
LIMIT    n
OFFSET   m;
```

Writing `LIMIT` before `ORDER BY` is a syntax error. As you add clauses over the
next twenty days the list grows, but the ones you know never move.

---

## Traps & Gotchas

| # | Trap | Consequence |
|---|---|---|
| 1 | `LIMIT` without `ORDER BY` | "Top 5" of nothing in particular |
| 2 | Non-unique `ORDER BY` + pagination | Rows duplicated and skipped between pages |
| 3 | `ORDER BY a, b DESC` | `DESC` applies only to `b` |
| 4 | Forgetting NULLs sort last by default | Missing rows at the top of a report |
| 5 | `SELECT DISTINCT(a), b` | Looks column-specific; isn't. Applies to both. |
| 6 | `DISTINCT` to hide join duplicates | Masks a broken join |
| 7 | `ORDER BY 2` then editing the `SELECT` list | Sort silently changes |
| 8 | `DISTINCT ON` without matching `ORDER BY` | Arbitrary row per group |
| 9 | Deep `OFFSET` | O(n) — 100k rows fetched and discarded per page |
| 10 | Assuming text sort order is universal | Collation-dependent; differs across servers |

---

## Interview angles

- **Junior** — "Five most expensive products?" → `ORDER BY price DESC LIMIT 5`
- **Junior** — "`WHERE` vs `HAVING` vs `ORDER BY`?" → (You'll answer fully on
  Day 21. Today: `ORDER BY` sorts the final result and runs last.)
- **Mid** — "Why is my paginated list showing duplicates?" → Non-deterministic
  `ORDER BY`. Add a unique tie-breaker.
- **Mid** — "Is `LIMIT 10` on a 10-million-row table fast?" → With a matching
  index on the `ORDER BY` column, yes — the planner can stop after 10 rows.
  Without one it must sort 10 million rows first. Day 74.
- **Senior** — "`DISTINCT` vs `GROUP BY` for deduplication?" → Equivalent
  results; the planner usually produces the same plan (HashAggregate). `GROUP
  BY` is preferred when you also need aggregates. Neither is a fix for a wrong
  join.
- **Senior** — "Paginate a 50-million-row feed." → Keyset/seek pagination on an
  indexed, unique, monotonic key. Never `OFFSET`. Discuss cursor stability and
  what happens when rows are inserted mid-scroll.

---

## Practice

### Section A — Drill (new concept only)

1. All products, cheapest first.
2. All products, most expensive first.
3. All customers ordered by `last_name`.
4. All customers ordered by `signup_date`, newest first.
5. All employees ordered by `salary`, highest first.
6. All employees ordered by `hire_date`, longest-serving first.
7. All orders ordered by `order_date`, newest first.
8. All products ordered by `stock_quantity`, lowest first.
9. All customers ordered by `country`, then `city`.
10. All employees ordered by `department`, then `salary` descending.
11. All products ordered by `category_id`, then `price` descending.
12. All customers ordered by `city`, with NULLs first.
13. All customers ordered by `city`, with NULLs last.
14. All customers ordered by `loyalty_tier` with NULLs first.
15. The 5 most expensive products.
16. The 3 cheapest products.
17. The 5 newest customers by `signup_date`.
18. The 10 highest-paid employees.
19. Products ranked 6th–10th by price descending.
20. Customers ranked 11th–20th by `signup_date`.
21. The 5 most expensive products using `FETCH FIRST`.
22. The single most recent order.
23. Distinct countries in `customers`.
24. Distinct `status` values in `orders`.
25. Distinct `loyalty_tier` values. How many rows, and why?
26. Distinct `department` values in `employees`.
27. Distinct `method` values in `payments`.
28. Distinct combinations of `country` and `city` from `customers`.
29. Distinct combinations of `department` and `job_title` from `employees`.
30. Distinct `rating` values in `reviews`, sorted ascending.

### Section B — Combination (with Days 01–04)

31. Product name and margin (`price - cost`), highest margin first, top 5.
32. Product name and stock value (`price * stock_quantity`), highest first,
    top 5.
33. Employee full name (one column) and salary, highest first.
34. Customer full name and country, ordered by country then last name.
35. Order items with their line total, largest line total first, top 10.
36. Products with `price > 500` as a boolean column, ordered so that the `t`
    values come first. (You may not use `WHERE`.)
37. Products and their margin percentage `(price - cost) / price * 100`, best
    margin first, top 5.
38. Employees with monthly salary (`salary / 12`) to 2 decimals, highest first.
39. Customer full name and `signup_date`, oldest customer first, top 3.
40. Products and `price::integer`, ordered by the cast value descending.
41. Order items showing `order_id`, `quantity` and line total, ordered by
    `order_id` then line total descending.
42. Distinct `shipping_country` values from `orders`, sorted.
43. The 5 largest payments by amount.
44. The 5 most helpful reviews by `helpful_votes`.
45. Reviews ordered by `rating` descending then `helpful_votes` descending,
    top 10.
46. Products ordered by name length — longest name first. (Day 2 gave you
    `length()`.)
47. Customers ordered by the length of their email address, longest first,
    top 5.
48. The most expensive product in each category, using `DISTINCT ON`.
49. The cheapest product in each category, using `DISTINCT ON`.
50. The earliest order for each customer, using `DISTINCT ON`.

### Section C — Recall (Days 01–04)

51. How many rows in `order_items`?
52. Describe `orders` — which columns are nullable?
53. Return `'Day 5'` with no table.
54. What is `pg_typeof(9.99)`?
55. Concatenate `'Product: '` with `product_name` for all products.
56. What does `'x' || NULL` return?
57. Compute `1899.00 * 0.15` with no table.
58. Show all nine tables.
59. Show `customer_id` and full name for all customers, aliased properly.
60. Reset the database and confirm the nine row counts.

### Section D — Challenge

61. Predict, then run, then explain:
    ```sql
    SELECT product_name, category_id
    FROM   products
    ORDER BY category_id
    LIMIT 3 OFFSET 0;
    ```
    then
    ```sql
    SELECT product_name, category_id
    FROM   products
    ORDER BY category_id
    LIMIT 3 OFFSET 2;
    ```
    Is any product in both results correct, or is it evidence of a problem?
62. Write a query that proves `DISTINCT` applies to the whole row, not the
    first column, using `customers`.
63. Using `DISTINCT ON`, find the highest-rated review for each product.
64. Using `DISTINCT ON`, find each customer's most recent order. Then explain
    in one sentence what would go wrong if you removed the `ORDER BY`.
65. Find the 3 products with the worst margin **percentage** (not absolute
    margin). Is the answer the same as the 3 with the worst absolute margin?
66. Return the second-most-expensive product, using only today's tools.
67. Sort `customers` so that active customers come first, and within each group
    the newest signups come first.
68. Explain why this returns 25 rows and not 10:
    ```sql
    SELECT DISTINCT product_name, price FROM products;
    ```
69. `SELECT DISTINCT ON (category_id) product_name FROM products;` — run it.
    Why is this a bug even though it succeeds?
70. Using `generate_series` and `ORDER BY`, produce the numbers 1–10 in
    descending order *two different ways*.

---

## Solutions

**1.** `SELECT product_name, price FROM products ORDER BY price;`
**2.** `... ORDER BY price DESC;`
**3.** `SELECT * FROM customers ORDER BY last_name;`
**4.** `SELECT * FROM customers ORDER BY signup_date DESC;`
**5.** `SELECT * FROM employees ORDER BY salary DESC;`
**6.** `SELECT * FROM employees ORDER BY hire_date;` → Sofia Lindqvist, 2016-02-01.
**7.** `SELECT * FROM orders ORDER BY order_date DESC;` → order 60, 2025-07-07.
**8.** `SELECT product_name, stock_quantity FROM products ORDER BY stock_quantity;`
**9.** `SELECT * FROM customers ORDER BY country, city;`
**10.** `SELECT * FROM employees ORDER BY department, salary DESC;`
**11.** `SELECT * FROM products ORDER BY category_id, price DESC;`
**12.** `SELECT first_name, city FROM customers ORDER BY city NULLS FIRST;`
**13.** `... ORDER BY city NULLS LAST;` (this is also the default)
**14.** `SELECT first_name, loyalty_tier FROM customers ORDER BY loyalty_tier NULLS FIRST;`
**15.** `SELECT product_name, price FROM products ORDER BY price DESC LIMIT 5;`
**16.** `... ORDER BY price LIMIT 3;` → Wireless Mouse 29.99, SQL Performance
Explained 34.95, Clean Code 39.50.
**17.** `SELECT * FROM customers ORDER BY signup_date DESC LIMIT 5;`
**18.** `SELECT * FROM employees ORDER BY salary DESC LIMIT 10;`
**19.** `SELECT product_name, price FROM products ORDER BY price DESC LIMIT 5 OFFSET 5;`
**20.** `SELECT * FROM customers ORDER BY signup_date LIMIT 10 OFFSET 10;`
**21.** `SELECT product_name, price FROM products ORDER BY price DESC FETCH FIRST 5 ROWS ONLY;`
**22.** `SELECT * FROM orders ORDER BY order_date DESC LIMIT 1;`
**23.** `SELECT DISTINCT country FROM customers ORDER BY country;` → 19 rows.
**24.** `SELECT DISTINCT status FROM orders ORDER BY status;` → 6 rows:
cancelled, delivered, paid, pending, returned, shipped.
**25.** `SELECT DISTINCT loyalty_tier FROM customers;` → **5** rows: the four
tiers plus `NULL`. `DISTINCT` treats NULL as a value.
**26.** 4 rows: Management, Sales, Support, Warehouse.
**27.** 5 rows: bank_transfer, card, cash_on_delivery, gift_card, paypal.
**28.** `SELECT DISTINCT country, city FROM customers ORDER BY country, city;` →
distinct *pairs*. Germany yields 3 (Berlin, Hamburg, Munich) even though four
customers are German.
**29.** `SELECT DISTINCT department, job_title FROM employees ORDER BY 1,2;` →
9 rows (12 employees, but some share a title).
**30.** `SELECT DISTINCT rating FROM reviews ORDER BY rating;` → 2,3,4,5. No
1-star reviews in this dataset.

**31.**
```sql
SELECT product_name, price - cost AS margin
FROM   products
ORDER BY margin DESC
LIMIT 5;
```
→ Laptop Pro 14 (499), Laptop Air 13 (299), Smartphone X (299), Smartphone Mini
(199), Standing Desk (179).
Note the tie at 299 — and note that nothing breaks the tie, so the relative
order of those two rows is undefined. Add `, product_id` to make it
deterministic. That is the Trap-2 lesson applied without being asked, which is
the habit to build.

**32.**
```sql
SELECT product_name, price * stock_quantity AS stock_value
FROM   products
ORDER BY stock_value DESC, product_id
LIMIT 5;
```
**33.**
```sql
SELECT first_name || ' ' || last_name AS full_name, salary
FROM   employees
ORDER BY salary DESC;
```
**34.**
```sql
SELECT first_name || ' ' || last_name AS full_name, country
FROM   customers
ORDER BY country, last_name;
```
**35.**
```sql
SELECT order_id, product_id,
       quantity * unit_price * (1 - discount_pct) AS line_total
FROM   order_items
ORDER BY line_total DESC, order_item_id
LIMIT 10;
```
Top line: order 2's `Laptop Pro 14` at 1804.05, or order 25's at 1899.00 —
run it and see.
**36.**
```sql
SELECT product_name, price > 500 AS expensive
FROM   products
ORDER BY expensive DESC, price DESC;
```
`true` sorts after `false` ascending, so `DESC` puts the `t` rows first. This is
a nice demonstration that booleans are ordinary sortable values.
**37.**
```sql
SELECT product_name, (price - cost) / price * 100 AS margin_pct
FROM   products
ORDER BY margin_pct DESC
LIMIT 5;
```
**38.**
```sql
SELECT first_name, (salary / 12)::numeric(10,2) AS monthly
FROM   employees
ORDER BY monthly DESC;
```
**39.** `SELECT first_name || ' ' || last_name AS full_name, signup_date FROM customers ORDER BY signup_date LIMIT 3;`
→ Olivia Brown (2022-08-17), James Wilson (2022-11-30), Peter Novak (2022-12-09).
**40.** `SELECT product_name, price::integer AS rounded FROM products ORDER BY rounded DESC;`
**41.**
```sql
SELECT order_id, quantity,
       quantity * unit_price * (1 - discount_pct) AS line_total
FROM   order_items
ORDER BY order_id, line_total DESC;
```
**42.** `SELECT DISTINCT shipping_country FROM orders ORDER BY shipping_country;`
**43.** `SELECT * FROM payments ORDER BY amount DESC LIMIT 5;`
**44.** `SELECT * FROM reviews ORDER BY helpful_votes DESC LIMIT 5;` → the DDIA
review with 88 votes leads.
**45.** `SELECT * FROM reviews ORDER BY rating DESC, helpful_votes DESC LIMIT 10;`
**46.** `SELECT product_name, length(product_name) AS len FROM products ORDER BY len DESC;`
→ `Designing Data-Intensive Applications` (36).
**47.** `SELECT email, length(email) AS len FROM customers ORDER BY len DESC LIMIT 5;`
**48.**
```sql
SELECT DISTINCT ON (category_id) category_id, product_name, price
FROM   products
ORDER BY category_id, price DESC;
```
**49.** Same, with `ORDER BY category_id, price ASC`.
**50.**
```sql
SELECT DISTINCT ON (customer_id) customer_id, order_id, order_date
FROM   orders
ORDER BY customer_id, order_date;
```
20 rows — one per customer who has ordered. (Four customers have no orders and
so cannot appear; finding *those* needs a join, Day 29.)

**51.** 105  **52.** `employee_id`, `shipping_city`, `shipping_country`
**53.** `SELECT 'Day 5';`  **54.** `numeric`
**55.** `SELECT 'Product: ' || product_name FROM products;`
**56.** `NULL`  **57.** `SELECT 1899.00 * 0.15;` → 284.8500
**58.** `\dt`
**59.** `SELECT customer_id, first_name || ' ' || last_name AS full_name FROM customers;`
**60.** `\i 99_reset.sql`

**61.** Both pages are drawn from a sort on `category_id` alone, and
`category_id` is heavily tied — products 1, 2 and 3 all have `category_id = 3`,
and there are four books in category 9. With ties, PostgreSQL may return tied
rows in any order, and it is free to choose differently between the two
executions. So a product appearing in both result sets **is** evidence of the
problem: your pages are not carving up a stable list. The fix is
`ORDER BY category_id, product_id`.

**62.**
```sql
SELECT DISTINCT country FROM customers;          -- 19 rows
SELECT DISTINCT country, city FROM customers;    -- more than 19
SELECT DISTINCT (country), city FROM customers;  -- identical to the line above
```
The third query is the proof: wrapping `country` in parentheses changes nothing.
`DISTINCT` is a modifier on the whole select list, not a function.

**63.**
```sql
SELECT DISTINCT ON (product_id) product_id, customer_id, rating, title
FROM   reviews
ORDER BY product_id, rating DESC, helpful_votes DESC;
```
Note the second tie-breaker: among equally-rated reviews, the most helpful wins.
Without it, ties are resolved arbitrarily.

**64.**
```sql
SELECT DISTINCT ON (customer_id) customer_id, order_id, order_date
FROM   orders
ORDER BY customer_id, order_date DESC;
```
Remove the `ORDER BY` and PostgreSQL still returns one row per customer — but
*which* row is arbitrary and may change between runs. The query would look
correct, pass code review, and return a different "most recent order" next
Tuesday.

**65.**
```sql
SELECT product_name,
       price - cost                        AS margin,
       (price - cost) / price * 100        AS margin_pct
FROM   products
ORDER BY margin_pct
LIMIT 3;
```
→ `Old Phone 2020` (16.4%), `Budget Laptop 15` (23.5%), `Laptop Air 13` (27.2%)
— run it to confirm. The absolute-margin bottom three are the cheap
accessories (`Wireless Mouse`, margin 17.99), which have *excellent*
percentages. Different question, different answer. Choosing between absolute and
relative measures is a judgement call you will make constantly in reporting
work, and getting it wrong is how dashboards mislead people.

**66.**
```sql
SELECT product_name, price
FROM   products
ORDER BY price DESC
LIMIT 1 OFFSET 1;
```
→ Laptop Air 13. (`OFFSET 1` skips the top row.) Note this returns the
second row, not necessarily the "second distinct price" — if two products tied
for most expensive, this would return the other one of the pair. Getting
"second distinct value" properly needs window functions, Day 47.

**67.**
```sql
SELECT first_name, is_active, signup_date
FROM   customers
ORDER BY is_active DESC, signup_date DESC;
```
**68.** Because `DISTINCT` operates on the *combination* of `product_name` and
`price`, and all 25 products have distinct names. Nothing can collapse. If you
wanted distinct prices you'd write `SELECT DISTINCT price FROM products;` — 25
rows again here, since no two products share a price. Try
`SELECT DISTINCT category_id FROM products;` → 9 rows (category 2 has no direct
products).

**69.** It succeeds and returns 9 rows — one arbitrary product per category.
There is no `ORDER BY`, so PostgreSQL picks whichever row it encounters first,
which depends on physical storage and the plan. The result is
non-deterministic. `DISTINCT ON` without a matching `ORDER BY` is always a bug,
even when the output looks fine. PostgreSQL will not warn you.

**70.**
```sql
SELECT generate_series(1, 10) AS n ORDER BY n DESC;
SELECT generate_series(10, 1, -1) AS n;
```
The first sorts an ascending series; the second generates it descending and
needs no sort at all. On ten rows this is irrelevant; on ten million it is the
difference between an instant answer and a disk spill. Producing data in the
order you need it, rather than sorting afterwards, is a recurring performance
theme from Day 74 onward.

---

## Day 05 Checklist

- [ ] I can sort ascending and descending, by one key and by several
- [ ] I know `ORDER BY a, b DESC` leaves `a` ascending
- [ ] I know NULLs sort last by default in Postgres, and how to override it
- [ ] I can sort by an expression, an alias, and a position — and I know why
      the alias works here but not in `SELECT`
- [ ] I never write `LIMIT` without `ORDER BY`
- [ ] I always add a unique tie-breaker when paginating, and I can say why
- [ ] I know `DISTINCT` applies to the entire select list
- [ ] I know `DISTINCT` counts NULL as a value
- [ ] I can write a top-1-per-group query with `DISTINCT ON`
- [ ] I know `DISTINCT ON` without a matching `ORDER BY` is a bug

---

## What's next

**Day 06 — Checkpoint 1.** No new concepts. Sixty mixed problems covering
Days 1–5, a self-assessment, and an honest score. If you score below 70%,
you repeat the phase before starting `WHERE` on Day 7 — and that will be the
right decision, not a setback.
