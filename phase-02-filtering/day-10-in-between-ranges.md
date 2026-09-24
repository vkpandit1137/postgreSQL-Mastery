# Day 10 — `IN`, `NOT IN` and `BETWEEN`

> **Phase** 2 · Filtering & Expressions
> **Level** Absolute Beginner
> **Time** 100–130 minutes
> **Prerequisites** Days 01–09 (especially Day 09 — `NULL`)
> **New concepts** `IN` · `NOT IN` · the `NOT IN` + `NULL` disaster · `BETWEEN` · `NOT BETWEEN` · inclusivity · half-open ranges for timestamps · `IN` on multiple columns · `ANY (ARRAY[...])`

---

## Why this matters

Yesterday's `WHERE country = 'Germany' OR country = 'France' OR country =
'India'` works, and it is horrible to read and worse to maintain. `IN` collapses
it to one line.

`BETWEEN` does the same for ranges. Both are pure convenience — they introduce
no new capability — but two things make today more than syntax sugar:

1. **`NOT IN` with a `NULL` anywhere in the list returns zero rows.** You saw the
   preview yesterday. Today you see it happen on real data, and learn the two
   safe alternatives.
2. **`BETWEEN` is inclusive at both ends**, which is exactly wrong for
   timestamps and causes a specific, recurring, hard-to-spot reporting bug.

---

## Part 1 — `IN`

```sql
SELECT product_name, category_id
FROM   products
WHERE  category_id IN (3, 4);
```

Six rows. Exactly equivalent to:

```sql
WHERE category_id = 3 OR category_id = 4
```

`IN` takes a parenthesised list and asks *"does this column equal any of
these?"*

```sql
SELECT first_name, country
FROM   customers
WHERE  country IN ('Germany', 'France', 'India');
```

Eight rows — 4 German, 2 French, 2 Indian.

```sql
SELECT order_id, status
FROM   orders
WHERE  status IN ('cancelled', 'returned');              -- 5 rows

SELECT product_name, category_id
FROM   products
WHERE  category_id IN (1, 9, 10);                        -- 13 rows

SELECT first_name, loyalty_tier
FROM   customers
WHERE  loyalty_tier IN ('gold', 'platinum');             -- 7 rows
```

Things worth knowing:

- The list can hold **any number** of values. PostgreSQL handles thousands,
  though beyond a few hundred you should be joining to a table instead (Day 27).
- The values must be **type-compatible** with the column.
- **Duplicates are harmless.** `IN (3, 3, 4)` is the same as `IN (3, 4)`.
- **Order is irrelevant.** `IN (4, 3)` is the same as `IN (3, 4)`.

🐘 A PostgreSQL alternative you will see in real code, especially from
application frameworks:

```sql
WHERE category_id = ANY (ARRAY[3, 4]);
```

Identical meaning. It exists because an array can be passed as a **single query
parameter**, whereas an `IN` list needs a variable number of placeholders. If
you have ever written string-building code to produce `IN ($1,$2,$3,...)`, this
is the fix. Arrays get a full day on Day 69.

---

## Part 2 — `NOT IN`

```sql
SELECT product_name, category_id
FROM   products
WHERE  category_id NOT IN (3, 4);
```

19 rows — the 25 products minus the 6 in categories 3 and 4.

Equivalent to `WHERE category_id <> 3 AND category_id <> 4`. Note the **`AND`**
— this is yesterday's De Morgan flip built into the operator, and it is one
reason `NOT IN` is worth having: it removes the chance of writing `OR` by
mistake.

```sql
SELECT order_id, status
FROM   orders
WHERE  status NOT IN ('cancelled', 'returned', 'pending');   -- 52 rows

SELECT first_name, department
FROM   employees
WHERE  department NOT IN ('Sales', 'Support');               -- 4 rows
```

---

## Part 3 — ⚠️ The `NOT IN` + `NULL` disaster

This is the reason `NOT IN` is taught *after* Day 9.

### Failure mode 1 — a `NULL` in the list

```sql
SELECT count(*) FROM products WHERE category_id NOT IN (3, 4);        -- 19
SELECT count(*) FROM products WHERE category_id NOT IN (3, 4, NULL);  --  0
```

**Zero rows.** Adding a value to an exclusion list cannot logically *reduce* the
result to nothing — and yet it does.

The expansion, exactly as on Day 9:

```
category_id NOT IN (3, 4, NULL)
  ≡ NOT (cat = 3 OR cat = 4 OR cat = NULL)
  ≡ NOT (FALSE OR FALSE OR UNKNOWN)      for, say, cat = 10
  ≡ NOT UNKNOWN
  ≡ UNKNOWN                              → row discarded
```

Every row hits `UNKNOWN`. Every row is discarded. **No error, no warning.**

Nobody types a literal `NULL` into an `IN` list. The bug arrives when the list
comes from a subquery (Day 37) over a nullable column — and then one `NULL` row
anywhere in a ten-million-row table silently empties your result.

### Failure mode 2 — a `NULL` in the *column*

```sql
SELECT count(*) FROM products WHERE supplier_id IN (1, 2);        --  9
SELECT count(*) FROM products WHERE supplier_id NOT IN (1, 2);    -- 15
SELECT count(*) FROM products;                                    -- 25
```

9 + 15 = 24, not 25. The missing row is `Webcam HD`, whose `supplier_id` is
`NULL`. It is neither "in" nor "not in" the list — the comparison is `UNKNOWN`
both ways.

Exactly the Day 9 partition failure, wearing a different hat.

### The two safe alternatives

**1. `IS DISTINCT FROM`** — for a small, known list:

```sql
SELECT count(*) FROM products
WHERE supplier_id IS DISTINCT FROM 1
  AND supplier_id IS DISTINCT FROM 2;      -- 16 (includes the NULL row)
```

**2. Add the `IS NULL` branch explicitly:**

```sql
SELECT count(*) FROM products
WHERE supplier_id NOT IN (1, 2) OR supplier_id IS NULL;   -- 16
```

**3. (From Day 38) `NOT EXISTS`** — the standard answer once subqueries exist.
`NOT EXISTS` is immune to this entire class of bug, which is why experienced
engineers reach for it reflexively.

🎯 **Interview** — "What's wrong with `WHERE id NOT IN (SELECT parent_id FROM
t)`?" The expected answer: if any `parent_id` is NULL the query returns zero
rows, silently. The fix is `NOT EXISTS`, or adding `WHERE parent_id IS NOT
NULL` to the subquery. Being able to explain *why* — via the three-valued truth
table — is what separates a memorised answer from an understood one.

> **Working rule:** `IN` is safe. `NOT IN` is safe **only** when you can
> guarantee no NULLs on either side. When in doubt, use `NOT EXISTS`.

---

## Part 4 — `BETWEEN`

```sql
SELECT product_name, price
FROM   products
WHERE  price BETWEEN 100 AND 500;
```

Seven rows. Exactly equivalent to:

```sql
WHERE price >= 100 AND price <= 500
```

**`BETWEEN` is inclusive at both ends.** Say that out loud. It is the source of
every `BETWEEN` bug.

```sql
SELECT first_name, salary
FROM   employees
WHERE  salary BETWEEN 40000 AND 60000;              -- 5 rows

SELECT order_id, order_date
FROM   orders
WHERE  order_date BETWEEN DATE '2024-01-01' AND DATE '2024-12-31';   -- 52 rows
```

`NOT BETWEEN` inverts it:

```sql
SELECT product_name, price
FROM   products
WHERE  price NOT BETWEEN 100 AND 500;               -- 18 rows
```

7 + 18 = 25 ✓ — safe here because `price` is `NOT NULL`. On a nullable column
the same split would leak rows, for the reason you now know well.

⚠️ **Trap** — the bounds must be `(low, high)` in that order:

```sql
SELECT count(*) FROM products WHERE price BETWEEN 500 AND 100;
```

```
 count
-------
     0
```

Zero rows, no error. `BETWEEN 500 AND 100` expands to `price >= 500 AND price
<= 100`, which nothing satisfies. Reversed bounds are a silent zero.

---

## Part 5 — ⚠️ `BETWEEN` and timestamps: the half-open range rule

This is the most commercially damaging trap in this phase.

`orders.order_date` is a `date`, so this is fine:

```sql
WHERE order_date BETWEEN DATE '2024-01-01' AND DATE '2024-12-31'
```

But `payments.paid_at` is a **`timestamptz`** — it has a time component. And:

```sql
SELECT count(*) FROM payments
WHERE paid_at BETWEEN '2024-01-01' AND '2024-12-31';
```

This means `paid_at <= '2024-12-31 00:00:00'`. **Every payment made during the
day of 31 December is excluded** — up to 24 hours of transactions silently
missing from your year-end report.

Demonstrate it:

```sql
SELECT count(*) FROM payments
WHERE paid_at BETWEEN '2024-12-01' AND '2024-12-31';

SELECT count(*) FROM payments
WHERE paid_at >= '2024-12-01' AND paid_at < '2025-01-01';
```

Run both. The second is larger — the December payments made after midnight on
the 31st (orders 51 and 52) appear only in the second.

### The rule

> **For any column with a time component, use a half-open range:
> `>= start AND < next_start`.** Never `BETWEEN`.

```sql
-- December 2024
WHERE paid_at >= '2024-12-01' AND paid_at < '2025-01-01'

-- a single day
WHERE paid_at >= '2024-12-31' AND paid_at < '2025-01-01'

-- the whole of 2024
WHERE paid_at >= '2024-01-01' AND paid_at < '2025-01-01'
```

Half-open ranges have three virtues:

1. **No gaps and no overlaps.** Consecutive months tile the timeline exactly.
2. **No dependence on precision.** Whether your timestamps hold seconds,
   microseconds, or someday nanoseconds, `< '2025-01-01'` is still correct.
   `<= '2024-12-31 23:59:59'` breaks the moment a payment lands at
   `23:59:59.5`.
3. **Index-friendly.** A range scan on a B-tree index works perfectly
   (Day 74).

💡 **Note** — the same convention appears all over computing: Python slices,
C++ iterators, HTTP byte ranges. Half-open intervals compose; closed intervals
don't.

🎯 **Interview** — "How do you filter a timestamp column for a single month?"
If the candidate writes `BETWEEN '2024-12-01' AND '2024-12-31'`, they have just
lost a day of data. The expected answer is the half-open range, and ideally the
reasoning about precision.

---

## Part 6 — `IN` on more than one column

PostgreSQL lets you compare **row values**:

```sql
SELECT order_id, product_id, quantity
FROM   order_items
WHERE  (order_id, product_id) IN ((1, 7), (2, 1), (30, 9));
```

Three rows — one per pair. This is genuinely useful when you have a list of
composite keys to look up, and it is far cleaner than

```sql
WHERE (order_id = 1 AND product_id = 7)
   OR (order_id = 2 AND product_id = 1)
   OR (order_id = 30 AND product_id = 9)
```

Row comparison also works with ordering operators, which is the foundation of
**keyset pagination**:

```sql
SELECT * FROM products
WHERE  (category_id, product_id) > (9, 18)
ORDER  BY category_id, product_id
LIMIT  5;
```

This means "the rows that come after (9, 18) in that sort order" — compared
lexicographically, left to right. It is the efficient replacement for deep
`OFFSET`, and you'll build it properly on Day 74.

---

## Part 7 — Combining today's tools

```sql
SELECT product_name, price, category_id, stock_quantity
FROM   products
WHERE  category_id IN (1, 9, 10)
  AND  price BETWEEN 30 AND 200
  AND  stock_quantity > 0
  AND  NOT is_discontinued
ORDER  BY price DESC;
```

```sql
SELECT first_name, last_name, country, loyalty_tier
FROM   customers
WHERE  country IN ('Germany', 'France', 'UK', 'Italy', 'Spain')
  AND  (loyalty_tier IN ('gold', 'platinum') OR loyalty_tier IS NULL)
  AND  is_active
ORDER  BY country, last_name;
```

Note the `OR loyalty_tier IS NULL` — deliberately including the customers whose
tier was never recorded. That is a *decision*, made explicitly, and it is what
Day 9 trained you to notice.

---

## Traps & Gotchas

| # | Trap | What happens |
|---|---|---|
| 1 | `NOT IN` with a `NULL` in the list | **Zero rows.** Silently. |
| 2 | `NOT IN` on a nullable column | Rows with NULL are excluded from both `IN` and `NOT IN` |
| 3 | `BETWEEN` on a timestamp | Loses up to a day of data at the upper bound |
| 4 | `BETWEEN high AND low` | Zero rows, no error |
| 5 | Forgetting `BETWEEN` is inclusive | Off-by-one at both ends |
| 6 | Enormous `IN` lists from application code | Plan-cache churn; use a join or `= ANY(array)` |
| 7 | `IN ()` with an empty list | Syntax error in Postgres. Use `= ANY(ARRAY[]::int[])`. |
| 8 | Assuming `IN` is faster than `OR` | Identical plans. `IN` is for readability. |

---

## Interview angles

- **Junior** — "Products in categories 3, 4 or 9." → `WHERE category_id IN (3,4,9)`
- **Junior** — "Is `BETWEEN` inclusive?" → Yes, both ends.
- **Mid** — "Why might `NOT IN (SELECT ...)` return nothing?" → A NULL in the
  subquery result makes every comparison `UNKNOWN`.
- **Mid** — "Filter a `timestamptz` column for March 2025." →
  `>= '2025-03-01' AND < '2025-04-01'`.
- **Mid** — "`IN` vs `EXISTS` vs a join?" → For a literal list, `IN`. For a
  subquery, `EXISTS` is NULL-safe and often better with correlated conditions;
  the planner frequently converts all three into a semi-join anyway. Day 38.
- **Senior** — "An ORM generates `IN` lists with 5,000 elements. Concerns?" →
  Query-plan cache pollution (every distinct arity is a distinct query),
  parse/plan time, statement-size limits, and the planner falling back to poor
  estimates. Better: pass a single array parameter and use
  `= ANY($1)`, or `JOIN` against a temporary table / `VALUES` list.

---

## Practice

> Available: everything from Days 1–9, plus `IN`, `NOT IN`, `BETWEEN`,
> `NOT BETWEEN`, `= ANY(ARRAY[...])`, row comparison.
> Not yet available: `LIKE`, `COALESCE`, `CASE`, subqueries.

### Section A — Drill (new concept only)

1. Products in category 3 or 4, using `IN`.
2. Products in categories 1, 9 or 10.
3. Products **not** in categories 3, 4 or 6.
4. Customers from Germany, France or India.
5. Customers **not** from Germany or USA.
6. Customers with `gold` or `platinum` tier.
7. Employees in Support or Warehouse.
8. Employees **not** in Sales or Management.
9. Orders that are cancelled or returned.
10. Orders that are **not** pending, paid or shipped.
11. Payments made by card or paypal.
12. Payments **not** made by card.
13. Reviews with a rating of 4 or 5.
14. Reviews with a rating **not** 4 or 5.
15. Products with `product_id` in 1, 5, 10, 15, 20.
16. Products priced between 100 and 500 inclusive.
17. Products priced between 40 and 100 inclusive.
18. Products **not** priced between 100 and 500.
19. Employees earning between 40000 and 60000.
20. Employees **not** earning between 40000 and 60000.
21. Customers who signed up between 2023-01-01 and 2023-12-31.
22. Orders placed between 2024-06-01 and 2024-08-31.
23. Order items with quantity between 2 and 3.
24. Products with stock between 1 and 20.
25. Reviews with helpful votes between 20 and 50.
26. Products in categories 3 or 4, written with `= ANY (ARRAY[...])`.
27. Order items whose `(order_id, product_id)` pair is `(1,7)`, `(2,1)` or
    `(30,9)`.
28. Count products where `price BETWEEN 500 AND 100`. Explain the result.
29. Count products where `supplier_id IN (1,2)` and where
    `supplier_id NOT IN (1,2)`. Do they sum to 25?
30. Count products where `category_id NOT IN (3, 4, NULL)`. Explain.

### Section B — Combination (with Days 01–09)

31. In-stock, non-discontinued products in categories 1, 9 or 10, priced
    between 30 and 200, most expensive first.
32. Active customers from Germany, France, UK, Italy or Spain, ordered by
    country then last name.
33. Sales or Support employees earning between 40000 and 80000, highest paid
    first.
34. Delivered or shipped orders placed between 2024-07-01 and 2024-12-31,
    with a shipping cost above 0.
35. Reviews with rating 4 or 5 and helpful votes between 20 and 60, best rating
    first.
36. Products in categories 3, 4 or 7 that have a supplier, showing the margin,
    best margin first.
37. Products **not** in categories 9 or 10, including any with a NULL category.
    (There are none — but write it so it would work if there were.)
38. Customers whose tier is `gold` or `platinum`, **or** who have no tier at
    all.
39. Products not supplied by suppliers 1 or 2, **including** the one with no
    supplier. How many rows?
40. Employees whose commission is not 0.040 or 0.045, including those with no
    commission.
41. The 5 most expensive products in categories 1, 3 or 4.
42. Distinct countries among customers in the `bronze` or `silver` tiers.
43. Distinct shipping countries for orders placed between 2024-01-01 and
    2024-06-30.
44. The most expensive product in each of categories 1, 6 and 9
    (`DISTINCT ON`).
45. Count of payments in December 2024 using `BETWEEN`, and again using a
    half-open range. Which is larger and by how many?
46. Count of payments in 2024 using a half-open range.
47. Order items whose line total is between 100 and 500, largest first.
48. Products whose stock value is between 1000 and 10000, showing the value.
49. Customers who signed up in 2024 **or** 2025, using one `BETWEEN`.
50. Employees hired between 2019-01-01 and 2022-12-31 who are in Sales or
    Support, showing full name, department and hire date, oldest hire first.

### Section C — Recall (Days 01–09)

51. Customers with no city.
52. `NULL = NULL` — what does it return?
53. Products where `supplier_id IS DISTINCT FROM 4`.
54. `NOT (city = 'Berlin')` — how many rows, and why not 22?
55. Employees with no manager.
56. Distinct loyalty tiers — how many rows and why?
57. The 3 cheapest in-stock products.
58. Concatenate name and country for customers with no phone.
59. `true OR NULL` and `false AND NULL`.
60. Reset the database and verify the nine counts.

### Section D — Challenge

61. Demonstrate the `NOT IN` + `NULL` failure with a one-line query using
    literals only, then explain it with the truth table.
62. Write three queries whose counts sum to exactly 25, proving that
    `supplier_id IN (1,2)`, `supplier_id NOT IN (1,2)` and
    `supplier_id IS NULL` partition `products`.
63. Rewrite `WHERE supplier_id NOT IN (1, 2)` two different ways so that the
    NULL-supplier product is included. Confirm both return 16.
64. Show, with two counts, that `BETWEEN` loses data on `payments.paid_at` for
    December 2024. State exactly which payments are lost and why.
65. Write a query for "all payments in 2024" that stays correct if the column
    is later changed from `timestamptz` to a higher-precision type.
66. `WHERE price BETWEEN 100 AND 500` returns 7 rows and
    `WHERE price NOT BETWEEN 100 AND 500` returns 18. They sum to 25. Under
    what change to the schema would that stop being true?
67. Using row comparison, find all products that come after `(9, 18)` in
    `(category_id, product_id)` order. Then explain why this is **not** the same
    as `WHERE category_id >= 9 AND product_id > 18`.
68. An application builds `WHERE id IN (...)` by string concatenation, and the
    list can be empty. `WHERE id IN ()` is a syntax error. Write a form that
    works for both an empty and a non-empty list, passing a single array.
69. You must exclude a list of product ids read from a nullable column in
    another system. You cannot guarantee it is NULL-free, and you cannot use
    subqueries yet. Write the safest `WHERE` clause you can with today's tools,
    and state what you would use instead on Day 38.
70. Without running it, predict the row count of each, then check:
    ```sql
    SELECT count(*) FROM customers WHERE loyalty_tier IN ('gold','platinum');
    SELECT count(*) FROM customers WHERE loyalty_tier NOT IN ('gold','platinum');
    SELECT count(*) FROM customers WHERE loyalty_tier IS NULL;
    ```

---

## Solutions

### Section A

**1.** `SELECT * FROM products WHERE category_id IN (3, 4);` → 6
**2.** `... IN (1, 9, 10);` → 13
**3.** `... NOT IN (3, 4, 6);` → 16 (25 − 3 − 3 − 3)
**4.** `SELECT * FROM customers WHERE country IN ('Germany','France','India');` → 8
**5.** `... NOT IN ('Germany','USA');` → 19
**6.** `... WHERE loyalty_tier IN ('gold','platinum');` → 7
**7.** `SELECT * FROM employees WHERE department IN ('Support','Warehouse');` → 6
**8.** `... NOT IN ('Sales','Management');` → 6
**9.** `SELECT * FROM orders WHERE status IN ('cancelled','returned');` → 5
**10.** `... NOT IN ('pending','paid','shipped');` → 52
**11.** `SELECT * FROM payments WHERE method IN ('card','paypal');`
**12.** `SELECT * FROM payments WHERE method NOT IN ('card');`
**13.** `SELECT * FROM reviews WHERE rating IN (4, 5);` → 28
**14.** `SELECT * FROM reviews WHERE rating NOT IN (4, 5);` → 8
**15.** `SELECT * FROM products WHERE product_id IN (1,5,10,15,20);` → 5
**16.** `... WHERE price BETWEEN 100 AND 500;` → 7
**17.** `... WHERE price BETWEEN 40 AND 100;` → 8
**18.** `... WHERE price NOT BETWEEN 100 AND 500;` → 18
**19.** `SELECT * FROM employees WHERE salary BETWEEN 40000 AND 60000;` → 5
**20.** `... NOT BETWEEN 40000 AND 60000;` → 7
**21.** `SELECT * FROM customers WHERE signup_date BETWEEN DATE '2023-01-01' AND DATE '2023-12-31';` → 9
**22.** `SELECT * FROM orders WHERE order_date BETWEEN DATE '2024-06-01' AND DATE '2024-08-31';`
**23.** `SELECT * FROM order_items WHERE quantity BETWEEN 2 AND 3;` → 17
**24.** `SELECT * FROM products WHERE stock_quantity BETWEEN 1 AND 20;` → 5
(Laptop Pro 14 12, Smartphone Mini 20, Coffee Maker 18, Office Chair 10,
Standing Desk 5).
**25.** `SELECT * FROM reviews WHERE helpful_votes BETWEEN 20 AND 50;`
**26.** `SELECT * FROM products WHERE category_id = ANY (ARRAY[3, 4]);` → 6
**27.**
```sql
SELECT * FROM order_items
WHERE (order_id, product_id) IN ((1,7), (2,1), (30,9));
```
→ 3 rows.
**28.** `SELECT count(*) FROM products WHERE price BETWEEN 500 AND 100;` → **0**.
Expands to `price >= 500 AND price <= 100`, which is unsatisfiable. Reversed
bounds give a silent zero, never an error.
**29.** `IN (1,2)` → 9; `NOT IN (1,2)` → 15. **9 + 15 = 24, not 25.** The
missing row is `Webcam HD`, `supplier_id IS NULL`.
**30.** `SELECT count(*) FROM products WHERE category_id NOT IN (3, 4, NULL);`
→ **0**. The `NULL` in the list makes every comparison `UNKNOWN`, so no row is
ever `TRUE`.

### Section B

**31.**
```sql
SELECT product_name, price, category_id, stock_quantity
FROM   products
WHERE  category_id IN (1, 9, 10)
  AND  price BETWEEN 30 AND 200
  AND  stock_quantity > 0
  AND  NOT is_discontinued
ORDER  BY price DESC;
```
**32.**
```sql
SELECT first_name, last_name, country
FROM   customers
WHERE  is_active
  AND  country IN ('Germany','France','UK','Italy','Spain')
ORDER  BY country, last_name;
```
**33.**
```sql
SELECT first_name, department, salary
FROM   employees
WHERE  department IN ('Sales','Support')
  AND  salary BETWEEN 40000 AND 80000
ORDER  BY salary DESC;
```
**34.**
```sql
SELECT order_id, status, order_date, shipping_cost
FROM   orders
WHERE  status IN ('delivered','shipped')
  AND  order_date BETWEEN DATE '2024-07-01' AND DATE '2024-12-31'
  AND  shipping_cost > 0
ORDER  BY order_date;
```
**35.**
```sql
SELECT * FROM reviews
WHERE  rating IN (4,5) AND helpful_votes BETWEEN 20 AND 60
ORDER  BY rating DESC, helpful_votes DESC;
```
**36.**
```sql
SELECT product_name, price - cost AS margin
FROM   products
WHERE  category_id IN (3,4,7) AND supplier_id IS NOT NULL
ORDER  BY margin DESC;
```
**37.**
```sql
SELECT * FROM products
WHERE  category_id NOT IN (9,10) OR category_id IS NULL;
```
→ 16 rows. There are no NULL categories, so the `OR` branch adds nothing today
— but writing it is the habit that keeps the query correct when the data
changes.
**38.**
```sql
SELECT first_name, loyalty_tier FROM customers
WHERE  loyalty_tier IN ('gold','platinum') OR loyalty_tier IS NULL;
```
→ 11 rows (7 + 4).
**39.**
```sql
SELECT * FROM products
WHERE  supplier_id NOT IN (1,2) OR supplier_id IS NULL;   -- 16
```
**40.**
```sql
SELECT * FROM employees
WHERE  commission_pct NOT IN (0.040, 0.045) OR commission_pct IS NULL;
```
→ 9 rows (12 − Lucia, Omar, Tom).
**41.**
```sql
SELECT product_name, price FROM products
WHERE  category_id IN (1,3,4) ORDER BY price DESC LIMIT 5;
```
**42.**
```sql
SELECT DISTINCT country FROM customers
WHERE  loyalty_tier IN ('bronze','silver') ORDER BY country;
```
**43.**
```sql
SELECT DISTINCT shipping_country FROM orders
WHERE  order_date BETWEEN DATE '2024-01-01' AND DATE '2024-06-30'
ORDER  BY shipping_country;
```
**44.**
```sql
SELECT DISTINCT ON (category_id) category_id, product_name, price
FROM   products WHERE category_id IN (1,6,9)
ORDER  BY category_id, price DESC;
```
**45.**
```sql
SELECT count(*) FROM payments WHERE paid_at BETWEEN '2024-12-01' AND '2024-12-31';
SELECT count(*) FROM payments WHERE paid_at >= '2024-12-01' AND paid_at < '2025-01-01';
```
The half-open version is larger. Run both and note the difference — the extra
rows are payments timestamped after midnight on 31 December.
**46.** `SELECT count(*) FROM payments WHERE paid_at >= '2024-01-01' AND paid_at < '2025-01-01';`
**47.**
```sql
SELECT order_id, product_id,
       quantity * unit_price * (1 - discount_pct) AS line_total
FROM   order_items
WHERE  quantity * unit_price * (1 - discount_pct) BETWEEN 100 AND 500
ORDER  BY line_total DESC;
```
**48.**
```sql
SELECT product_name, price * stock_quantity AS stock_value
FROM   products
WHERE  price * stock_quantity BETWEEN 1000 AND 10000
ORDER  BY stock_value DESC;
```
**49.** `SELECT * FROM customers WHERE signup_date BETWEEN DATE '2024-01-01' AND DATE '2025-12-31';` → 12
**50.**
```sql
SELECT first_name || ' ' || last_name AS full_name, department, hire_date
FROM   employees
WHERE  hire_date BETWEEN DATE '2019-01-01' AND DATE '2022-12-31'
  AND  department IN ('Sales','Support')
ORDER  BY hire_date;
```

### Section C

**51.** `SELECT * FROM customers WHERE city IS NULL;` → 2
**52.** `NULL`
**53.** `SELECT * FROM products WHERE supplier_id IS DISTINCT FROM 4;` → 21
**54.** 20. The two NULL-city rows give `UNKNOWN`, and `NOT UNKNOWN` is still
`UNKNOWN`, so they are discarded.
**55.** `SELECT * FROM employees WHERE manager_id IS NULL;` → 1
**56.** 5 — four tiers plus one row for `NULL`. `DISTINCT` treats NULLs as equal
to each other.
**57.** `SELECT product_name, price FROM products WHERE stock_quantity > 0 ORDER BY price LIMIT 3;`
**58.** `SELECT first_name || ' ' || last_name || ' (' || country || ')' FROM customers WHERE phone IS NULL;`
**59.** `t` and `f`
**60.** `\i 99_reset.sql`

### Section D

**61.**
```sql
SELECT 1 WHERE 5 NOT IN (1, 2, NULL);   -- 0 rows
```
```
5 NOT IN (1,2,NULL)
  ≡ NOT (5=1 OR 5=2 OR 5=NULL)
  ≡ NOT (FALSE OR FALSE OR UNKNOWN)
  ≡ NOT UNKNOWN                          ← because FALSE OR UNKNOWN = UNKNOWN
  ≡ UNKNOWN                              ← because NOT UNKNOWN = UNKNOWN
```
`WHERE` keeps only `TRUE`, so nothing survives. The deciding cell is
`FALSE OR UNKNOWN = UNKNOWN`.

**62.**
```sql
SELECT count(*) FROM products WHERE supplier_id IN (1,2);      --  9
SELECT count(*) FROM products WHERE supplier_id NOT IN (1,2);  -- 15
SELECT count(*) FROM products WHERE supplier_id IS NULL;       --  1
```
9 + 15 + 1 = 25 ✓

**63.**
```sql
-- A
SELECT count(*) FROM products WHERE supplier_id NOT IN (1,2) OR supplier_id IS NULL;
-- B
SELECT count(*) FROM products
WHERE supplier_id IS DISTINCT FROM 1 AND supplier_id IS DISTINCT FROM 2;
```
Both → 16.

**64.**
```sql
SELECT count(*) FROM payments WHERE paid_at BETWEEN '2024-12-01' AND '2024-12-31';
SELECT count(*) FROM payments WHERE paid_at >= '2024-12-01' AND paid_at < '2025-01-01';
```
`BETWEEN` upper bound `'2024-12-31'` is coerced to the **timestamp**
`2024-12-31 00:00:00+00`, so any payment stamped later that day is excluded.
Inspect the boundary directly:
```sql
SELECT payment_id, order_id, paid_at FROM payments
WHERE paid_at >= '2024-12-31' AND paid_at < '2025-01-01';
```
Those are exactly the rows `BETWEEN` loses.

**65.**
```sql
SELECT count(*) FROM payments
WHERE paid_at >= TIMESTAMPTZ '2024-01-01 00:00:00+00'
  AND paid_at <  TIMESTAMPTZ '2025-01-01 00:00:00+00';
```
The half-open upper bound has no dependence on the column's precision. Writing
`<= '2024-12-31 23:59:59'` would break for a value of
`23:59:59.500`; `<= '2024-12-31 23:59:59.999999'` would break if the type
gained nanoseconds. `< next_start` never breaks.

**66.** It would stop being true the moment `price` became nullable. A row with
`price IS NULL` satisfies neither `BETWEEN` nor `NOT BETWEEN` — both evaluate to
`UNKNOWN`. `price` is currently `NOT NULL`, which is why the arithmetic works.

**67.**
```sql
SELECT category_id, product_id, product_name
FROM   products
WHERE  (category_id, product_id) > (9, 18)
ORDER  BY category_id, product_id;
```
Row comparison is **lexicographic**: it returns rows where `category_id > 9`,
**or** where `category_id = 9` and `product_id > 18`.

`WHERE category_id >= 9 AND product_id > 18` is different — it would also
return, say, `(10, 25)` correctly but would *exclude* `(10, 7)`, which should be
included because category 10 comes entirely after category 9 regardless of
product id. The two conditions are independent in the `AND` version and coupled
in the row-comparison version, and only the coupled one implements "comes after
in this sort order". That is precisely why keyset pagination uses row
comparison.

**68.**
```sql
SELECT * FROM products WHERE product_id = ANY ($1);
```
with `$1` bound to an integer array. An empty array yields zero rows — correct,
and no syntax error. To test it inline:
```sql
SELECT count(*) FROM products WHERE product_id = ANY (ARRAY[]::integer[]);  -- 0
SELECT count(*) FROM products WHERE product_id = ANY (ARRAY[1,2,3]);        -- 3
```
This also collapses every list length into **one** cached plan instead of one
per arity — a real benefit at scale.

**69.** With today's tools, the safest form combines both guards:
```sql
SELECT * FROM products
WHERE  (product_id NOT IN (3, 7, 11) OR product_id IS NULL)
  AND  product_id IS NOT NULL;   -- if you also want to drop unknown ids
```
…but the honest answer is that a literal list you *typed* can be guaranteed
NULL-free, while a list from another system cannot be, and no `WHERE` clause can
fix a `NULL` you didn't filter out at the source.

From Day 38 the correct form is:
```sql
SELECT * FROM products p
WHERE  NOT EXISTS (
         SELECT 1 FROM excluded_ids e WHERE e.product_id = p.product_id
       );
```
`NOT EXISTS` is immune, because it asks "did the subquery produce any row?" —
a question with only two possible answers, never `UNKNOWN`.

**70.** 7, 13, 4. They sum to 24 ✓ — but only because the three branches are
`IN`, `NOT IN` and `IS NULL`. Drop the third and you have 20 of 24 customers,
which is the Day 9 lesson restated in Day 10's vocabulary. Predicting `7, 17`
for the first two is the natural wrong answer; the four tier-less customers are
in neither.

---

## Day 10 Checklist

- [ ] I can replace a chain of `OR`s with `IN`
- [ ] I know `NOT IN` expands to `AND`s of `<>`
- [ ] **I know `NOT IN` with a NULL anywhere returns zero rows, and why**
- [ ] I know `NOT IN` on a nullable column loses the NULL rows
- [ ] I can name two safe alternatives to `NOT IN` today, and the third (Day 38)
- [ ] I know `BETWEEN` is inclusive at both ends
- [ ] I know `BETWEEN high AND low` returns zero rows silently
- [ ] **I use half-open ranges (`>= start AND < next_start`) for timestamps**
- [ ] I can explain the three virtues of half-open ranges
- [ ] I can use `= ANY(ARRAY[...])` and say why an application would prefer it
- [ ] I can use row comparison `(a, b) > (x, y)` and explain its lexicographic
      meaning

---

## What's next

**Day 11 — `LIKE`, `ILIKE` and pattern matching.** Searching inside text:
wildcards, case-insensitive matching, escaping, and a first look at regular
expressions. It is also the day you meet the phrase "this query cannot use an
index", which becomes a recurring theme from Phase 9 onwards.
