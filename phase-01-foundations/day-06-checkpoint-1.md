# Day 06 — ✅ Checkpoint 1

> **Phase** 1 · Foundations
> **Level** Absolute Beginner
> **Time** 120–150 minutes
> **Prerequisites** Days 01–05
> **New concepts** None. This is a test.
> **Pass mark** 42 / 60 (70%)

---

## How to take this checkpoint

1. **Close every other file.** No `DATA_DICTIONARY.md`, no day files, no notes.
   You may use `\d tablename` and `\?` — those are tools a working engineer has
   at the prompt. You may not use the solutions.
2. **Work through all 60 problems in order.** Write each query, run it, and
   mark it right or wrong yourself.
3. **Mark honestly.** A query that errors three times before working is still
   correct — but note it. A query that returns plausible-looking wrong data is
   incorrect, and those are the ones that matter.
4. **Only then** read the solutions, and re-do every problem you got wrong.
5. **Record your score in `PROGRESS.md`.**

**Below 42/60: repeat Days 1–5's Section A and B problems before Day 7.** That
costs you two days. Carrying a gap in `SELECT`, `ORDER BY` and `NULL`-awareness
into the next hundred days costs you far more.

> Reminder — you do not know `WHERE` yet. Nothing in this checkpoint requires
> it. If you find yourself wanting to filter rows, re-read the question: the
> answer uses `ORDER BY`, `LIMIT`, `DISTINCT`, `DISTINCT ON`, or a computed
> boolean column.

---

## Part 1 — Environment & psql (8 problems)

1. Show which database, user and port you are connected to.
2. List every table in the current database.
3. Describe the `reviews` table. Which of its columns may be NULL?
4. Which two tables does `order_items` reference?
5. Show the PostgreSQL version using SQL.
6. Show the server's `max_connections` setting.
7. Turn expanded display on, run `SELECT * FROM suppliers;`, turn it off.
   Describe in one sentence when expanded display is worth using.
8. Name three things a meta-command does differently from a SQL statement.

---

## Part 2 — Expressions with no table (10 problems)

9. Return the number `256`.
10. Return the text `Checkpoint 1`.
11. Compute `987 / 4`. Then compute it again so the answer has decimals.
12. Compute the remainder of `987` divided by `4`.
13. Compute `3` raised to the power `5`.
14. Return the text `Bob's laptop` — two different ways.
15. Cast the text `'1999'` to an integer and add `26`.
16. Cast `14.6` to an integer. Is the result 14 or 15? State the rule.
17. Return the data type of `100`, of `100.0`, and of `true`, in one row.
18. Generate the numbers 5, 10, 15 … 50.

---

## Part 3 — Single-table `SELECT` (12 problems)

19. Every column of `categories`.
20. Only `product_name` and `price` from `products`.
21. `order_id`, `order_date` and `status` from `orders`, in that order.
22. `first_name` and `country` from `customers`, with `country` shown first.
23. `supplier_name` aliased as `"Vendor Name"`.
24. `category_name` and `parent_category_id`, aliased `label` and `parent`.
25. How many rows are in `payments`?
26. How many rows are in `employees`?
27. Every employee's full name as a single column named `full_name`.
28. Every product's name and `price * 1.2` as `price_with_vat`.
29. Every product's name, `price`, `cost`, and `price - cost` as `margin`.
30. Every order item's `order_id` and its line total, aliased `line_total`.

---

## Part 4 — Computed & boolean columns (8 problems)

31. Every customer's name and whether they are active, aliased `active`.
32. Every product's name and whether `stock_quantity` is `0`, aliased
    `out_of_stock`.
33. Every supplier's name and whether `rating` is at least `4.0`, aliased
    `preferred`.
34. Every employee's name and whether `salary` exceeds `50000`, aliased
    `above_50k`.
35. Every product's name and its stock value (`price * stock_quantity`).
36. Every payment's `amount` and `amount * 0.02` as `fee`, to two decimal
    places.
37. Every customer's name concatenated with their country in the form
    `Anna Muller (Germany)`, aliased `label`.
38. Every customer's name concatenated with their city in the form
    `Anna lives in Berlin`. How many rows come back **blank**, and why?

---

## Part 5 — `ORDER BY` (10 problems)

39. All products, most expensive first.
40. All employees ordered by `hire_date`, longest-serving first.
41. All customers ordered by `country`, then `last_name`.
42. All employees ordered by `department` ascending, then `salary` descending.
43. All customers ordered by `city`, NULLs first.
44. All products ordered by `margin` (`price - cost`) descending, using an
    alias in the `ORDER BY`.
45. All products ordered by the length of their name, longest first.
46. All reviews ordered by `rating` descending, then `helpful_votes`
    descending.
47. All customers ordered so active customers appear first and, within each
    group, the newest signups appear first.
48. In one sentence: why does `ORDER BY margin` work when `SELECT margin + 1`
    in the same query does not?

---

## Part 6 — `LIMIT`, `OFFSET`, `DISTINCT`, `DISTINCT ON` (12 problems)

49. The 5 most expensive products.
50. The 3 cheapest products.
51. The 5 highest-paid employees.
52. Products ranked 6th–10th by price descending.
53. The single most recent order.
54. The 5 most expensive products using `FETCH FIRST`.
55. Distinct `status` values in `orders`, sorted.
56. Distinct `loyalty_tier` values in `customers`. How many rows, and why is it
    not four?
57. Distinct combinations of `department` and `job_title` from `employees`.
58. The most expensive product in each category, using `DISTINCT ON`.
59. Each customer's most recent order, using `DISTINCT ON`.
60. A query returning the 5 largest order-item line totals, written so that
    running it twice always gives the same five rows in the same order.
    Explain the part that guarantees it.

---

## Solutions

### Part 1

**1.** `\conninfo`
**2.** `\dt` → 9 tables.
**3.** `\d reviews` → nullable: `title`, `body`. Everything else is `NOT NULL`.
**4.** `orders` and `products` (read the bottom of `\d order_items`).
**5.** `SELECT version();`
**6.** `SHOW max_connections;`
**7.** `\x` / query / `\x`. Worth using when a row is wider than your terminal,
so that it wraps into an unreadable mess — expanded display prints one column
per line instead.
**8.** Meta-commands (a) start with `\`, (b) take no semicolon, (c) are executed
by `psql` on your machine and never sent to the server. A fourth: they can do
things SQL cannot, like read a file (`\i`) or change output formatting.

### Part 2

**9.** `SELECT 256;`
**10.** `SELECT 'Checkpoint 1';`
**11.** `SELECT 987 / 4;` → 246 (integer division).
`SELECT 987::numeric / 4;` → 246.75. Casting an *operand*, not the result.
**12.** `SELECT 987 % 4;` → 3
**13.** `SELECT 3 ^ 5;` → 243
**14.** `SELECT 'Bob''s laptop';` and `SELECT $$Bob's laptop$$;`
**15.** `SELECT '1999'::integer + 26;` → 2025
**16.** `SELECT 14.6::integer;` → **15**. Casting to an integer type rounds to
nearest. (Truncation is `trunc(14.6)` → 14. Integer *division* truncates; a
*cast* rounds. Two different operations, two different rules.)
**17.** `SELECT pg_typeof(100), pg_typeof(100.0), pg_typeof(true);` →
`integer`, `numeric`, `boolean`.
**18.** `SELECT generate_series(5, 50, 5);`

### Part 3

**19.** `SELECT * FROM categories;`
**20.** `SELECT product_name, price FROM products;`
**21.** `SELECT order_id, order_date, status FROM orders;`
**22.** `SELECT country, first_name FROM customers;`
**23.** `SELECT supplier_name AS "Vendor Name" FROM suppliers;` — double quotes.
**24.** `SELECT category_name AS label, parent_category_id AS parent FROM categories;`
**25.** `SELECT count(*) FROM payments;` → 56
**26.** `SELECT count(*) FROM employees;` → 12
**27.** `SELECT first_name || ' ' || last_name AS full_name FROM employees;`
**28.** `SELECT product_name, price * 1.2 AS price_with_vat FROM products;`
**29.** `SELECT product_name, price, cost, price - cost AS margin FROM products;`
**30.**
```sql
SELECT order_id,
       quantity * unit_price * (1 - discount_pct) AS line_total
FROM   order_items;
```

### Part 4

**31.** `SELECT first_name, is_active AS active FROM customers;`
**32.** `SELECT product_name, stock_quantity = 0 AS out_of_stock FROM products;`
**33.** `SELECT supplier_name, rating >= 4.0 AS preferred FROM suppliers;`
**34.** `SELECT first_name, salary > 50000 AS above_50k FROM employees;`
**35.** `SELECT product_name, price * stock_quantity AS stock_value FROM products;`
**36.** `SELECT amount, (amount * 0.02)::numeric(10,2) AS fee FROM payments;`
**37.**
```sql
SELECT first_name || ' ' || last_name || ' (' || country || ')' AS label
FROM   customers;
```
**38.**
```sql
SELECT first_name || ' lives in ' || city FROM customers;
```
**Two blank rows** — Marie Dubois (customer 7) and Nina Petrova (customer 18),
both with `city IS NULL`. Concatenating anything with `NULL` produces `NULL`, so
the whole string vanishes rather than showing a partial sentence. This is the
single most important thing on this checkpoint: it is not an edge case, it is
how customers silently drop out of production reports.

### Part 5

**39.** `SELECT product_name, price FROM products ORDER BY price DESC;`
**40.** `SELECT * FROM employees ORDER BY hire_date;`
**41.** `SELECT * FROM customers ORDER BY country, last_name;`
**42.** `SELECT * FROM employees ORDER BY department, salary DESC;`
**43.** `SELECT first_name, city FROM customers ORDER BY city NULLS FIRST;`
**44.**
```sql
SELECT product_name, price - cost AS margin
FROM   products
ORDER BY margin DESC;
```
**45.** `SELECT product_name FROM products ORDER BY length(product_name) DESC;`
**46.** `SELECT * FROM reviews ORDER BY rating DESC, helpful_votes DESC;`
**47.** `SELECT * FROM customers ORDER BY is_active DESC, signup_date DESC;`
**48.** Because `ORDER BY` is evaluated **after** the `SELECT` list, so the
alias already exists by then; expressions *inside* the `SELECT` list are all
evaluated together, so `margin` does not yet exist for a sibling expression.
(The full evaluation order is Day 21.)

### Part 6

**49.** `SELECT product_name, price FROM products ORDER BY price DESC LIMIT 5;`
**50.** `SELECT product_name, price FROM products ORDER BY price LIMIT 3;`
**51.** `SELECT * FROM employees ORDER BY salary DESC LIMIT 5;`
**52.** `SELECT product_name, price FROM products ORDER BY price DESC LIMIT 5 OFFSET 5;`
**53.** `SELECT * FROM orders ORDER BY order_date DESC LIMIT 1;` → order 60.
**54.** `SELECT product_name, price FROM products ORDER BY price DESC FETCH FIRST 5 ROWS ONLY;`
**55.** `SELECT DISTINCT status FROM orders ORDER BY status;` → cancelled,
delivered, paid, pending, returned, shipped.
**56.** `SELECT DISTINCT loyalty_tier FROM customers;` → **5** rows. The four
tiers plus `NULL`. `DISTINCT` treats `NULL` as a value and collapses all NULLs
into one row.
**57.** `SELECT DISTINCT department, job_title FROM employees ORDER BY 1, 2;` → 9 rows.
**58.**
```sql
SELECT DISTINCT ON (category_id) category_id, product_name, price
FROM   products
ORDER BY category_id, price DESC;
```
**59.**
```sql
SELECT DISTINCT ON (customer_id) customer_id, order_id, order_date
FROM   orders
ORDER BY customer_id, order_date DESC;
```
**60.**
```sql
SELECT order_item_id,
       order_id,
       quantity * unit_price * (1 - discount_pct) AS line_total
FROM   order_items
ORDER BY line_total DESC, order_item_id
LIMIT 5;
```
The guarantee comes from `order_item_id` as the final sort key. It is unique, so
the sort is **total** — no two rows can tie, so no two rows can swap places
between runs. Without it, any two lines with equal totals could come back in
either order, and the "top 5" could differ between executions. Full marks
require naming the tie-breaker specifically, not just producing five rows.

---

## Scoring

| Part | Topic | Max |
|---|---|---|
| 1 | Environment & psql | 8 |
| 2 | Expressions with no table | 10 |
| 3 | Single-table SELECT | 12 |
| 4 | Computed & boolean columns | 8 |
| 5 | ORDER BY | 10 |
| 6 | LIMIT / DISTINCT / DISTINCT ON | 12 |
| | **Total** | **60** |

**My score: _____ / 60**

| Score | Verdict |
|---|---|
| 54–60 | Excellent. Go to Day 7. |
| 42–53 | Pass. Re-do what you missed, then Day 7. |
| 30–41 | Repeat Days 3, 4 and 5 — Section A and B only. One day of work. |
| < 30 | Repeat Days 1–5 in full. This is not a setback; it is the correct call. |

### Diagnostic — what a weak part means

| Weak part | What to re-read |
|---|---|
| 1 | Day 01, Parts 4–6 |
| 2 | Day 02, Parts 3–5 (especially integer division and casting) |
| 3 | Day 03 Part 3, Day 04 Parts 1–2 |
| 4 | Day 04 Part 4 — the `SELECT` list is a list of expressions |
| 5 | Day 05 Parts 1–4 |
| 6 | Day 05 Parts 5–7 |

### Three things that must be automatic before Day 7

If any of these still needs thought, fix it now:

1. **`quantity * unit_price * (1 - discount_pct)`** — the line-total formula,
   from memory, without looking.
2. **Concatenating a nullable column produces `NULL`** — not a partial string.
3. **`LIMIT` without a deterministic `ORDER BY` is meaningless** — and
   "deterministic" means ending on a unique column.

---

## Phase 1 retrospective

Write three or four sentences in `mistakes.md` now, while it is fresh:

- Which single concept was hardest?
- Which mistake did you make more than once?
- What surprised you most about PostgreSQL?

At Checkpoint 2 you will re-read this entry. The pattern in your own errors is
more useful to you than any list of tips someone else could write.

---

## What's next

**Phase 2 — Filtering & Expressions (Days 7–18).**

Everything so far has returned *every row* in a table. Starting tomorrow you
choose which rows come back, and that single clause — `WHERE` — is the most-used
piece of syntax in the entire language.

The phase then spends twelve days on the vocabulary that lives inside `WHERE`:
boolean logic and its precedence traps, `NULL` and three-valued logic (the
single most important day in the first month), `IN`, `BETWEEN`, pattern
matching, and the string, numeric and date functions you will use for the rest
of your career.

**Day 07 — `WHERE` and comparison operators.** See you there.
