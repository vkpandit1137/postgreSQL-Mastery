# Day 18 — ✅ Checkpoint 3 (End of Phase 2)

> **Phase** 2 · Filtering & Expressions
> **Level** Absolute Beginner → Confident Beginner
> **Time** 150–180 minutes
> **Prerequisites** Days 01–17
> **New concepts** None. This is the Phase 2 exam.
> **Pass mark** 56 / 80 (70%)

---

## How to take this checkpoint

Close everything. `\d tablename` is allowed. Solutions are not. Work in order,
mark honestly, record the score in `PROGRESS.md`.

This is the longest checkpoint so far and the last one before the shape of SQL
changes. Everything from here — aggregation, joins, subqueries, windows — sits
on top of what is tested below. A gap now is a gap forever.

Budget the full three hours. If you cannot finish in one sitting, split it
across two days rather than rushing.

> **Available:** `SELECT`/`FROM`/aliases/expressions · `ORDER BY`/`LIMIT`/
> `OFFSET`/`DISTINCT`/`DISTINCT ON` · `WHERE` · comparison operators ·
> `AND`/`OR`/`NOT` · `IS NULL`/`IS DISTINCT FROM`/`IS NOT TRUE` · `IN`/`BETWEEN`
> · `LIKE`/`ILIKE`/regex · string functions · numeric functions · date
> functions · `CASE`/`COALESCE`/`NULLIF`/`GREATEST`/`LEAST`.
>
> **Not available:** aggregates beyond `count(*)` as a sanity check, `GROUP BY`,
> joins, subqueries, window functions.

---

## Part 1 — Filtering and logic (15 problems)

1. Products priced over 400 and in stock.
2. Products in category 6 or 7 priced under 200.
3. Customers who are active and from Germany, France or Italy.
4. Employees not in Sales earning between 40000 and 80000.
5. Orders that are delivered or shipped, placed in the second half of 2024.
6. Order items with a quantity above 1 and a discount above zero.
7. Payments over 500 not made by card.
8. Reviews rated 4 or 5 with more than 20 helpful votes.
9. Products neither discontinued nor out of stock, priced over 100.
10. Write a query returning products in category 3 or 4 priced under 700 —
    then write it without parentheses, report both row counts, and explain.
11. Employees who are neither in Sales nor in Support.
12. Products not in categories 9 or 10, including any with a NULL category.
13. Customers who signed up before 2023 or after 2025-01-01.
14. Orders with free shipping that are not pending.
15. Products where cost exceeds half the price.

## Part 2 — `NULL` (15 problems)

16. Customers with no city.
17. Customers with no loyalty tier.
18. Employees with no manager.
19. Products with no supplier.
20. Orders with no salesperson.
21. Count customers with `city = 'Berlin'`, `city <> 'Berlin'` and
    `city IS NULL`. Which two sum to less than 24, and why?
22. Products not supplied by supplier 1, **including** the one with no
    supplier — two different ways.
23. Employees whose commission is not 0.040, including those with none.
24. `NULL = NULL`, `NULL IS NOT DISTINCT FROM NULL`, `NOT NULL`,
    `true OR NULL`, `false AND NULL` — in one row.
25. `SELECT count(*) FROM products WHERE category_id NOT IN (3, 4, NULL);` —
    predict and explain.
26. Why does `WHERE NOT (city = 'Berlin')` return 20 rather than 22? Fix it.
27. Every employee's `salary * commission_pct`. Which rows are blank and why?
28. The same, but showing `0.00` instead of blank.
29. Every customer's `first_name || ', ' || city`. Which rows are blank?
30. The same, so that nothing is lost — two different techniques.

## Part 3 — Ranges, sets and patterns (12 problems)

31. Products in categories 1, 6 or 7.
32. Orders with status `pending`, `paid` or `shipped`.
33. Products priced between 50 and 250 inclusive.
34. Employees hired between 2019-01-01 and 2022-12-31.
35. `SELECT count(*) FROM products WHERE price BETWEEN 250 AND 50;` — predict
    and explain.
36. Payments in November 2024 — using `BETWEEN`, then using a half-open range.
    Which is correct and why?
37. Products whose name contains `laptop`, any case.
38. Customers whose last name ends in `son`.
39. Customers whose first name starts with a vowel, using a regex.
40. Product names containing a digit, using a regex.
41. Products whose name contains a literal underscore. (There are none — write
    it correctly and prove the naive version differs.)
42. Products in categories 3 or 4, using `= ANY (ARRAY[...])`.

## Part 4 — Strings (10 problems)

43. Every customer's email domain.
44. Every customer's email local part.
45. Every customer's full name via `concat_ws`, losing nothing.
46. Every product's name and its length, longest first.
47. Every order's reference as `ORD-000001`.
48. Every customer's initials, e.g. `A.M.`.
49. Every customer's phone with `+`, `-` and spaces stripped.
50. Products whose name is longer than 25 characters.
51. `concat('a', NULL, 'b')`, `concat_ws('-', 'a', NULL, 'b')` and
    `'a' || NULL || 'b'` in one row. Explain all three.
52. Every employee's name as `LASTNAME, Firstname`.

## Part 5 — Numbers (10 problems)

53. `10 / 3` and the same as a decimal.
54. `(10 / 3)::numeric` versus `10::numeric / 3`. Explain.
55. `round(2.5::numeric)` versus `round(2.5::float8)`. Explain.
56. `0.1 + 0.2 = 0.3` versus the same with `float8` casts.
57. Every product's margin and margin percentage, rounded, best first.
58. Every order item's line total rounded to 2 decimals.
59. Every employee's monthly salary to 2 decimals.
60. Every product's stock cover in weeks (stock ÷ 7) to one decimal — make sure
    it is not integer division.
61. Every product's markup `(price - cost) / cost`, guarded against zero cost.
62. `2147483647::integer + 1` — what happens and why does it matter?

## Part 6 — Dates (10 problems)

63. Orders placed in 2025, using a half-open range.
64. Orders placed at a weekend.
65. Every order's month start as a `date`.
66. Every order's date formatted as `15 March 2024`.
67. The last day of the month containing `2024-02-10`.
68. `DATE '2024-01-31' + INTERVAL '1 month'` and then minus a month. Explain.
69. Every customer's age in whole years at 2025-01-01, excluding NULLs.
70. Every payment's `paid_at` in Berlin local time.
71. `to_char(ts, 'HH24:MM')` versus `'HH24:MI'` for a payment. Explain.
72. Every employee's whole years of service at 2025-01-01.

## Part 7 — Conditionals (8 problems)

73. Label products `premium` (≥1000), `mid-range` (≥300), `budget` (≥50),
    `accessory`.
74. Write the same with branches in the wrong order and report what happens.
75. `CASE WHEN 1 = 2 THEN 'yes' END` — what and why?
76. Orders sorted in workflow order, then by date.
77. Every customer's city, or `'unknown'`.
78. Every customer's contact: phone, else email, else `'no contact'`.
79. Every customer's count of missing fields among city, phone, birth_date and
    loyalty_tier, most incomplete first.
80. `GREATEST(1, NULL, 3)` versus `1 + NULL`. Explain the inconsistency.

---

## Solutions

### Part 1

**1.** `WHERE price > 400 AND stock_quantity > 0;`
**2.** `WHERE category_id IN (6,7) AND price < 200;`
**3.** `WHERE is_active AND country IN ('Germany','France','Italy');`
**4.** `WHERE department <> 'Sales' AND salary BETWEEN 40000 AND 80000;`
**5.**
```sql
WHERE status IN ('delivered','shipped')
  AND order_date >= DATE '2024-07-01' AND order_date < DATE '2025-01-01';
```
**6.** `WHERE quantity > 1 AND discount_pct > 0;` → 4
**7.** `WHERE amount > 500 AND method <> 'card';`
**8.** `WHERE rating IN (4,5) AND helpful_votes > 20;`
**9.** `WHERE NOT is_discontinued AND stock_quantity > 0 AND price > 100;`
**10.**
```sql
SELECT count(*) FROM products WHERE (category_id = 3 OR category_id = 4) AND price < 700;  -- 3
SELECT count(*) FROM products WHERE  category_id = 3 OR category_id = 4  AND price < 700;  -- 5
```
Without brackets, `AND` binds tighter, so it means "all of category 3, **or**
the cheap items of category 4" — the €1899 and €1099 laptops are included
despite the price condition.
**11.** `WHERE department NOT IN ('Sales','Support');` → 4
**12.** `WHERE category_id NOT IN (9,10) OR category_id IS NULL;` → 16
**13.** `WHERE signup_date < DATE '2023-01-01' OR signup_date > DATE '2025-01-01';`
**14.** `WHERE shipping_cost = 0 AND status <> 'pending';` → 9
**15.** `WHERE cost > price / 2;`

### Part 2

**16.** `WHERE city IS NULL;` → 2
**17.** `WHERE loyalty_tier IS NULL;` → 4
**18.** `WHERE manager_id IS NULL;` → 1
**19.** `WHERE supplier_id IS NULL;` → 1
**20.** `WHERE employee_id IS NULL;` → 6
**21.** 2, 20, 2. **The first two sum to 22**, not 24. The two customers with a
NULL city produce `UNKNOWN` for both `= 'Berlin'` and `<> 'Berlin'`, and `WHERE`
keeps only `TRUE`.
**22.**
```sql
WHERE supplier_id IS DISTINCT FROM 1;
WHERE supplier_id <> 1 OR supplier_id IS NULL;
```
Both → 22.
**23.** `WHERE commission_pct IS DISTINCT FROM 0.040;` → 10
**24.** `NULL`, `t`, `NULL`, `t`, `f`
**25.** **0**. The `NULL` in the list makes every comparison
`FALSE OR FALSE OR UNKNOWN` = `UNKNOWN`, then `NOT UNKNOWN` = `UNKNOWN`.
**26.** `NOT` cannot convert `UNKNOWN` to `TRUE`, so the two NULL-city rows are
still discarded. Fix: `WHERE city IS DISTINCT FROM 'Berlin';` → 22.
**27.** `SELECT first_name, salary * commission_pct FROM employees;` — seven
blanks, the non-Sales staff. Arithmetic with NULL is NULL.
**28.** `SELECT first_name, round(salary * COALESCE(commission_pct, 0), 2) FROM employees;`
**29.** Two blanks — customers 7 and 18.
**30.**
```sql
SELECT first_name || ', ' || COALESCE(city, 'unknown') AS substituted,
       concat_ws(', ', first_name, city)               AS omitted
FROM   customers;
```
`COALESCE` **substitutes** a placeholder; `concat_ws` **omits** the field and
its separator. Both are correct; which you want depends on whether the reader
should see that data is missing.

### Part 3

**31.** `WHERE category_id IN (1,6,7);` → 10
**32.** `WHERE status IN ('pending','paid','shipped');` → 8
**33.** `WHERE price BETWEEN 50 AND 250;`
**34.** `WHERE hire_date BETWEEN DATE '2019-01-01' AND DATE '2022-12-31';` → 6
**35.** **0**. `BETWEEN 250 AND 50` expands to `price >= 250 AND price <= 50`,
which is unsatisfiable. Reversed bounds give a silent zero, never an error.
**36.**
```sql
WHERE paid_at BETWEEN '2024-11-01' AND '2024-11-30';              -- loses a day
WHERE paid_at >= '2024-11-01' AND paid_at < '2024-12-01';         -- correct
```
`BETWEEN` coerces `'2024-11-30'` to midnight, excluding everything that happened
during 30 November.
**37.** `WHERE product_name ILIKE '%laptop%';` → 4
**38.** `WHERE last_name LIKE '%son';` → 2
**39.** `WHERE first_name ~ '^[AEIOU]';` → 6
**40.** `WHERE product_name ~ '[0-9]';` → 6
**41.**
```sql
SELECT count(*) FROM products WHERE product_name LIKE '%\_%';   -- 0
SELECT count(*) FROM products WHERE product_name LIKE '%_%';    -- 25
```
Unescaped, `_` matches any single character, so every non-empty name matches.
**42.** `WHERE category_id = ANY (ARRAY[3,4]);` → 6

### Part 4

**43.** `SELECT split_part(email, '@', 2) FROM customers;`
**44.** `SELECT split_part(email, '@', 1) FROM customers;`
**45.** `SELECT concat_ws(' ', first_name, last_name) FROM customers;`
**46.** `SELECT product_name, length(product_name) AS len FROM products ORDER BY len DESC;`
**47.** `SELECT 'ORD-' || lpad(order_id::text, 6, '0') FROM orders;`
**48.** `SELECT left(first_name,1) || '.' || left(last_name,1) || '.' FROM customers;`
**49.** `SELECT translate(phone, '+- ', '') FROM customers;`
**50.** `WHERE length(product_name) > 25;`
**51.** `ab`, `a-b`, `NULL`. `concat` treats NULL as `''`; `concat_ws` skips the
argument entirely; `||` propagates NULL through the whole expression.
**52.** `SELECT upper(last_name) || ', ' || first_name FROM employees;`

### Part 5

**53.** `3`; `10::numeric / 3` → `3.333…`
**54.** `3.0` versus `3.333…`. In the first, the integer division happened
before the cast — the fraction was already gone. **Cast the operand, not the
result.**
**55.** `3` and `2`. `numeric` rounds half away from zero; `float8` uses
banker's rounding (half to even).
**56.** `t` and `f`. `numeric` is exact decimal; `float8` is a binary
approximation, and `0.1 + 0.2` is `0.30000000000000004`.
**57.**
```sql
SELECT product_name, round(price - cost, 2) AS margin,
       round((price - cost) / NULLIF(price,0) * 100, 1) AS margin_pct
FROM   products ORDER BY margin_pct DESC;
```
**58.** `SELECT round(quantity * unit_price * (1 - discount_pct), 2) FROM order_items;`
**59.** `SELECT round(salary / 12, 2) FROM employees;`
**60.** `SELECT round(stock_quantity::numeric / 7, 1) FROM products;` — the cast
is essential; without it `200 / 7` is `28`.
**61.** `SELECT round((price - cost) / NULLIF(cost, 0), 4) FROM products;`
**62.** `ERROR: integer out of range`. It matters because an `integer` primary
key silently works until it doesn't, and the fix — `ALTER COLUMN ... TYPE
bigint` — rewrites the table under an exclusive lock. Use `bigint` for identity
columns from the start.

### Part 6

**63.** `WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2026-01-01';` → 8
**64.** `WHERE EXTRACT(ISODOW FROM order_date) IN (6,7);`
**65.** `SELECT date_trunc('month', order_date)::date FROM orders;`
**66.** `SELECT to_char(order_date, 'FMDD FMMonth YYYY') FROM orders;`
**67.** `SELECT (date_trunc('month', DATE '2024-02-10') + INTERVAL '1 month - 1 day')::date;` → `2024-02-29`
**68.** `2024-02-29`, then `2024-01-29` — **not** 31 January. Adding a month
clamps to the target month's last day, and the clamp destroys the information
needed to reverse it.
**69.**
```sql
SELECT first_name, EXTRACT(YEAR FROM age(DATE '2025-01-01', birth_date))::int
FROM   customers WHERE birth_date IS NOT NULL;
```
**70.** `SELECT paid_at AT TIME ZONE 'Europe/Berlin' FROM payments;`
**71.** `MM` is **month**, `MI` is minutes. A payment at 14:22 in January
renders as `14:01` with `HH24:MM` — a plausible-looking time, which is why the
bug survives review.
**72.** `SELECT first_name, EXTRACT(YEAR FROM age(DATE '2025-01-01', hire_date))::int FROM employees;`

### Part 7

**73.**
```sql
SELECT product_name, price,
       CASE WHEN price >= 1000 THEN 'premium'
            WHEN price >= 300  THEN 'mid-range'
            WHEN price >= 50   THEN 'budget'
            ELSE                    'accessory' END AS band
FROM   products;
```
**74.** With `price >= 50` first, every product over €50 is labelled `budget`
and the later branches are unreachable. No error. **Order branches most-specific
first.**
**75.** `NULL`. No branch matched and there is no `ELSE`.
**76.**
```sql
SELECT order_id, status, order_date FROM orders
ORDER  BY CASE status WHEN 'pending' THEN 1 WHEN 'paid' THEN 2
                      WHEN 'shipped' THEN 3 WHEN 'delivered' THEN 4
                      WHEN 'returned' THEN 5 WHEN 'cancelled' THEN 6 END,
          order_date;
```
**77.** `SELECT COALESCE(city, 'unknown') FROM customers;`
**78.** `SELECT COALESCE(phone, email, 'no contact') FROM customers;`
**79.**
```sql
SELECT first_name, last_name,
       (city IS NULL)::int + (phone IS NULL)::int
     + (birth_date IS NULL)::int + (loyalty_tier IS NULL)::int AS missing
FROM   customers ORDER BY missing DESC;
```
**80.** `3` and `NULL`. `GREATEST`/`LEAST` are defined to **ignore** NULL
arguments; arithmetic and comparison operators **propagate** them. It is a
genuine inconsistency in the standard, and MySQL resolves it the other way —
there, `GREATEST(1,NULL,3)` is `NULL`.

---

## Scoring

| Part | Topic | Max |
|---|---|---|
| 1 | Filtering and logic | 15 |
| 2 | `NULL` | 15 |
| 3 | Ranges, sets, patterns | 12 |
| 4 | Strings | 10 |
| 5 | Numbers | 10 |
| 6 | Dates | 10 |
| 7 | Conditionals | 8 |
| | **Total** | **80** |

**My score: _____ / 80**

| Score | Verdict |
|---|---|
| 72–80 | Excellent. Phase 3 will feel natural. |
| 56–71 | Pass. Re-do what you missed, then Day 19. |
| 40–55 | Repeat the weakest two topics' days before continuing. |
| < 40 | Repeat Days 7–17. Two or three days' work, and worth it. |

**Special rule, again: below 10/15 on Part 2 means repeat Day 9**, whatever your
total. Aggregates skip NULLs, outer joins *create* NULLs, and `NOT IN` breaks on
them. Every one of the next four phases makes NULL handling harder, not easier.

### Diagnostic

| Weak part | Re-read |
|---|---|
| 1 | Days 07–08 |
| 2 | **Day 09**, plus Day 10 Part 3 |
| 3 | Days 10–11 |
| 4 | Day 13 |
| 5 | Day 14 |
| 6 | Days 15–16 |
| 7 | Day 17 |

---

## Phase 2 retrospective

You have finished the largest phase of the program by problem count — about
400 problems across twelve days.

Write in `mistakes.md`:

- Which of the seven topics cost you the most marks?
- How many of your errors were `NULL`-related, across all three checkpoints?
- Name the single trap you have now fallen into more than once.
- Re-read your Checkpoint 1 and 2 retrospectives. What has genuinely improved?

### The ten rules you should now hold without thinking

1. `= NULL` never matches — use `IS NULL`.
2. Any `<>`, `NOT IN` or `NOT LIKE` on a nullable column silently drops NULL
   rows.
3. `NOT IN` with a NULL anywhere returns **zero rows**.
4. `AND` binds tighter than `OR` — parenthesise when both appear.
5. `BETWEEN` is inclusive, so use half-open ranges for timestamps.
6. `int / int` truncates — cast the **operand**, not the result.
7. Money is `numeric`, never a float.
8. `date_trunc` for grouping by month, never `EXTRACT(MONTH …)`.
9. `timestamptz` for anything that records when something happened.
10. Guard every division with `NULLIF(denominator, 0)`.

If any of those needs a moment's thought, find the day that covers it and re-read
the relevant part today. They are the vocabulary of everything that follows.

---

## Where you are

You can now take any single table and ask an arbitrarily precise question of it:
filter it, transform it, label it, sort it, and handle missing data
deliberately rather than accidentally.

**What you cannot yet do** is ask a question about the data *as a whole*. How
many orders? What is the average order value? Which country buys the most? Every
query so far has returned one output row per input row, and that assumption is
about to break.

---

## What's next

**Phase 3 — Aggregation (Days 19–25).**

**Day 19 — Aggregate functions.** `count`, `sum`, `avg`, `min`, `max`: many
rows collapse into one. You will immediately meet the most-asked interview
question in beginner SQL — the difference between `COUNT(*)` and
`COUNT(column)` — and you will already know the answer, because it is a NULL
question and you have spent twelve days on NULL.
