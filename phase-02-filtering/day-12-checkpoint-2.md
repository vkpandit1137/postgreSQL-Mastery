# Day 12 — ✅ Checkpoint 2

> **Phase** 2 · Filtering & Expressions
> **Level** Absolute Beginner
> **Time** 130–160 minutes
> **Prerequisites** Days 01–11
> **New concepts** None. This is a test.
> **Pass mark** 49 / 70 (70%)

---

## How to take this checkpoint

Same rules as Checkpoint 1. Close every other file. `\d tablename` is allowed;
solutions are not. Work in order, mark honestly, record the score in
`PROGRESS.md`.

**This checkpoint is weighted towards `NULL`.** Twenty of the seventy problems
involve a nullable column, because that is where the real-world failures are.
If you lose most of your marks in Part 3, repeat Day 9 before Day 13 — no
exceptions.

> Available: `SELECT`, `FROM`, aliases, expressions, `ORDER BY`, `LIMIT`,
> `OFFSET`, `DISTINCT`, `DISTINCT ON`, `WHERE`, all comparison operators,
> `AND`/`OR`/`NOT`, `IS NULL`/`IS NOT NULL`, `IS DISTINCT FROM`, `IS TRUE`/
> `IS NOT TRUE`, `IN`/`NOT IN`, `BETWEEN`/`NOT BETWEEN`, `LIKE`/`ILIKE`/
> `NOT LIKE`, `ESCAPE`, `~`/`~*`/`!~`, `= ANY(ARRAY[...])`, row comparison.
>
> Not available: `count()` beyond sanity checks, `GROUP BY`, joins, subqueries,
> `CASE`, `COALESCE`, string/date functions beyond `length()` and `lower()`.

---

## Part 1 — `WHERE` and comparison (12 problems)

1. All products priced over 700.
2. All products priced 249.00 exactly.
3. All products **not** priced 249.00.
4. All products with stock of 5 or fewer.
5. All customers from Japan.
6. All customers **not** from Germany.
7. All employees hired on or after 2022-01-01.
8. All employees earning 45000 or less.
9. All orders with a shipping cost above 10.
10. All order items with a quantity of exactly 3.
11. All products where the margin (`price - cost`) is under 20.
12. All products where `cost` is greater than half of `price`.

## Part 2 — `AND`, `OR`, `NOT`, precedence (12 problems)

13. In-stock products priced under 100.
14. Products in category 6 that cost over 60.
15. Active customers from India.
16. Customers who are `silver` **or** `bronze`.
17. Employees in Sales earning over 50000.
18. Employees **not** in Sales **and** earning under 45000.
19. Orders that are `paid` or `shipped`.
20. Orders that are **neither** `cancelled` **nor** `returned` **nor**
    `pending`.
21. Products that are cheap (under 50) **or** out of stock.
22. Products in category 3 **or** 4, restricted to those under 700 — make sure
    the restriction applies to both categories.
23. Write the same query as 22 **without** the parentheses, report the row
    count, and explain the difference in one sentence.
24. Employees in Sales or Support hired before 2022, earning over 45000.

## Part 3 — `NULL` (20 problems)

25. Customers with no phone number.
26. Customers with a phone number.
27. Verify that 25 and 26 sum to 24.
28. Products with no supplier.
29. Orders placed without a salesperson.
30. Employees with no manager.
31. Employees with no commission percentage.
32. Suppliers with no contact email.
33. Customers with neither a city nor a loyalty tier.
34. Customers missing a birth date **or** a phone number.
35. What does `NULL = NULL` return?
36. What does `NULL IS NOT DISTINCT FROM NULL` return?
37. What do `true AND NULL`, `false AND NULL`, `true OR NULL` and
    `false OR NULL` return?
38. What does `NOT NULL` return?
39. What do `'' IS NULL` and `length(NULL)` return?
40. Count customers with `city = 'Berlin'`, with `city <> 'Berlin'`, and with
    `city IS NULL`. Do all three sum to 24? Do the first two?
41. Products **not** supplied by supplier 1 — including the one with no
    supplier. Two different ways.
42. Employees whose commission is not 0.040, including those with none.
43. `SELECT count(*) FROM products WHERE category_id NOT IN (3, 4, NULL);`
    — predict the result and explain it.
44. Every employee's `salary * commission_pct` as `commission`. Which rows are
    blank and why?
- 45. Every customer's `first_name || ', ' || city`. Which rows are blank and
    why?
46. Show every customer with three boolean columns flagging whether `city`,
    `phone` and `birth_date` are NULL, with the most-incomplete rows first.
47. Explain in one sentence why `WHERE NOT (city = 'Berlin')` returns 20 rows
    rather than 22.
48. Rewrite 47 so that it returns 22.
49. `loyalty_tier = 'gold' OR loyalty_tier <> 'gold'` returns how many of 24?
    Fix it two ways.
50. `is_active` is `NOT NULL`. Under what change would `WHERE NOT is_active`
    and `WHERE is_active IS NOT TRUE` start to disagree?
51. Distinct loyalty tiers — how many rows, and why is it not 4?
52. Customers ordered by `city` with NULLs first.
53. Products where `supplier_id IS DISTINCT FROM 6`.
54. Count of orders with a salesperson plus count without — do they sum to 60?

## Part 4 — `IN`, `NOT IN`, `BETWEEN` (12 problems)

55. Products in categories 1, 6 or 7.
56. Products **not** in categories 3, 4 or 9.
57. Customers from Germany, UK or Ireland.
58. Orders with status `pending`, `paid` or `shipped`.
59. Reviews with a rating of 2 or 3.
60. Products priced between 50 and 250 inclusive.
61. Employees earning between 50000 and 100000.
62. Customers who signed up during 2024.
63. Products **not** priced between 50 and 250.
64. `SELECT count(*) FROM products WHERE price BETWEEN 250 AND 50;` — predict
    and explain.
65. Count payments in November 2024 using `BETWEEN`, and again using a
    half-open range. Which is correct, and why?
66. Products in categories 3 or 4, written with `= ANY (ARRAY[...])`.

## Part 5 — Pattern matching (8 problems)

67. Products whose name contains `laptop`, any case.
68. Customers whose last name ends with `son`.
69. Employees whose job title contains `Rep`.
70. Product names containing a digit, using a regex.

*(Problems 67–70 are the last four; Parts 1–4 supply the other 66.)*

---

## Solutions

### Part 1

**1.** `SELECT * FROM products WHERE price > 700;` → 3 (Laptop Pro 14,
Laptop Air 13, Smartphone X)
**2.** `WHERE price = 249.00;` → 2 (Office Chair, Smart Watch)
**3.** `WHERE price <> 249.00;` → 23
**4.** `WHERE stock_quantity <= 5;` → 5 (the four zero-stock products plus
Standing Desk)
**5.** `SELECT * FROM customers WHERE country = 'Japan';` → 1 (Yuki Tanaka)
**6.** `WHERE country <> 'Germany';` → 20
**7.** `SELECT * FROM employees WHERE hire_date >= DATE '2022-01-01';` → 4
(Chen, Ivan, Fatima, Liam)
**8.** `WHERE salary <= 45000;` → 5
**9.** `SELECT * FROM orders WHERE shipping_cost > 10;` → the orders at 11.99,
12.50, 13.00. Run it.
**10.** `SELECT * FROM order_items WHERE quantity = 3;` → 1 (order 19,
Wireless Mouse ×3)
**11.** `SELECT * FROM products WHERE price - cost < 20;` → run it; includes
`Wireless Mouse` (17.99), `Chef Knife` (34.99)? no — 34.99 > 20. Check each.
**12.** `SELECT * FROM products WHERE cost > price / 2;` → note `price / 2` on
`numeric` is exact, no integer division.

### Part 2

**13.** `WHERE stock_quantity > 0 AND price < 100;`
**14.** `WHERE category_id = 6 AND price > 60;` → 2 (Coffee Maker 129.99,
Blender 500W 79.99)
**15.** `WHERE is_active AND country = 'India';` → 2
**16.** `WHERE loyalty_tier IN ('silver','bronze');` → 13
**17.** `WHERE department = 'Sales' AND salary > 50000;` → 4
**18.** `WHERE department <> 'Sales' AND salary < 45000;` → 4
**19.** `WHERE status IN ('paid','shipped');` → 5
**20.** `WHERE status NOT IN ('cancelled','returned','pending');` → 52
**21.** `WHERE price < 50 OR stock_quantity = 0;`
**22.**
```sql
SELECT * FROM products WHERE (category_id = 3 OR category_id = 4) AND price < 700;
```
→ 3 rows (Budget Laptop 15 549, Smartphone Mini 699, Old Phone 2020 299).
**23.**
```sql
SELECT * FROM products WHERE category_id = 3 OR category_id = 4 AND price < 700;
```
→ 5 rows. Without brackets it parses as
`category_id = 3 OR (category_id = 4 AND price < 700)` — all three laptops
regardless of price, plus the two cheap phones. `AND` binds tighter than `OR`.
**24.**
```sql
SELECT * FROM employees
WHERE  department IN ('Sales','Support')
  AND  hire_date < DATE '2022-01-01'
  AND  salary > 45000;
```

### Part 3

**25.** `WHERE phone IS NULL;` → 5
**26.** `WHERE phone IS NOT NULL;` → 19
**27.** 5 + 19 = 24 ✓
**28.** `SELECT * FROM products WHERE supplier_id IS NULL;` → 1
**29.** `SELECT * FROM orders WHERE employee_id IS NULL;` → 6
**30.** `SELECT * FROM employees WHERE manager_id IS NULL;` → 1
**31.** `WHERE commission_pct IS NULL;` → 7
**32.** `SELECT * FROM suppliers WHERE contact_email IS NULL;` → 1
**33.** `WHERE city IS NULL AND loyalty_tier IS NULL;` → 1 (Nina Petrova)
**34.** `WHERE birth_date IS NULL OR phone IS NULL;` → 6
**35.** `NULL` — two unknowns cannot be shown equal.
**36.** `true`
**37.** `NULL`, `f`, `t`, `NULL`
**38.** `NULL`
**39.** `f` and `NULL`
**40.** 2, 20, 2. All three sum to 24 ✓. **The first two sum to 22** — the
two NULL-city customers fall out of both, because both comparisons are
`UNKNOWN`.
**41.**
```sql
SELECT * FROM products WHERE supplier_id IS DISTINCT FROM 1;
SELECT * FROM products WHERE supplier_id <> 1 OR supplier_id IS NULL;
```
Both → 22 (25 − 3 from supplier 1).
**42.** `WHERE commission_pct IS DISTINCT FROM 0.040;` → 10
**43.** **0**. A `NULL` in the `NOT IN` list makes every comparison
`FALSE OR FALSE OR UNKNOWN` = `UNKNOWN`, then `NOT UNKNOWN` = `UNKNOWN`. Nothing
is ever `TRUE`.
**44.**
```sql
SELECT first_name, salary * commission_pct AS commission FROM employees;
```
Seven blank — everyone outside Sales. Arithmetic with `NULL` yields `NULL`.
**45.**
```sql
SELECT first_name || ', ' || city FROM customers;
```
Two blank — customers 7 and 18. Concatenation with `NULL` yields `NULL`, and the
known part of the string is destroyed along with the unknown part.
**46.**
```sql
SELECT first_name, last_name,
       city       IS NULL AS no_city,
       phone      IS NULL AS no_phone,
       birth_date IS NULL AS no_birth_date
FROM   customers
ORDER  BY (city IS NULL)::int + (phone IS NULL)::int + (birth_date IS NULL)::int
          DESC;
```
Casting booleans to `int` and summing gives a "missingness score" — a neat trick
worth keeping.
**47.** `city = 'Berlin'` is `UNKNOWN` for the two NULL rows, and
`NOT UNKNOWN` is still `UNKNOWN`, so they are discarded. `NOT` cannot convert
unknown into true.
**48.** `WHERE city IS DISTINCT FROM 'Berlin';` → 22.
**49.** 20 of 24. Fix A: append `OR loyalty_tier IS NULL`. Fix B: use
`IS NOT DISTINCT FROM` / `IS DISTINCT FROM`.
**50.** The moment `is_active` becomes nullable. A row with `is_active = NULL`
gives `NOT NULL` = `UNKNOWN` (excluded) but `IS NOT TRUE` = `TRUE` (included).
**51.** 5 — four tiers plus one row for `NULL`. `DISTINCT` treats all NULLs as
equal to one another, unlike `=`.
**52.** `SELECT * FROM customers ORDER BY city NULLS FIRST;`
**53.** `SELECT * FROM products WHERE supplier_id IS DISTINCT FROM 6;` → 20
(25 − 5 from supplier 6; the NULL row is included).
**54.** 54 + 6 = 60 ✓ — safe only because `IS NULL`/`IS NOT NULL` never return
`UNKNOWN`.

### Part 4

**55.** `WHERE category_id IN (1,6,7);` → 10
**56.** `WHERE category_id NOT IN (3,4,9);` → 15
**57.** `WHERE country IN ('Germany','UK','Ireland');` → 6
**58.** `WHERE status IN ('pending','paid','shipped');` → 8
**59.** `SELECT * FROM reviews WHERE rating IN (2,3);` → 8
**60.** `WHERE price BETWEEN 50 AND 250;` → run it; inclusive at both ends.
**61.** `WHERE salary BETWEEN 50000 AND 100000;` → 4 (Marcus 98000, Aiko 76000,
Priya 71000, Tom 62000, Lucia 54000, Omar 51000) — count it yourself, the
boundary matters.
**62.** `WHERE signup_date BETWEEN DATE '2024-01-01' AND DATE '2024-12-31';` → 8
**63.** `WHERE price NOT BETWEEN 50 AND 250;`
**64.** **0**. `BETWEEN 250 AND 50` expands to `price >= 250 AND price <= 50`,
which nothing satisfies. Reversed bounds are a silent zero, not an error.
**65.**
```sql
SELECT count(*) FROM payments WHERE paid_at BETWEEN '2024-11-01' AND '2024-11-30';
SELECT count(*) FROM payments WHERE paid_at >= '2024-11-01' AND paid_at < '2024-12-01';
```
The **half-open** version is correct. `BETWEEN` coerces the upper bound to
`2024-11-30 00:00:00+00`, losing every payment made during 30 November.
**66.** `WHERE category_id = ANY (ARRAY[3,4]);` → 6

### Part 5

**67.** `WHERE product_name ILIKE '%laptop%';` → 4
**68.** `WHERE last_name LIKE '%son';` → 2 (Wilson, Nilsson)
**69.** `WHERE job_title LIKE '%Rep%';` → 4 (Senior Sales Rep, Sales Rep ×2,
Junior Sales Rep)
**70.** `WHERE product_name ~ '[0-9]';` → 6

---

## Scoring

| Part | Topic | Max |
|---|---|---|
| 1 | `WHERE` and comparison | 12 |
| 2 | `AND`, `OR`, `NOT`, precedence | 12 |
| 3 | **`NULL`** | 30 |
| 4 | `IN`, `NOT IN`, `BETWEEN` | 12 |
| 5 | Pattern matching | 4 |
| | **Total** | **70** |

**My score: _____ / 70**

| Score | Verdict |
|---|---|
| 63–70 | Excellent. Go to Day 13. |
| 49–62 | Pass. Re-do what you missed, then Day 13. |
| 35–48 | Repeat Days 8, 9 and 10. One day of work. |
| < 35 | Repeat Days 7–11 in full. |

**Special rule: if you scored below 21/30 on Part 3, repeat Day 9 regardless of
your total.** `NULL` is the foundation of everything from here on — aggregates
skip it, outer joins produce it, `NOT IN` breaks on it. A gap here compounds.

### Diagnostic

| Weak part | Re-read |
|---|---|
| 1 | Day 07, Parts 2–4 |
| 2 | Day 08, Part 4 (precedence) and Part 5 (De Morgan) |
| 3 | **Day 09, all of it** |
| 4 | Day 10, Parts 3 and 5 |
| 5 | Day 11, Parts 1–4 |

### Five things that must be automatic before Day 13

1. `= NULL` never matches. Always `IS NULL`.
2. Any `<>`, `NOT IN` or `NOT LIKE` on a nullable column **silently drops the
   NULL rows**.
3. `AND` binds tighter than `OR`. Parenthesise when both appear.
4. `BETWEEN` is inclusive — so use half-open ranges for timestamps.
5. `NOT IN` with a `NULL` anywhere returns **zero rows**.

---

## Phase 2 midpoint retrospective

Add to `mistakes.md`:

- How many of your errors in this checkpoint involved `NULL`?
- Did you catch the precedence problem in question 23 before running it?
- Which of the five "must be automatic" rules did you get wrong at least once?

Re-read your Checkpoint 1 retrospective. Have the same mistakes recurred?

---

## What's next

The second half of Phase 2 turns from *which rows* to *what values*.

**Day 13 — String functions.** Six days of functions: strings, numbers, dates,
and conditional expressions. These are the tools that turn raw columns into
report-ready output, and `COALESCE` on Day 17 finally gives you the answer to
the NULL-substitution problem you've been unable to solve since Day 4.
