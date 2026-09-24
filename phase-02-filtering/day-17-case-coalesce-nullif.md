# Day 17 — `CASE`, `COALESCE`, `NULLIF`, `GREATEST` and `LEAST`

> **Phase** 2 · Filtering & Expressions
> **Level** Absolute Beginner
> **Time** 110–140 minutes
> **Prerequisites** Days 01–16
> **New concepts** `CASE` (searched and simple) · `ELSE` and the implicit `NULL` · nested `CASE` · `CASE` in `ORDER BY` and `WHERE` · `COALESCE` · `NULLIF` · division-by-zero guard · `GREATEST` / `LEAST` and their NULL behaviour · boolean-to-integer casting

---

## Why this matters

This is the day the loose ends tie up.

Since Day 4 you have been unable to write "show the city, or `unknown` if there
isn't one". Since Day 14 you have known that a division can abort your whole
query. Since Day 7 you have been able to *compute* a boolean but not to turn it
into a label.

`CASE` and `COALESCE` fix all three, and they are the two most-used expressions
in reporting SQL after the aggregates you meet on Day 19.

---

## Part 1 — `CASE`: if/then/else inside a query

### Searched `CASE` — the general form

```sql
SELECT product_name,
       price,
       CASE
           WHEN price >= 1000 THEN 'premium'
           WHEN price >= 300  THEN 'mid-range'
           WHEN price >= 50   THEN 'budget'
           ELSE                    'accessory'
       END AS price_band
FROM   products
ORDER  BY price DESC;
```

```
             product_name             |  price  | price_band
--------------------------------------+---------+------------
 Laptop Pro 14                        | 1899.00 | premium
 Laptop Air 13                        | 1099.00 | premium
 Smartphone X                         |  999.00 | mid-range
 Smartphone Mini                      |  699.00 | mid-range
 Budget Laptop 15                     |  549.00 | mid-range
 Standing Desk                        |  499.00 | mid-range
 Tablet 10                            |  429.00 | mid-range
 Old Phone 2020                       |  299.00 | budget
 ...
 Wireless Mouse                       |   29.99 | accessory
```

The structure:

```sql
CASE
    WHEN <condition> THEN <value>
    WHEN <condition> THEN <value>
    ELSE <value>
END
```

Three rules that matter:

1. **Conditions are evaluated top to bottom, and the first `TRUE` wins.** Order
   is significant — put the most specific condition first.
2. **`ELSE` is optional.** If you omit it and nothing matches, the result is
   `NULL`. This is the most common `CASE` bug.
3. **All branches must return compatible types.** You cannot return `'premium'`
   in one branch and `42` in another.

⚠️ **Trap — order matters.** Reverse the bands above and everything collapses:

```sql
CASE
    WHEN price >= 50   THEN 'budget'      -- matches almost everything first
    WHEN price >= 1000 THEN 'premium'     -- unreachable
    ...
END
```

A €1899 laptop is `>= 50`, so it is labelled `budget` and the `premium` branch
is never reached. No error. A perfectly plausible, entirely wrong report.

⚠️ **Trap — the missing `ELSE`.**

```sql
SELECT product_name,
       CASE WHEN price > 100 THEN 'expensive' END AS label
FROM   products;
```

Products at or below €100 get `NULL`, not `'cheap'`. Then someone concatenates
that column and the whole string disappears (Day 4). **Write an explicit `ELSE`
every time**, even if it is `ELSE NULL` — it documents that you thought about
it.

### Simple `CASE` — comparing one expression to values

```sql
SELECT order_id,
       status,
       CASE status
           WHEN 'pending'   THEN 'Awaiting payment'
           WHEN 'paid'      THEN 'Payment received'
           WHEN 'shipped'   THEN 'On its way'
           WHEN 'delivered' THEN 'Complete'
           WHEN 'cancelled' THEN 'Cancelled by customer'
           WHEN 'returned'  THEN 'Returned'
           ELSE                  'Unknown status'
       END AS status_label
FROM   orders
LIMIT  5;
```

Shorter when you're testing one expression against a list of values. It uses
`=` internally — which means:

⚠️ **Trap — simple `CASE` cannot match `NULL`:**

```sql
SELECT CASE NULL WHEN NULL THEN 'matched' ELSE 'not matched' END;
```

```
 not matched
```

Because `NULL = NULL` is `UNKNOWN`, not `TRUE` (Day 9). To handle `NULL` you
must use the searched form:

```sql
SELECT CASE WHEN x IS NULL THEN 'missing' ELSE 'present' END ...
```

### `CASE` everywhere

`CASE` is an **expression**, so it works anywhere a value works.

**In `ORDER BY`** — custom sort orders:

```sql
SELECT order_id, status
FROM   orders
ORDER  BY CASE status
              WHEN 'pending'   THEN 1
              WHEN 'paid'      THEN 2
              WHEN 'shipped'   THEN 3
              WHEN 'delivered' THEN 4
              WHEN 'returned'  THEN 5
              WHEN 'cancelled' THEN 6
          END,
          order_id;
```

Statuses now sort in **workflow order**, not alphabetically. This is one of the
most useful `CASE` applications and it comes up constantly in real reporting.

**In `WHERE`:**

```sql
SELECT product_name, price, stock_quantity
FROM   products
WHERE  CASE WHEN is_discontinued THEN price < 100
            ELSE                      stock_quantity > 0
       END;
```

*"Discontinued products only if they're cheap; everything else only if in
stock."* Legal, occasionally necessary — but usually a sign that plain
`AND`/`OR` would read better. Use it when the branching genuinely differs per
row.

**Nested:**

```sql
SELECT product_name, price, stock_quantity,
       CASE
           WHEN stock_quantity = 0 THEN 'out of stock'
           WHEN price > 500 THEN
                CASE WHEN stock_quantity < 20 THEN 'premium - low stock'
                     ELSE                          'premium - available'
                END
           ELSE 'standard'
       END AS shelf_status
FROM   products;
```

Readable to two levels. Beyond that, reach for a lookup table (Day 27) — deeply
nested `CASE` is how reporting SQL becomes unmaintainable.

### `CASE` as a division guard

Remember Day 8: you cannot rely on `WHERE` running before `SELECT`. `CASE`
**does** guarantee evaluation order — a branch is only evaluated if its
condition is true:

```sql
SELECT product_name,
       CASE WHEN cost = 0 THEN NULL
            ELSE (price - cost) / cost
       END AS markup
FROM   products;
```

This is safe. The division never runs when `cost` is zero.

💡 The caveat: PostgreSQL may still evaluate constant sub-expressions early
during planning. For column-dependent conditions like the one above, the
guarantee holds.

---

## Part 2 — `COALESCE`: the first non-NULL

```sql
SELECT COALESCE(NULL, NULL, 'third', 'fourth');   -- 'third'
```

`COALESCE(a, b, c, …)` returns the **first argument that is not NULL**. It takes
any number of arguments and stops as soon as it finds one.

**The problem you have carried since Day 4, solved:**

```sql
SELECT first_name,
       city,
       COALESCE(city, 'unknown')                    AS city_display,
       first_name || ' lives in ' || COALESCE(city, 'an unknown city') AS sentence
FROM   customers
WHERE  city IS NULL;
```

```
 first_name | city | city_display |            sentence
------------+------+--------------+---------------------------------
 Marie      | ␀    | unknown      | Marie lives in an unknown city
 Nina       | ␀    | unknown      | Nina lives in an unknown city
```

No more vanishing rows.

### Where you'll use it constantly

```sql
-- substitute zero for a missing number
SELECT first_name, COALESCE(commission_pct, 0) AS commission_pct FROM employees;

-- a fallback chain: phone, then email, then a placeholder
SELECT first_name, COALESCE(phone, email, 'no contact') AS contact FROM customers;

-- a default label
SELECT first_name, COALESCE(loyalty_tier, 'none') AS tier FROM customers;

-- arithmetic that doesn't collapse to NULL
SELECT first_name, salary * COALESCE(commission_pct, 0) AS commission FROM employees;
```

That last one is the pattern to internalise. Without `COALESCE`, seven
employees get `NULL` commission (Day 9); with it, they correctly get `0.00`.

### `COALESCE` vs `concat_ws`

Both solve NULL-in-a-string problems, differently:

```sql
SELECT concat_ws(', ', first_name, city)              AS ws,      -- drops the field
       first_name || ', ' || COALESCE(city, 'n/a')    AS coalesce -- substitutes
FROM   customers WHERE city IS NULL;
```

```
   ws    |  coalesce
---------+------------
 Marie   | Marie, n/a
 Nina    | Nina, n/a
```

**`concat_ws` omits; `COALESCE` substitutes.** Choose based on whether the
reader should see that something is missing.

### Two things to know

**All arguments must share a common type:**

```sql
SELECT COALESCE(NULL::integer, 'text');
```

```
ERROR:  invalid input syntax for type integer: "text"
```

**`COALESCE` short-circuits.** Later arguments are not evaluated once a non-NULL
is found — which matters if a later argument is expensive or could error.

⚠️ **Trap — `COALESCE` does not treat `''` as missing:**

```sql
SELECT COALESCE('', 'fallback');   -- '' — the empty string IS a value
```

If your data has a mix of `NULL` and `''`, you need
`COALESCE(NULLIF(col, ''), 'fallback')` — which brings us neatly to the next
function.

---

## Part 3 — `NULLIF`: the inverse

```sql
SELECT NULLIF(5, 5),     -- NULL   (they're equal)
       NULLIF(5, 0),     -- 5      (not equal → return the first)
       NULLIF('', '');   -- NULL
```

`NULLIF(a, b)` returns `NULL` if `a = b`, otherwise returns `a`. It is
`COALESCE` in reverse: `COALESCE` turns NULL into a value; `NULLIF` turns a
value into NULL.

### Use 1 — the division guard (the important one)

```sql
SELECT product_name,
       price,
       cost,
       round((price - cost) / NULLIF(cost, 0), 4) AS markup
FROM   products;
```

If `cost` is 0, `NULLIF(cost, 0)` is `NULL`, and `x / NULL` is `NULL` — a blank
cell instead of an aborted query.

**This is the idiom.** It is shorter than the `CASE` equivalent, everyone reads
it instantly, and you will write it hundreds of times:

```sql
anything / NULLIF(denominator, 0)
```

Compare the two safe forms:

```sql
-- CASE version: explicit, verbose
CASE WHEN cost = 0 THEN NULL ELSE (price - cost) / cost END

-- NULLIF version: idiomatic
(price - cost) / NULLIF(cost, 0)
```

Both are correct. Ship the second.

### Use 2 — normalising empty strings

```sql
SELECT COALESCE(NULLIF(city, ''), 'unknown') FROM customers;
```

Treats both `NULL` and `''` as missing. Essential when data arrives from web
forms, where an untouched text box submits `''`.

### Use 3 — suppressing a sentinel value

```sql
SELECT NULLIF(shipping_country, 'Unknown') FROM orders;
```

Turns a magic "Unknown" string back into a real `NULL` so that downstream NULL
handling works.

---

## Part 4 — `GREATEST` and `LEAST`

```sql
SELECT GREATEST(3, 7, 2),      -- 7
       LEAST(3, 7, 2);         -- 2
```

These compare **values across columns in the same row** — not across rows. (That
is `MAX`/`MIN`, which are aggregates and arrive on Day 19. Confusing the two is
a very common beginner error.)

```sql
-- clamp a discount to a maximum of 20%
SELECT order_id, discount_pct, LEAST(discount_pct, 0.20) AS capped FROM order_items;

-- never show a negative margin
SELECT product_name, GREATEST(price - cost, 0) AS margin FROM products;

-- the later of two dates
SELECT GREATEST(DATE '2024-01-01', DATE '2024-06-15');   -- 2024-06-15

-- clamp into a range: at least 10, at most 100
SELECT LEAST(GREATEST(value, 10), 100) ...
```

⚠️ **Trap — `GREATEST`/`LEAST` ignore NULLs (unlike most of SQL):**

```sql
SELECT GREATEST(1, NULL, 3),   -- 3   ← NULL is skipped
       LEAST(1, NULL, 3);      -- 1
```

Almost everything else in SQL propagates NULL. These two do not — they skip
NULL arguments and only return `NULL` if **every** argument is NULL.

This is convenient but inconsistent, and it is a favourite interview question
precisely because it contradicts the rule you spent Day 9 learning.

🎯 **Interview** — "What does `GREATEST(1, NULL, 3)` return?" → `3`. Then:
"And `1 + NULL`?" → `NULL`. Then: "Why the difference?" → `GREATEST`/`LEAST`
are defined by the standard to ignore NULLs; arithmetic and comparison operators
propagate them. (Note: in **MySQL** `GREATEST` *does* return NULL — another
cross-database trap.)

---

## Part 5 — Boolean to integer: the counting trick

```sql
SELECT true::int, false::int, NULL::boolean::int;   -- 1, 0, NULL
```

Casting a boolean to an integer gives 1 or 0, which lets you **count conditions
without aggregates**:

```sql
SELECT first_name,
       last_name,
       (city IS NULL)::int
     + (phone IS NULL)::int
     + (birth_date IS NULL)::int
     + (loyalty_tier IS NULL)::int AS missing_fields
FROM   customers
ORDER  BY missing_fields DESC, last_name;
```

```
 first_name | last_name | missing_fields
------------+-----------+----------------
 Nina       | Petrova   |              3
 Marie      | Dubois    |              2
 Hannah     | Schmidt   |              2
 Daniel     | Kim       |              2
 ...
```

A data-quality report in five lines. The same trick with `CASE` is the
foundation of **conditional aggregation**, which is Day 22 and one of the most
powerful reporting techniques in SQL:

```sql
-- a preview of Day 22
SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END)
```

---

## Part 6 — Putting it all together

```sql
SELECT product_name,
       price,
       CASE
           WHEN price >= 1000 THEN 'premium'
           WHEN price >= 300  THEN 'mid-range'
           WHEN price >= 50   THEN 'budget'
           ELSE                    'accessory'
       END                                              AS band,
       COALESCE(supplier_id::text, 'no supplier')       AS supplier,
       round((price - cost) / NULLIF(price, 0) * 100, 1) AS margin_pct,
       GREATEST(price - cost, 0)                        AS margin_floor,
       CASE WHEN stock_quantity = 0 THEN 'restock'
            WHEN stock_quantity < 20 THEN 'low'
            ELSE 'ok'
       END                                              AS stock_status
FROM   products
WHERE  NOT is_discontinued
ORDER  BY CASE WHEN stock_quantity = 0 THEN 0 ELSE 1 END,   -- out of stock first
          price DESC;
```

Every technique from today, on one screen. Read it once more and notice that
none of it is *filtering* — it is all *shaping*. That distinction, `WHERE`
versus `SELECT`, has been the spine of Phase 2.

---

## Traps & Gotchas

| # | Trap | What happens |
|---|---|---|
| 1 | `CASE` branches in the wrong order | The broad condition matches first; later branches unreachable |
| 2 | Omitting `ELSE` | Unmatched rows get `NULL`, silently |
| 3 | Simple `CASE x WHEN NULL` | Never matches — use `WHEN x IS NULL` in the searched form |
| 4 | Mixed types across branches | Type error, or a surprising implicit cast |
| 5 | `COALESCE('', 'x')` | Returns `''` — empty string is a value |
| 6 | `COALESCE` with incompatible types | Error |
| 7 | `GREATEST(1, NULL, 3)` | Returns 3 — NULLs ignored, unlike everything else |
| 8 | Confusing `GREATEST` with `MAX` | Across columns vs across rows |
| 9 | Deeply nested `CASE` | Unmaintainable — use a lookup table |
| 10 | Forgetting `NULLIF` on a denominator | `division by zero` aborts the statement |
| 11 | `CASE` in `WHERE` where `AND`/`OR` would do | Harder to read, harder to index |

---

## Interview angles

- **Junior** — "Label products as cheap/medium/expensive." → searched `CASE`
  with correctly ordered branches and an explicit `ELSE`.
- **Junior** — "Show 0 instead of NULL." → `COALESCE(col, 0)`.
- **Mid** — "Avoid division by zero." → `x / NULLIF(y, 0)`.
- **Mid** — "Sort by a custom status order." → `ORDER BY CASE status WHEN …`.
- **Mid** — "`COALESCE` vs `NULLIF`?" → Inverses: first non-NULL vs
  value-to-NULL. They compose: `COALESCE(NULLIF(col, ''), 'default')`.
- **Mid** — "`GREATEST` vs `MAX`?" → Row-wise across columns vs aggregate
  across rows.
- **Senior** — "A status column is compared against a 40-branch `CASE` in
  twelve different queries. Fix it." → The mapping is data, not logic: put it in
  a lookup table with a foreign key, join to it, and the labels become
  editable without a deploy. If the labels are presentation-only, they may not
  belong in SQL at all. Mention that a `CASE` repeated across queries is
  duplicated business logic that *will* drift.
- **Senior** — "Does `CASE` guarantee evaluation order?" → Yes for the
  branches, which is why it is a valid guard against errors; but constant
  sub-expressions can still be folded during planning, so don't rely on it to
  suppress an error in a constant expression.

---

## Practice

> Available: everything from Days 1–16, plus `CASE`, `COALESCE`, `NULLIF`,
> `GREATEST`, `LEAST`, boolean casting.

### Section A — Drill (new concept only)

1. `CASE WHEN 1 = 1 THEN 'yes' ELSE 'no' END`.
2. `CASE WHEN 1 = 2 THEN 'yes' END` — what do you get and why?
3. Label every product `premium` (≥1000), `mid-range` (≥300), `budget` (≥50) or
   `accessory`.
4. Write the same `CASE` with the branches in the wrong order and report what
   happens.
5. Label every customer `active` or `inactive` from `is_active`.
6. Label every product `in stock` or `out of stock`.
7. Label every employee `commissioned` or `salaried` based on `commission_pct`.
8. Use a **simple** `CASE` to turn `orders.status` into friendly labels.
9. `CASE NULL WHEN NULL THEN 'matched' ELSE 'not matched' END`. Explain.
10. Rewrite 9 using a searched `CASE` so that it correctly reports `matched`.
11. Label reviews `positive` (4–5), `neutral` (3) or `negative` (1–2).
12. Label orders `complete`, `in progress` or `failed` from their status.
13. `COALESCE(NULL, NULL, 'third')`.
14. Every customer's city, or `'unknown'`.
15. Every customer's loyalty tier, or `'none'`.
16. Every employee's commission percentage, or `0`.
17. Every customer's contact: phone, else email, else `'no contact'`.
18. Every product's supplier id as text, or `'no supplier'`.
19. `COALESCE('', 'fallback')` — explain.
20. `COALESCE(NULLIF('', ''), 'fallback')` — explain.
21. `NULLIF(5, 5)` and `NULLIF(5, 0)`.
22. Every product's markup `(price - cost) / cost`, guarded against zero cost.
23. Every product's margin percentage, guarded against zero price.
24. `GREATEST(3, 7, 2)` and `LEAST(3, 7, 2)`.
25. `GREATEST(1, NULL, 3)` and `LEAST(1, NULL, 3)`. Explain.
26. Every order item's discount capped at 5%.
27. Every product's margin, floored at 0.
28. `true::int`, `false::int`.
29. Every customer's count of missing fields among city, phone, birth_date and
    loyalty_tier.
30. `LEAST(GREATEST(150, 10), 100)` — what does this compute?

### Section B — Combination (with Days 01–16)

31. Every product with its price band, ordered by price descending.
32. Every product with its price band and stock status, out-of-stock first.
33. Every customer's full name and city, substituting `'unknown'`, using
    `concat_ws` as well so that nothing is lost.
34. Every employee's name, salary, commission percentage (0 if none) and
    computed commission amount to 2 decimals.
35. Every employee's total compensation: `salary + salary * COALESCE(commission_pct, 0)`,
    to 2 decimals, highest first.
36. Every product's margin percentage, guarded, rounded to 1 decimal, best
    first.
37. Orders sorted in workflow order (`pending`, `paid`, `shipped`, `delivered`,
    `returned`, `cancelled`), then by date.
38. Every order labelled `recent` (2025) or `historic` (2024), using its date.
39. Every customer labelled by signup year using `EXTRACT` inside a `CASE`.
40. Every customer's age band at 2025-01-01: `under 30`, `30-45`, `over 45`, or
    `unknown` when `birth_date` is NULL.
41. Every product's name and a display price: the price, or `'discontinued'`
    when `is_discontinued` — note the type problem and solve it.
42. Every order item's line total, and a flag `discounted` / `full price`.
43. Every payment labelled `large` (>1000), `medium` (>200) or `small`.
44. Every review's rating as stars, e.g. `*****`, using `repeat`.
45. Every customer's contact preference: `phone` if they have one, else
    `email`.
46. Every product's stock cover in weeks (stock / 7), guarded so a zero-stock
    product shows 0 rather than causing trouble.
47. Every employee's department, with `Management` renamed to `Exec` and
    everything else unchanged.
48. Every order's shipping cost, or the text `'free'` when it is zero.
49. Every product's name padded to 40 characters and its band, so the output
    lines up.
50. Every customer's data-completeness score out of 4, with a label:
    `complete` (4), `partial` (2–3), `sparse` (0–1).
51. Distinct price bands present in `products`.
52. Products whose band is `premium` or `mid-range`, using a `CASE` in the
    `WHERE` clause — then rewrite it without `CASE` and say which you'd ship.
53. Every payment's amount and its amount net of a 2.9% + €0.30 fee, floored at
    0.
54. Every order's date formatted as `Mon YYYY`, with a `CASE` labelling
    quarters `Q1`–`Q4`.
55. Every product's price compared to 500: `above`, `below` or `exactly 500`.

### Section C — Recall (Days 01–16)

56. `DATE '2024-01-31' + INTERVAL '1 month'`.
57. The last day of the month containing `2024-02-10`.
58. Every payment's `paid_at` in Berlin local time.
59. Orders placed in 2025, using a half-open range.
60. `round(2.5::numeric)` versus `round(2.5::float8)`.
61. Every customer's email domain.
62. `concat_ws('-', 'a', NULL, 'b')`.
63. Customers with no phone, using `IS NULL`.
64. `supplier_id NOT IN (1, 2)` — why 15 rows?
65. Reset the database and verify the counts.

### Section D — Challenge

66. Write a `CASE` with the branches deliberately in the wrong order, show the
    wrong output, then fix it — and state the rule in one sentence.
67. Show that omitting `ELSE` produces `NULL`, then show the knock-on effect
    when that column is concatenated.
68. Show that a **simple** `CASE` cannot match `NULL`, and write the searched
    equivalent that can.
69. Write a query proving that `GREATEST` ignores NULLs while `+` propagates
    them, in one row.
70. Write the markup calculation `(price - cost) / cost` three ways — unguarded,
    guarded with `CASE`, guarded with `NULLIF` — and say which you would ship.
71. Someone writes `WHERE cost > 0` and claims it protects
    `SELECT (price-cost)/cost`. Explain why that is not a guarantee, referring
    to Day 8.
72. Build a complete "customer health" report: full name, country, city
    (substituted), tier (substituted), age band, data-completeness score and a
    label, sorted worst-completeness first.
73. Every product's price band **and** the count of how many products would
    share that band — without using `GROUP BY`. (Hint: you can't, properly.
    Attempt it, then write one sentence on what Day 20 will give you.)
74. Rewrite this deliberately awful expression to be readable:
    ```sql
    CASE WHEN a THEN CASE WHEN b THEN 'x' ELSE CASE WHEN c THEN 'y'
    ELSE 'z' END END ELSE CASE WHEN b THEN 'p' ELSE 'q' END END
    ```
    using `products`: `a` = `NOT is_discontinued`, `b` = `stock_quantity > 0`,
    `c` = `price > 100`.
75. Design question: `orders.status` has six values, each needing a
    human-readable label, a sort position and a colour for the UI. A colleague
    proposes a 6-branch `CASE` in each of nine queries. Argue for a better
    design and say what you would build.

---

## Solutions

### Section A

**1.** `SELECT CASE WHEN 1 = 1 THEN 'yes' ELSE 'no' END;` → `yes`
**2.** `SELECT CASE WHEN 1 = 2 THEN 'yes' END;` → `NULL`. No branch matched and
there is no `ELSE`, so the implicit result is `NULL`.
**3.**
```sql
SELECT product_name, price,
       CASE WHEN price >= 1000 THEN 'premium'
            WHEN price >= 300  THEN 'mid-range'
            WHEN price >= 50   THEN 'budget'
            ELSE                    'accessory'
       END AS band
FROM   products ORDER BY price DESC;
```
**4.**
```sql
SELECT product_name, price,
       CASE WHEN price >= 50   THEN 'budget'
            WHEN price >= 300  THEN 'mid-range'
            WHEN price >= 1000 THEN 'premium'
            ELSE                    'accessory'
       END AS band
FROM   products ORDER BY price DESC;
```
Every product over €50 is labelled `budget`, including the €1899 laptop. The
later branches are unreachable. No error is raised.
**5.** `SELECT first_name, CASE WHEN is_active THEN 'active' ELSE 'inactive' END FROM customers;`
**6.** `SELECT product_name, CASE WHEN stock_quantity > 0 THEN 'in stock' ELSE 'out of stock' END FROM products;`
**7.** `SELECT first_name, CASE WHEN commission_pct IS NULL THEN 'salaried' ELSE 'commissioned' END FROM employees;`
**8.**
```sql
SELECT order_id, status,
       CASE status
           WHEN 'pending'   THEN 'Awaiting payment'
           WHEN 'paid'      THEN 'Payment received'
           WHEN 'shipped'   THEN 'On its way'
           WHEN 'delivered' THEN 'Complete'
           WHEN 'cancelled' THEN 'Cancelled'
           WHEN 'returned'  THEN 'Returned'
           ELSE                  'Unknown'
       END AS label
FROM   orders;
```
**9.** `not matched`. Simple `CASE` uses `=`, and `NULL = NULL` is `UNKNOWN`,
not `TRUE`.
**10.** `SELECT CASE WHEN NULL IS NULL THEN 'matched' ELSE 'not matched' END;` → `matched`
**11.**
```sql
SELECT review_id, rating,
       CASE WHEN rating >= 4 THEN 'positive'
            WHEN rating = 3  THEN 'neutral'
            ELSE                  'negative'
       END AS sentiment
FROM   reviews;
```
**12.**
```sql
SELECT order_id, status,
       CASE WHEN status = 'delivered' THEN 'complete'
            WHEN status IN ('cancelled','returned') THEN 'failed'
            ELSE 'in progress'
       END AS phase
FROM   orders;
```
**13.** `third`
**14.** `SELECT first_name, COALESCE(city, 'unknown') FROM customers;`
**15.** `SELECT first_name, COALESCE(loyalty_tier, 'none') FROM customers;`
**16.** `SELECT first_name, COALESCE(commission_pct, 0) FROM employees;`
**17.** `SELECT first_name, COALESCE(phone, email, 'no contact') FROM customers;`
**18.** `SELECT product_name, COALESCE(supplier_id::text, 'no supplier') FROM products;`
**19.** `''`. The empty string is a value, not NULL, so `COALESCE` returns it.
**20.** `fallback`. `NULLIF('','')` converts the empty string to NULL first, and
then `COALESCE` substitutes.
**21.** `NULL` and `5`.
**22.** `SELECT product_name, round((price - cost) / NULLIF(cost, 0), 4) AS markup FROM products;`
**23.** `SELECT product_name, round((price - cost) / NULLIF(price, 0) * 100, 1) AS margin_pct FROM products;`
**24.** `7` and `2`.
**25.** `3` and `1`. `GREATEST`/`LEAST` **skip** NULL arguments — unlike
arithmetic and comparison, which propagate them.
**26.** `SELECT order_id, discount_pct, LEAST(discount_pct, 0.05) AS capped FROM order_items;`
**27.** `SELECT product_name, GREATEST(price - cost, 0) AS margin FROM products;`
**28.** `1`, `0`
**29.**
```sql
SELECT first_name, last_name,
       (city IS NULL)::int + (phone IS NULL)::int
     + (birth_date IS NULL)::int + (loyalty_tier IS NULL)::int AS missing
FROM   customers ORDER BY missing DESC;
```
→ Nina Petrova has 3 (city, phone, tier).
**30.** `100`. `GREATEST(150,10)` is 150, then `LEAST(150,100)` is 100 — a
**clamp** into the range [10, 100].

### Section B

**31.** As A3.
**32.**
```sql
SELECT product_name, price, stock_quantity,
       CASE WHEN price >= 1000 THEN 'premium'
            WHEN price >= 300  THEN 'mid-range'
            WHEN price >= 50   THEN 'budget'
            ELSE                    'accessory' END AS band,
       CASE WHEN stock_quantity = 0  THEN 'out of stock'
            WHEN stock_quantity < 20 THEN 'low'
            ELSE                          'ok' END  AS stock_status
FROM   products
ORDER  BY CASE WHEN stock_quantity = 0 THEN 0 ELSE 1 END, price DESC;
```
**33.**
```sql
SELECT concat_ws(' ', first_name, last_name)        AS full_name,
       COALESCE(city, 'unknown')                    AS city_display,
       concat_ws(', ', first_name || ' ' || last_name, city) AS omitted_style
FROM   customers;
```
**34.**
```sql
SELECT first_name, salary,
       COALESCE(commission_pct, 0)                        AS commission_pct,
       round(salary * COALESCE(commission_pct, 0), 2)     AS commission
FROM   employees;
```
**35.**
```sql
SELECT first_name,
       round(salary + salary * COALESCE(commission_pct, 0), 2) AS total_comp
FROM   employees ORDER BY total_comp DESC;
```
**36.** As A23, with `ORDER BY margin_pct DESC`.
**37.**
```sql
SELECT order_id, status, order_date
FROM   orders
ORDER  BY CASE status
              WHEN 'pending' THEN 1 WHEN 'paid' THEN 2 WHEN 'shipped' THEN 3
              WHEN 'delivered' THEN 4 WHEN 'returned' THEN 5 WHEN 'cancelled' THEN 6
          END,
          order_date;
```
**38.**
```sql
SELECT order_id, order_date,
       CASE WHEN order_date >= DATE '2025-01-01' THEN 'recent' ELSE 'historic' END AS era
FROM   orders;
```
**39.**
```sql
SELECT first_name, signup_date,
       CASE EXTRACT(YEAR FROM signup_date)::int
           WHEN 2022 THEN 'early adopter'
           WHEN 2023 THEN 'established'
           WHEN 2024 THEN 'recent'
           ELSE           'new'
       END AS cohort
FROM   customers;
```
**40.**
```sql
SELECT first_name, birth_date,
       CASE WHEN birth_date IS NULL THEN 'unknown'
            WHEN EXTRACT(YEAR FROM age(DATE '2025-01-01', birth_date)) < 30 THEN 'under 30'
            WHEN EXTRACT(YEAR FROM age(DATE '2025-01-01', birth_date)) <= 45 THEN '30-45'
            ELSE 'over 45'
       END AS age_band
FROM   customers;
```
Note the NULL branch comes **first** — otherwise the comparison yields `UNKNOWN`
and the row falls through to `ELSE`, silently labelling a customer with no
birth date as `over 45`.
**41.**
```sql
SELECT product_name,
       CASE WHEN is_discontinued THEN 'discontinued'
            ELSE price::text
       END AS display_price
FROM   products;
```
The type problem: one branch returns `text`, the other `numeric`. All branches
must agree, so cast the numeric one to `text`. Without the cast:
`ERROR: CASE types text and numeric cannot be matched`.
**42.**
```sql
SELECT order_id, product_id,
       round(quantity * unit_price * (1 - discount_pct), 2) AS line_total,
       CASE WHEN discount_pct > 0 THEN 'discounted' ELSE 'full price' END AS pricing
FROM   order_items;
```
**43.**
```sql
SELECT payment_id, amount,
       CASE WHEN amount > 1000 THEN 'large'
            WHEN amount > 200  THEN 'medium'
            ELSE                    'small' END AS size
FROM   payments;
```
**44.** `SELECT review_id, rating, repeat('*', rating) AS stars FROM reviews;`
**45.**
```sql
SELECT first_name,
       CASE WHEN phone IS NOT NULL THEN 'phone' ELSE 'email' END AS contact_pref
FROM   customers;
```
**46.**
```sql
SELECT product_name, stock_quantity,
       COALESCE(round(stock_quantity::numeric / NULLIF(7, 0), 1), 0) AS weeks
FROM   products;
```
(The divisor here is a constant 7, so `NULLIF` is theatre — the honest answer is
that no guard is needed. Recognising when a guard is unnecessary is part of the
exercise.)
**47.**
```sql
SELECT first_name, department,
       CASE department WHEN 'Management' THEN 'Exec' ELSE department END AS dept
FROM   employees;
```
**48.**
```sql
SELECT order_id,
       CASE WHEN shipping_cost = 0 THEN 'free' ELSE shipping_cost::text END AS shipping
FROM   orders;
```
**49.**
```sql
SELECT rpad(product_name, 40, ' ') ||
       CASE WHEN price >= 1000 THEN 'premium'
            WHEN price >= 300  THEN 'mid-range'
            WHEN price >= 50   THEN 'budget'
            ELSE                    'accessory' END AS line
FROM   products ORDER BY price DESC;
```
**50.**
```sql
SELECT first_name, last_name,
       4 - ((city IS NULL)::int + (phone IS NULL)::int
          + (birth_date IS NULL)::int + (loyalty_tier IS NULL)::int) AS score,
       CASE 4 - ((city IS NULL)::int + (phone IS NULL)::int
               + (birth_date IS NULL)::int + (loyalty_tier IS NULL)::int)
           WHEN 4 THEN 'complete'
           WHEN 3 THEN 'partial'
           WHEN 2 THEN 'partial'
           ELSE        'sparse'
       END AS completeness
FROM   customers
ORDER  BY score;
```
Repeating that expression three times is horrible. A CTE (Day 41) lets you name
it once — this problem exists to make you feel that pain.
**51.**
```sql
SELECT DISTINCT CASE WHEN price >= 1000 THEN 'premium'
                     WHEN price >= 300  THEN 'mid-range'
                     WHEN price >= 50   THEN 'budget'
                     ELSE                    'accessory' END AS band
FROM   products;
```
**52.**
```sql
-- with CASE
SELECT product_name, price FROM products
WHERE  CASE WHEN price >= 1000 THEN 'premium'
            WHEN price >= 300  THEN 'mid-range'
            WHEN price >= 50   THEN 'budget'
            ELSE                    'accessory' END IN ('premium','mid-range');

-- without
SELECT product_name, price FROM products WHERE price >= 300;
```
**Ship the second.** It is shorter, obviously correct, and *sargable* — an index
on `price` can be used, whereas the `CASE` version must be computed for every
row. When a `CASE` in `WHERE` reduces to a simple range, simplify it.
**53.**
```sql
SELECT payment_id, amount,
       GREATEST(round(amount - (amount * 0.029 + 0.30), 2), 0) AS net
FROM   payments;
```
**54.**
```sql
SELECT order_id, to_char(order_date, 'FMMon YYYY') AS month,
       'Q' || EXTRACT(QUARTER FROM order_date)::int AS quarter
FROM   orders;
```
**55.**
```sql
SELECT product_name, price,
       CASE WHEN price > 500 THEN 'above'
            WHEN price < 500 THEN 'below'
            ELSE                  'exactly 500' END AS vs_500
FROM   products;
```

### Section C

**56.** `2024-02-29`
**57.** `SELECT (date_trunc('month', DATE '2024-02-10') + INTERVAL '1 month - 1 day')::date;` → `2024-02-29`
**58.** `SELECT paid_at AT TIME ZONE 'Europe/Berlin' FROM payments;`
**59.** `WHERE order_date >= DATE '2025-01-01' AND order_date < DATE '2026-01-01';`
**60.** `3` and `2`.
**61.** `SELECT split_part(email, '@', 2) FROM customers;`
**62.** `a-b`
**63.** `WHERE phone IS NULL;` → 5
**64.** `Webcam HD` has a NULL supplier, so it satisfies neither `IN` nor
`NOT IN`.
**65.** `\i 99_reset.sql`

### Section D

**66.** See A4. **The rule: order `CASE` branches from most specific to least
specific**, because the first `TRUE` wins and later branches become
unreachable.

**67.**
```sql
SELECT product_name,
       CASE WHEN price > 100 THEN 'expensive' END          AS label,
       'Product is ' || CASE WHEN price > 100 THEN 'expensive' END AS sentence
FROM   products ORDER BY price;
```
Cheap products get `NULL` in `label`, and the `sentence` column is `NULL`
entirely — the known prefix `'Product is '` is destroyed too. One missing
`ELSE` propagates into a blank cell three columns later.

**68.**
```sql
SELECT CASE NULL WHEN NULL THEN 'matched' ELSE 'not matched' END AS simple_form,
       CASE WHEN NULL IS NULL THEN 'matched' ELSE 'not matched' END AS searched_form;
```
→ `not matched`, `matched`. Simple `CASE` compares with `=`; `NULL = NULL` is
`UNKNOWN`, so no branch is taken.

**69.**
```sql
SELECT GREATEST(1, NULL, 3) AS greatest_ignores_null,
       LEAST(1, NULL, 3)    AS least_ignores_null,
       1 + NULL             AS arithmetic_propagates,
       (1 = NULL)           AS comparison_propagates;
```
→ `3`, `1`, `NULL`, `NULL`. `GREATEST`/`LEAST` are the exception to the rule
you learned on Day 9. (And note MySQL disagrees — there, `GREATEST(1,NULL,3)`
is `NULL`.)

**70.**
```sql
SELECT product_name,
       (price - cost) / cost                                      AS unguarded,
       CASE WHEN cost = 0 THEN NULL ELSE (price - cost) / cost END AS case_guard,
       (price - cost) / NULLIF(cost, 0)                            AS nullif_guard
FROM   products;
```
All three work here because no product has zero cost. Insert one and the first
column aborts the entire query.

**Ship the `NULLIF` version.** It is the shortest, it is a recognised idiom that
any reviewer reads instantly, and it composes — you can wrap the whole thing in
`COALESCE(..., 0)` if a zero is more useful than a blank.

**71.** SQL is declarative: the planner is free to evaluate `SELECT`
expressions and `WHERE` conditions in any order, and to reorder the conditions
among themselves by estimated cost (Day 8, Part 7). There is no guarantee that
`cost > 0` is checked before the division is computed. A plan change — after an
`ANALYZE`, a data-distribution shift, or an index being added — can flip the
order and start raising `division by zero` on a query that worked for years.

The guard must be *inside the expression* (`NULLIF` or `CASE`), where evaluation
order is defined. This is one of the clearest practical consequences of SQL
being declarative rather than procedural.

**72.**
```sql
SELECT concat_ws(' ', first_name, last_name)                AS full_name,
       country,
       COALESCE(city, 'unknown')                            AS city,
       COALESCE(loyalty_tier, 'none')                       AS tier,
       CASE WHEN birth_date IS NULL THEN 'unknown'
            WHEN EXTRACT(YEAR FROM age(DATE '2025-01-01', birth_date)) < 30 THEN 'under 30'
            WHEN EXTRACT(YEAR FROM age(DATE '2025-01-01', birth_date)) <= 45 THEN '30-45'
            ELSE 'over 45' END                              AS age_band,
       4 - ((city IS NULL)::int + (phone IS NULL)::int
          + (birth_date IS NULL)::int + (loyalty_tier IS NULL)::int) AS completeness,
       CASE WHEN (city IS NULL)::int + (phone IS NULL)::int
               + (birth_date IS NULL)::int + (loyalty_tier IS NULL)::int = 0
            THEN 'complete'
            WHEN (city IS NULL)::int + (phone IS NULL)::int
               + (birth_date IS NULL)::int + (loyalty_tier IS NULL)::int <= 2
            THEN 'partial'
            ELSE 'sparse' END                               AS health
FROM   customers
ORDER  BY completeness, last_name;
```
Note how much duplication this needs. Keep this query — on Day 41 you will
rewrite it with a CTE and it will shrink by half. That before-and-after is one
of the more satisfying moments in the program.

**73.** You cannot do it properly with today's tools. A window function
(`count(*) OVER (PARTITION BY band)`) is Day 46, and `GROUP BY` is Day 20.

What you *can* do is produce the band per row and count by eye:
```sql
SELECT DISTINCT CASE WHEN price >= 1000 THEN 'premium'
                     WHEN price >= 300  THEN 'mid-range'
                     WHEN price >= 50   THEN 'budget'
                     ELSE                    'accessory' END AS band
FROM   products;
```
**Day 20 gives you `GROUP BY`**, which collapses rows into one per band with a
`count(*)` — turning "list the rows" into "summarise the rows", and it is the
single biggest jump in expressive power in the whole program.

**74.**
```sql
SELECT product_name, is_discontinued, stock_quantity, price,
       CASE
           WHEN is_discontinued AND stock_quantity > 0 THEN 'p'
           WHEN is_discontinued                        THEN 'q'
           WHEN stock_quantity > 0                     THEN 'x'
           WHEN price > 100                            THEN 'y'
           ELSE                                             'z'
       END AS label
FROM   products;
```
The nested version branches on `a`, then on `b`, then on `c` — but every path
ends in a single label, so the whole thing flattens into one searched `CASE`
with five ordered conditions. **Flattening nested `CASE` into an ordered
searched `CASE` is almost always possible and almost always clearer.** Verify
the rewrite by running both and comparing, row for row.

**75.** **The argument:** a label, a sort position and a colour are *data about
statuses*, not logic. Putting them in a `CASE` means:

- the same mapping is duplicated in nine places and **will** drift — someone
  adds a seventh status and updates six of the nine queries;
- changing a label requires a code deploy;
- there is nothing preventing a typo'd status from being inserted;
- the UI colour is presentation concern leaking into the data layer.

**What I would build:**

```sql
CREATE TABLE order_statuses (
    status       text PRIMARY KEY,
    label        text NOT NULL,
    sort_order   int  NOT NULL,
    colour       text
);

ALTER TABLE orders
    ADD CONSTRAINT orders_status_fkey
    FOREIGN KEY (status) REFERENCES order_statuses (status);
```

Then every query joins to `order_statuses` and orders by `sort_order`. Adding a
status is an `INSERT`, not a deploy. The foreign key makes an invalid status
*impossible to write*, which is stronger than any `CHECK` on a list.

(You'll write exactly this on Days 53–57. The technique of replacing repeated
`CASE` logic with a lookup table is worth remembering now, because you will meet
the 40-branch version of this problem in real code.)

**The honest caveat:** the colour probably belongs in the front-end, not the
database — a design system changes more often than a schema should. Storing a
*semantic* token (`'danger'`, `'success'`) rather than `'#ff0000'` is the
compromise most teams land on.

---

## Day 17 Checklist

- [ ] I can write a searched `CASE` and a simple `CASE`
- [ ] **I order branches most-specific first, and I always write `ELSE`**
- [ ] I know a missing `ELSE` yields `NULL` silently
- [ ] I know a simple `CASE` cannot match `NULL`
- [ ] I can use `CASE` in `SELECT`, `WHERE` and `ORDER BY`
- [ ] I can sort by a custom order with `ORDER BY CASE …`
- [ ] **I use `COALESCE(col, fallback)` to substitute for NULL**
- [ ] I know `COALESCE('', 'x')` returns `''`, and how `NULLIF` fixes it
- [ ] **I guard every division with `NULLIF(denominator, 0)`**
- [ ] I know `GREATEST`/`LEAST` work across columns and ignore NULLs
- [ ] I know `GREATEST` ≠ `MAX`
- [ ] I can cast booleans to integers to count conditions per row

---

## What's next

**Day 18 — ✅ Checkpoint 3.** Eighty problems covering the whole of Phase 2:
filtering, boolean logic, `NULL`, ranges, patterns, strings, numbers, dates and
conditionals. Pass mark 56/80.

After that, Phase 3 changes the shape of everything you know. So far every query
has returned **one output row per input row**. `GROUP BY` breaks that
assumption, and with it comes the ability to answer questions about the data as
a whole rather than row by row.
