# Day 14 — Numeric Types and Math Functions

> **Phase** 2 · Filtering & Expressions
> **Level** Absolute Beginner
> **Time** 110–140 minutes
> **Prerequisites** Days 01–13
> **New concepts** `smallint`/`integer`/`bigint` · `numeric(p,s)` · `real`/`double precision` · integer division · `round`/`ceil`/`floor`/`trunc` · `abs`/`sign`/`mod`/`div` · `power`/`sqrt`/`exp`/`ln`/`log` · `random` · division by zero · overflow · scale propagation · why money is never a float

---

## Why this matters

Two of the most expensive bug classes in commercial software are numeric:

1. **Integer division truncating away money.** `total_cents / 100` quietly
   discards the pennies, and nobody notices until an auditor does.
2. **Floating-point arithmetic on currency.** `0.1 + 0.2 <> 0.3` in binary
   floating point, so a balance that should be zero is `-0.000000000001`, and
   your reconciliation job fails at 3 a.m.

You met the first on Day 2. Today you learn the type system well enough that
neither can happen to you again.

---

## Part 1 — The three families of number

PostgreSQL has three families, and choosing between them is a design decision,
not a detail.

### Integers — whole numbers, exact

| Type | Bytes | Range | Use for |
|---|---|---|---|
| `smallint` (`int2`) | 2 | ±32,767 | rarely worth it |
| `integer` (`int4`) | 4 | ±2,147,483,647 | counts, most ids |
| `bigint` (`int8`) | 8 | ±9.2 × 10¹⁸ | ids at scale, epoch millis |

```sql
SELECT pg_typeof(42), pg_typeof(9000000000);
```

```
 pg_typeof | pg_typeof
-----------+-----------
 integer   | bigint
```

PostgreSQL picks the smallest type that fits the literal.

### `numeric` — exact decimal, arbitrary precision

```sql
numeric(precision, scale)
```

- **precision** = total significant digits
- **scale** = digits after the decimal point

`numeric(10,2)` holds up to 99,999,999.99. That is the type of every money
column in this practice database.

`numeric` with no arguments accepts any precision — useful, but a column
declared that way accepts anything and documents nothing.

```sql
SELECT pg_typeof(1.5), pg_typeof(1.5::numeric(10,2));
```

Both `numeric`. PostgreSQL treats a decimal literal as `numeric` by default,
which is a deliberately safe choice.

💡 `decimal` is an exact synonym for `numeric` in PostgreSQL. Use whichever
your team prefers; they are the same type.

### Floating point — approximate, fast

| Type | Bytes | Precision |
|---|---|---|
| `real` (`float4`) | 4 | ~6 decimal digits |
| `double precision` (`float8`) | 8 | ~15 decimal digits |

Floats are **binary** approximations. They are the right choice for
measurements, scientific data and anything where a rounding error in the
fifteenth digit is irrelevant. They are the **wrong** choice for money.

### The demonstration you should be able to give from memory

```sql
SELECT 0.1 + 0.2 = 0.3                               AS numeric_ok,
       0.1::float8 + 0.2::float8 = 0.3::float8       AS float_broken,
       0.1::float8 + 0.2::float8                     AS what_float_gives;
```

```
 numeric_ok | float_broken |    what_float_gives
------------+--------------+------------------------
 t          | f            | 0.30000000000000004
```

`numeric` is exact and the comparison holds. `float8` is not, and it doesn't.
Three lines, and it settles the "can we just use a double?" argument
permanently.

🎯 **Interview** — "Which type for a money column?" → `numeric(p,s)`, or an
`integer`/`bigint` count of minor units (cents). Never a float. Being able to
demonstrate it in one query is what turns a memorised answer into a credible
one.

### The trade-off, stated honestly

`numeric` is exact but **slow** — it is software arithmetic, roughly 10–100×
slower than hardware floats, and it uses more space. For a table of financial
transactions that is an excellent trade. For a billion sensor readings you are
aggregating, `float8` is the right answer. Know which situation you are in.

---

## Part 2 — Integer division, settled

```sql
SELECT 10 / 3,        -- 3
       10 % 3,        -- 1
       -10 / 3,       -- -3   (truncates TOWARD ZERO, not down)
       -10 % 3;       -- -1
```

**Rule: `integer / integer` → `integer`, truncated toward zero.** Not rounded.
Not floored.

That `-10 / 3 = -3` matters: Python gives `-4` because it floors. SQL truncates.
If you port a formula from Python, check every division.

### The four fixes

```sql
SELECT 10 / 3,                -- 3           wrong
       10.0 / 3,              -- 3.333...    decimal literal
       10::numeric / 3,       -- 3.333...    cast an operand  ← best
       10 / 3.0,              -- 3.333...    other side works too
       (10::numeric / 3)::numeric(10,2);  -- 3.33   cast, divide, then round
```

⚠️ **Trap — casting the result is too late:**

```sql
SELECT (10 / 3)::numeric;     -- 3.0   ← division already happened in integers
SELECT 10::numeric / 3;       -- 3.33… ← correct
```

**Cast the operand, not the result.** This is the single most important line on
today's page.

### Where it bites in this database

`orders.shipping_cost` and `products.price` are `numeric`, so you are safe
there. But:

```sql
SELECT stock_quantity, stock_quantity / 7 AS weeks_of_stock FROM products;
```

`stock_quantity` is `integer`, so `200 / 7` gives `28`, not `28.57`. If that
number drives a reorder decision, you have just under-ordered.

```sql
SELECT stock_quantity, stock_quantity::numeric / 7 AS weeks FROM products;
```

▶ **Try it** — run both and compare the `Wireless Mouse` row.

### `div()` and `mod()`

```sql
SELECT div(10, 3),    -- 3   explicit integer division
       mod(10, 3);    -- 1   same as %
```

`div()` works on `numeric` too and always truncates, which is occasionally
clearer than relying on the type of the operands:

```sql
SELECT div(10.5, 3);  -- 3
SELECT 10.5 / 3;      -- 3.5
```

---

## Part 3 — Rounding

| Function | Does | `round`/`ceil`/`floor`/`trunc` of 2.5 / −2.5 |
|---|---|---|
| `round(n)` | nearest integer, halves **away from zero** | 3 / −3 |
| `round(n, d)` | nearest, to `d` decimal places | — |
| `ceil(n)` / `ceiling(n)` | smallest integer ≥ n | 3 / −2 |
| `floor(n)` | largest integer ≤ n | 2 / −3 |
| `trunc(n)` | drop the fraction, toward zero | 2 / −2 |
| `trunc(n, d)` | truncate to `d` places | — |

```sql
SELECT round(2.5), round(-2.5), ceil(2.1), floor(2.9), trunc(2.9), trunc(-2.9);
```

```
 round | round | ceil | floor | trunc | trunc
-------+-------+------+-------+-------+-------
     3 |    -3 |    3 |     2 |     2 |    -2
```

```sql
SELECT round(3.14159, 2),    -- 3.14
       round(1234.5678, -2), -- 1200   negative digits round to the left
       trunc(3.99, 1);       -- 3.9
```

### ⚠️ The rounding trap that catches everyone

`round()` behaves **differently** for `numeric` and `double precision`:

```sql
SELECT round(0.5::numeric),  round(1.5::numeric),  round(2.5::numeric);   -- 1, 2, 3
SELECT round(0.5::float8),   round(1.5::float8),   round(2.5::float8);    -- 0, 2, 2
```

- `numeric` rounds **half away from zero** — the arithmetic everyone learns at
  school.
- `float8` uses **banker's rounding** (half to even) — `0.5 → 0`, `2.5 → 2`.

Banker's rounding is statistically better for large aggregations and
*completely wrong* for an invoice. One more reason money is `numeric`.

Also: `round(n, d)` with two arguments **only exists for `numeric`**:

```sql
SELECT round(3.14159::float8, 2);
```

```
ERROR:  function round(double precision, integer) does not exist
```

The fix is a cast: `round(3.14159::numeric, 2)`.

### Applied to the practice database

```sql
SELECT order_id,
       product_id,
       quantity * unit_price * (1 - discount_pct)              AS raw_total,
       round(quantity * unit_price * (1 - discount_pct), 2)    AS line_total
FROM   order_items
LIMIT  5;
```

```
 order_id | product_id |  raw_total  | line_total
----------+------------+-------------+------------
        1 |          7 |    59.98000 |      59.98
        1 |          8 |    89.99000 |      89.99
        2 |          1 |  1804.05000 |    1804.05
        2 |          9 |    49.99000 |      49.99
```

Those five trailing decimals you have been seeing since Day 4 finally have a
fix. **Round every money expression at the point of display.**

### Scale propagation — why the extra zeros appear

```sql
SELECT pg_typeof(1.00::numeric(10,2) * 0.050::numeric(4,3));
SELECT 1.00::numeric(10,2) * 0.050::numeric(4,3);    -- 0.05000
```

Multiplying `numeric` values **adds their scales**: 2 + 3 = 5 decimal places.
Division produces even more. The result is exact — it just looks untidy. Round
at the end, never in the middle, or you accumulate rounding error.

> **Rule: compute at full precision, round once, at the last step.**

---

## Part 4 — The rest of the toolkit

```sql
SELECT abs(-42),          -- 42
       sign(-42),         -- -1   (1, 0 or -1)
       power(2, 10),      -- 1024
       2 ^ 10,            -- 1024  (same thing)
       sqrt(144),         -- 12
       cbrt(27),          -- 3
       exp(1),            -- 2.718281828459045
       ln(2.718281828),   -- ~1
       log(100),          -- 2     (base 10)
       log(2, 1024),      -- 10    (base 2)
       pi();              -- 3.141592653589793
```

Random numbers:

```sql
SELECT random();                              -- [0,1)
SELECT floor(random() * 100)::int;            -- integer 0–99
SELECT floor(random() * 100 + 1)::int;        -- integer 1–100
```

```sql
SELECT product_name FROM products ORDER BY random() LIMIT 3;
```

A random sample. Convenient, and **O(n log n)** — it sorts the whole table. Fine
on 25 rows, unusable on 25 million. `TABLESAMPLE` is the scalable answer, and
you'll meet it on Day 80.

### Formatting numbers for display

`to_char()` gives you full control:

```sql
SELECT to_char(1234567.891, 'FM999,999,999.00');   -- '1,234,567.89'
SELECT to_char(0.0725, 'FM990.00%');               -- '0.07%'  — careful
SELECT to_char(42, 'FM0000');                      -- '0042'
```

`FM` ("fill mode") strips the padding spaces that `to_char` otherwise adds.
Forgetting it is why your output has a mysterious leading space. You'll see
`to_char` again on Day 16 for dates.

---

## Part 5 — Errors: division by zero and overflow

### Division by zero raises an error

```sql
SELECT 10 / 0;
```

```
ERROR:  division by zero
```

Not `NULL`, not infinity — a hard error that aborts the statement. Which means
this is a live hazard:

```sql
SELECT product_name, (price - cost) / cost AS markup FROM products;
```

If any product had `cost = 0`, the whole query would fail. None does here, but
you cannot rely on that in general.

The guard is `NULLIF` (Day 17):

```sql
SELECT product_name, (price - cost) / NULLIF(cost, 0) AS markup FROM products;
```

`NULLIF(cost, 0)` returns `NULL` when `cost` is 0, and dividing by `NULL` gives
`NULL` — a missing answer instead of a crashed report. That is almost always the
right trade.

⚠️ And remember Day 8: you **cannot** protect the division by putting
`cost <> 0` in the `WHERE` clause and hoping it runs first. The planner may
evaluate the division first. Use `NULLIF`.

### Overflow also raises an error

```sql
SELECT 2147483647::integer + 1;
```

```
ERROR:  integer out of range
```

PostgreSQL does **not** wrap around silently the way C does. That is a feature:
a loud failure beats a corrupted number.

🎯 **Interview** — "Your `orders.order_id` is an `integer` and the table is
approaching 2 billion rows. What happens and what do you do?" → Inserts start
failing with `integer out of range`. The fix is `ALTER TABLE ... ALTER COLUMN
... TYPE bigint`, which in older versions rewrites the whole table and takes an
`ACCESS EXCLUSIVE` lock — an outage. The real answer is to have used `bigint`
for identity columns from the start; the cost is 4 bytes per row and it removes
an entire category of 3 a.m. incident. Day 56 and Day 62.

---

## Part 6 — Putting it together

```sql
SELECT product_name,
       price,
       cost,
       round(price - cost, 2)                            AS margin,
       round((price - cost) / price * 100, 1)            AS margin_pct,
       round(price * stock_quantity, 2)                  AS stock_value,
       stock_quantity::numeric / 7                       AS weeks_of_stock
FROM   products
WHERE  stock_quantity > 0
  AND  NOT is_discontinued
ORDER  BY margin_pct DESC;
```

Four things worth noting in that query:

1. `round(..., 2)` at the point of display, not in the middle.
2. `(price - cost) / price` is safe because `price` is `NOT NULL` and every
   price is positive — and there is a `CHECK (price >= 0)` on the column, so a
   zero price is *possible*. Strictly you should write
   `NULLIF(price, 0)`. (Day 17.)
3. `stock_quantity::numeric` — casting the operand before dividing.
4. `ORDER BY margin_pct` uses the alias, which is legal because `ORDER BY` runs
   after `SELECT`.

---

## Traps & Gotchas

| # | Trap | What happens |
|---|---|---|
| 1 | `int / int` | Truncates. `10/3 = 3` |
| 2 | `(a / b)::numeric` | Too late — division already truncated |
| 3 | `float` for money | `0.1 + 0.2 <> 0.3` |
| 4 | `round(x, 2)` on a `float8` | Function does not exist — cast to `numeric` |
| 5 | `round` on `float8` | Banker's rounding: `0.5 → 0`, `2.5 → 2` |
| 6 | Rounding intermediate results | Accumulated error. Round once, at the end. |
| 7 | `/ 0` | Hard error, aborts the statement. Use `NULLIF`. |
| 8 | Relying on `WHERE x <> 0` to guard a division | No evaluation-order guarantee |
| 9 | `integer` overflow at 2.1 billion | Error, plus a painful migration |
| 10 | `-10 / 3 = -3` | Truncates toward zero, unlike Python's floor |
| 11 | Trailing zeros after `numeric` multiplication | Expected — scales add |
| 12 | `ORDER BY random()` on a big table | Full sort |

---

## Interview angles

- **Junior** — "Why is `10/3` equal to 3?" → Integer division truncates.
- **Junior** — "Round to two decimals." → `round(x::numeric, 2)`.
- **Mid** — "Which type for currency, and why?" → `numeric`, exact decimal;
  or integer minor units. Demonstrate the float failure.
- **Mid** — "`numeric` vs `bigint` cents?" → `numeric` is self-documenting and
  handles fractional units (FX rates, per-unit pricing); integer cents are
  faster and impossible to mis-round, but every read site must divide by 100
  and the currency's exponent is implicit. Most systems use `numeric`; some
  high-volume ledgers use integers deliberately.
- **Mid** — "Guard against division by zero." → `NULLIF(denominator, 0)`.
- **Senior** — "An `integer` primary key is at 1.9 billion. Plan the fix." →
  Discuss `ALTER TYPE` rewrite cost and lock level, the online alternative
  (add a `bigint` column, backfill in batches, swap with a short lock), logical
  replication to a new table, and the fact that `bigint` should have been the
  default. Day 62.
- **Senior** — "Why is `numeric` slower than `float8`?" → Software arbitrary-
  precision arithmetic versus a hardware FPU instruction, plus variable-length
  storage. Roughly an order of magnitude. Relevant when aggregating billions of
  rows, irrelevant for transactional money.

---

## Practice

> Available: everything from Days 1–13 plus today's numeric functions.

### Section A — Drill (new concept only)

1. `pg_typeof` of `42`, `9000000000`, `1.5` and `1.5::float8`, in one row.
2. `10 / 3` and `10 % 3`.
3. `-10 / 3` and `-10 % 3`. Explain the sign.
4. `10 / 3` as a decimal, three different ways.
5. `(10 / 3)::numeric` — why is it `3.0`?
6. `div(10, 3)` and `mod(10, 3)`.
7. `round(2.5)`, `round(-2.5)`, `round(3.4999)`.
8. `ceil(2.1)`, `floor(2.9)`, `trunc(2.9)`, `trunc(-2.9)`.
9. `round(3.14159, 2)` and `round(3.14159, 4)`.
10. `round(1234.5678, -2)`.
11. `trunc(3.99, 1)`.
12. `round(0.5::numeric)` and `round(0.5::float8)`. Explain.
13. `round(2.5::numeric)` and `round(2.5::float8)`. Explain.
14. `round(3.14159::float8, 2)` — what happens, and how do you fix it?
15. `abs(-42)` and `sign(-42)`.
16. `power(2, 10)` and `2 ^ 10`.
17. `sqrt(144)` and `cbrt(27)`.
18. `log(100)`, `log(2, 1024)` and `ln(exp(1))`.
19. `pi()`.
20. A random number between 0 and 1.
21. A random integer from 1 to 100.
22. `0.1 + 0.2 = 0.3` and the same with `float8` casts.
23. `0.1::float8 + 0.2::float8` — what is the actual value?
24. `2147483647::integer + 1` — what happens?
25. `10 / 0` — what happens?
26. `1.00::numeric(10,2) * 0.050::numeric(4,3)` — how many decimal places, and
    why?
27. `to_char(1234567.891, 'FM999,999,999.00')`.
28. `to_char(42, 'FM0000')`.
29. `to_char(1234.5, '999,999.00')` without `FM` — what's different?
30. Three random products from `products`.

### Section B — Combination (with Days 01–13)

31. Every product's name, price, cost and margin rounded to 2 decimals.
32. Every product's margin percentage, rounded to 1 decimal, best first.
33. Every product's stock value rounded to 2 decimals, highest first.
34. Every product's weeks of stock at 7 units a week, as a decimal to 1 place.
35. Every order item's line total rounded to 2 decimals.
36. Every order item's line total rounded to 2 decimals, where it exceeds 500,
    largest first.
37. Every employee's monthly salary to 2 decimals, highest first.
38. Every employee's commission amount (`salary * commission_pct`) to 2
    decimals — note which rows are blank and why.
39. Every payment's amount and a 2.9% + €0.30 processor fee, to 2 decimals.
40. Every payment's amount net of that fee, to 2 decimals.
41. Every product's price with 19% VAT, to 2 decimals.
42. Every product's price rounded to the nearest 10.
43. Every product's price rounded **down** to the nearest whole euro.
44. Every product's price rounded **up** to the nearest whole euro.
45. Products where the price rounded to the nearest euro differs from the price
    truncated to the nearest euro.
46. Products whose margin percentage exceeds 60%, showing it to 1 decimal.
47. Products whose stock value is between 1000 and 10000, to 2 decimals.
48. Every customer's `customer_id` formatted as `CUST-0001` using `lpad`.
49. Every order's total shipping cost as a percentage of 100 (i.e.
    `shipping_cost / 100 * 100`) — a deliberately silly formula; check the type
    behaviour.
50. Every review's `helpful_votes` as a percentage of the maximum possible 100,
    to 1 decimal.
51. Products grouped by rounded price band — show `floor(price / 100) * 100` as
    `price_band`, sorted.
52. Every product's price per kilogram (`price / weight_kg`) to 2 decimals,
    highest first.
53. Order items where the discount saved more than €50 — show the saving to 2
    decimals.
54. Every employee's salary as a multiple of the lowest salary in the company
    (36500), to 2 decimals.
55. Every product's cost as a percentage of price, to 1 decimal, lowest first.

### Section C — Recall (Days 01–13)

56. Every customer's email domain using `split_part`.
57. Every customer's full name using `concat_ws`, including the city-less ones.
58. Products whose name contains `laptop`, any case.
59. Customers with no phone number.
60. `NOT IN (1, 2, NULL)` on `supplier_id` — count and reason.
61. Payments in September 2024, half-open range.
62. `concat_ws('-', 'a', NULL, 'b')` versus `'a' || NULL || 'b'`.
63. The 3 most expensive in-stock products.
64. Employees whose commission is not 0.040, including those with none.
65. Reset the database and verify the counts.

### Section D — Challenge

66. Demonstrate in one query that `numeric` is exact and `float8` is not, using
    `0.1 + 0.2`.
67. Demonstrate the difference between `numeric` and `float8` rounding for
    `0.5`, `1.5`, `2.5` and `3.5`, in one row each.
68. Show that `(10 / 3)::numeric` and `10::numeric / 3` differ, and explain the
    rule in one sentence.
69. Write a markup calculation `(price - cost) / cost` that cannot fail even if
    a product's cost were zero. (`NULLIF` is Day 17 — try to reason out what it
    must do, then check.)
70. Compute the line total for every order item, rounding **once** at the end,
    and again rounding each factor first. Find an item where the two differ and
    explain why rounding early is wrong.
71. `products.price` has a `CHECK (price >= 0)`. Write the margin-percentage
    query so it is safe against a zero price, and explain why a `WHERE price > 0`
    clause is *not* a reliable guard.
72. `SELECT floor(random() * 100)::int;` gives 0–99 and
    `SELECT round(random() * 100)::int;` gives 0–100. Explain why the second is
    a subtly biased way to pick a number in a range.
73. Work out, without running it, what `SELECT round(2.675, 2);` returns for
    `numeric`, and what it would return for `float8`. Then check. (This exact
    value is a famous floating-point example.)
74. `orders.order_id` is an `integer`. Compute how many more orders could be
    inserted before overflow, using `SHOW`-free pure SQL.
75. Design question: your team stores money as `float8` in an existing table
    with 40 million rows. Write the argument for changing it, name the migration
    risks, and say what you'd do if the change were refused.

---

## Solutions

### Section A

**1.** `SELECT pg_typeof(42), pg_typeof(9000000000), pg_typeof(1.5), pg_typeof(1.5::float8);`
→ `integer`, `bigint`, `numeric`, `double precision`
**2.** `3`, `1`
**3.** `-3`, `-1`. Integer division truncates **toward zero**, so −3.33 becomes
−3 (not −4), and the remainder takes the sign of the dividend.
**4.** `10.0 / 3`, `10::numeric / 3`, `10 / 3.0`
**5.** `3.0`. The division `10 / 3` ran first in integer arithmetic, producing
`3`; the cast then converted `3` to `numeric`. The precision was lost before the
cast existed.
**6.** `3`, `1`
**7.** `3`, `-3`, `3`
**8.** `3`, `2`, `2`, `-2`
**9.** `3.14`, `3.1416`
**10.** `1200`
**11.** `3.9`
**12.** `1` and `0`. `numeric` rounds half away from zero; `float8` uses
banker's rounding (half to even), and 0 is even.
**13.** `3` and `2`. Same reason — 2 is even.
**14.** `ERROR: function round(double precision, integer) does not exist`. The
two-argument `round` exists only for `numeric`. Fix:
`round(3.14159::numeric, 2)`.
**15.** `42`, `-1`
**16.** `1024`, `1024`
**17.** `12`, `3`
**18.** `2`, `10`, `1`
**19.** `3.141592653589793`
**20.** `SELECT random();`
**21.** `SELECT floor(random() * 100 + 1)::int;`
**22.** `t` and `f`
**23.** `0.30000000000000004`
**24.** `ERROR: integer out of range`. PostgreSQL errors rather than wrapping.
**25.** `ERROR: division by zero`. Not NULL, not infinity.
**26.** `0.05000` — five decimal places. Multiplying `numeric` values **adds
their scales**: 2 + 3 = 5.
**27.** `1,234,567.89`
**28.** `0042`
**29.** `SELECT to_char(1234.5, '999,999.00');` → `   1,234.50` with leading
spaces. `FM` (fill mode) suppresses the padding. Forgetting `FM` is why output
has a mysterious leading space.
**30.** `SELECT product_name FROM products ORDER BY random() LIMIT 3;`

### Section B

**31.**
```sql
SELECT product_name, price, cost, round(price - cost, 2) AS margin FROM products;
```
**32.**
```sql
SELECT product_name, round((price - cost) / price * 100, 1) AS margin_pct
FROM   products ORDER BY margin_pct DESC;
```
**33.** `SELECT product_name, round(price * stock_quantity, 2) AS stock_value FROM products ORDER BY stock_value DESC;`
**34.** `SELECT product_name, round(stock_quantity::numeric / 7, 1) AS weeks FROM products;`
**35.**
```sql
SELECT order_id, product_id,
       round(quantity * unit_price * (1 - discount_pct), 2) AS line_total
FROM   order_items;
```
**36.**
```sql
SELECT order_id, product_id,
       round(quantity * unit_price * (1 - discount_pct), 2) AS line_total
FROM   order_items
WHERE  quantity * unit_price * (1 - discount_pct) > 500
ORDER  BY line_total DESC;
```
**37.** `SELECT first_name, round(salary / 12, 2) AS monthly FROM employees ORDER BY monthly DESC;`
**38.** `SELECT first_name, round(salary * commission_pct, 2) AS commission FROM employees;`
— seven blank rows, the non-Sales staff. Arithmetic with NULL is NULL.
**39.** `SELECT amount, round(amount * 0.029 + 0.30, 2) AS fee FROM payments;`
**40.** `SELECT amount, round(amount - (amount * 0.029 + 0.30), 2) AS net FROM payments;`
**41.** `SELECT product_name, round(price * 1.19, 2) AS with_vat FROM products;`
**42.** `SELECT product_name, price, round(price / 10) * 10 AS nearest_10 FROM products;`
**43.** `SELECT product_name, floor(price) AS floored FROM products;`
**44.** `SELECT product_name, ceil(price) AS ceiled FROM products;`
**45.** `SELECT product_name, price FROM products WHERE round(price) <> trunc(price);`
→ every product whose fractional part is ≥ 0.5, e.g. 29.99, 89.99, 49.99.
**46.**
```sql
SELECT product_name, round((price - cost) / price * 100, 1) AS margin_pct
FROM   products WHERE (price - cost) / price * 100 > 60
ORDER  BY margin_pct DESC;
```
→ the accessories: `Wireless Mouse` (60.0%), `USB-C Hub` (60.0%),
`Laptop Stand` (62.5%), `Chef Knife` (58.3%)… run it and read the real list,
minding the strict `>`.
**47.**
```sql
SELECT product_name, round(price * stock_quantity, 2) AS stock_value
FROM   products WHERE price * stock_quantity BETWEEN 1000 AND 10000
ORDER  BY stock_value DESC;
```
**48.** `SELECT 'CUST-' || lpad(customer_id::text, 4, '0') FROM customers;`
**49.** `SELECT order_id, shipping_cost / 100 * 100 FROM orders;` — returns the
original value, because `shipping_cost` is `numeric` so no truncation occurs.
Had it been `integer`, `shipping_cost / 100` would have been 0 for every order
under €100 and the answer would be 0. That is the whole point of the exercise.
**50.** `SELECT review_id, round(helpful_votes::numeric / 100 * 100, 1) FROM reviews;`
**51.**
```sql
SELECT product_name, price, floor(price / 100) * 100 AS price_band
FROM   products ORDER BY price_band, price;
```
**52.** `SELECT product_name, round(price / weight_kg, 2) AS price_per_kg FROM products ORDER BY price_per_kg DESC;`
→ `Smart Watch` leads, at 249.00 / 0.045 ≈ 5533.33.
**53.**
```sql
SELECT order_id, product_id,
       round(quantity * unit_price * discount_pct, 2) AS saving
FROM   order_items
WHERE  quantity * unit_price * discount_pct > 50
ORDER  BY saving DESC;
```
**54.** `SELECT first_name, round(salary / 36500, 2) AS multiple FROM employees ORDER BY multiple DESC;`
**55.** `SELECT product_name, round(cost / price * 100, 1) AS cost_pct FROM products ORDER BY cost_pct;`

### Section C

**56.** `SELECT split_part(email, '@', 2) FROM customers;`
**57.** `SELECT concat_ws(' ', first_name, last_name) FROM customers;`
**58.** `WHERE product_name ILIKE '%laptop%';`
**59.** `WHERE phone IS NULL;` → 5
**60.** 0 rows — the NULL in the list makes every comparison UNKNOWN.
**61.** `WHERE paid_at >= '2024-09-01' AND paid_at < '2024-10-01';`
**62.** `a-b` and `NULL`.
**63.** `WHERE stock_quantity > 0 ORDER BY price DESC LIMIT 3;`
**64.** `WHERE commission_pct IS DISTINCT FROM 0.040;` → 10
**65.** `\i 99_reset.sql`

### Section D

**66.**
```sql
SELECT 0.1 + 0.2                         AS numeric_sum,
       0.1 + 0.2 = 0.3                   AS numeric_exact,
       0.1::float8 + 0.2::float8         AS float_sum,
       0.1::float8 + 0.2::float8 = 0.3::float8 AS float_exact;
```
→ `0.3 | t | 0.30000000000000004 | f`

**67.**
```sql
SELECT n,
       round(n::numeric) AS as_numeric,
       round(n::float8)  AS as_float
FROM   (VALUES (0.5),(1.5),(2.5),(3.5)) AS t(n);
```
→ numeric: 1, 2, 3, 4 (half away from zero).
→ float8: 0, 2, 2, 4 (half to even).
(`VALUES` as a row source is formally Day 39; it's used here only to keep the
comparison on one screen. Four separate `SELECT`s are equally fine.)

**68.** `(10 / 3)::numeric` = `3.0`; `10::numeric / 3` = `3.333…`.
**Cast the operand, not the result** — by the time you cast the result, the
integer division has already thrown the fraction away.

**69.**
```sql
SELECT product_name, round((price - cost) / NULLIF(cost, 0), 4) AS markup
FROM   products;
```
`NULLIF(a, b)` returns `NULL` when `a = b`, otherwise `a`. So a zero cost
becomes `NULL`, dividing by `NULL` yields `NULL`, and you get a blank cell
instead of an aborted query. Reasoning it out before Day 17 is exactly the
intent — you now have a concrete problem that `NULLIF` solves, which is a far
better way to meet a function than a reference list.

**70.**
```sql
SELECT order_id, product_id,
       round(quantity * unit_price * (1 - discount_pct), 2)         AS round_once,
       round(quantity * round(unit_price * (1 - discount_pct), 2), 2) AS round_early
FROM   order_items
WHERE  round(quantity * unit_price * (1 - discount_pct), 2)
    <> round(quantity * round(unit_price * (1 - discount_pct), 2), 2);
```
Rounding the per-unit price first throws away up to half a cent **per unit**,
then multiplies that error by the quantity. On a 2-unit line the discrepancy can
reach a cent; on a 1,000-unit line, five euros. This is why accounting systems
specify precisely where rounding occurs, and why "round once, at the end" is a
rule rather than a preference.

**71.**
```sql
SELECT product_name, round((price - cost) / NULLIF(price, 0) * 100, 1) AS margin_pct
FROM   products;
```
A `WHERE price > 0` clause is not a reliable guard because SQL gives **no
guarantee** that `WHERE` conditions are evaluated before `SELECT` expressions,
or in any particular order among themselves. The planner may compute the
division while evaluating the scan. `NULLIF` makes the expression itself safe,
which is the only robust approach. (Day 8, Part 7.)

**72.** `floor(random() * 100)` maps the uniform interval [0,1) onto 100
equal-width buckets, 0–99 — uniform.
`round(random() * 100)` produces 101 possible values, 0–100, but **0 and 100 are
half as likely** as the others: 0 comes only from [0, 0.005) and 100 only from
[0.995, 1), each half the width of the interval mapping to any interior value.
The general rule for a uniform integer in `[lo, hi]` is
`lo + floor(random() * (hi - lo + 1))`.

**73.** `SELECT round(2.675, 2);` on `numeric` → **2.68**, because `numeric`
stores 2.675 exactly and rounds half away from zero.
`SELECT round(2.675::float8::numeric, 2);` → **2.67**, because the nearest
`float8` to 2.675 is actually 2.67499999999999982..., which rounds down.

This is the canonical floating-point rounding surprise — it is the reason
`round(2.675, 2)` returns `2.67` in Python and JavaScript — and PostgreSQL gets
the *right* answer only because `numeric` is exact. Being able to explain this
is a strong signal in an interview.

**74.**
```sql
SELECT 2147483647 - max_id AS remaining
FROM   (SELECT max(order_id) AS max_id FROM orders) AS t;
```
…except `max()` and subqueries are Days 19 and 39. With today's tools:
```sql
SELECT 2147483647 - order_id AS remaining
FROM   orders ORDER BY order_id DESC LIMIT 1;
```
→ 2,147,483,587. Plenty. The point of the exercise is that this is a number you
should be able to compute for a real table, and that "plenty" stops being true
at a few thousand inserts per second sustained for a decade — which is exactly
the timescale on which long-lived systems fail.

**75.** **The argument for changing it:**

Binary floating point cannot represent most decimal fractions exactly. Over 40
million rows, errors accumulate in any aggregation, so totals will not
reconcile — and the discrepancies will be small, non-reproducible and
maddening. Equality comparisons on balances are already unreliable. Any
regulated or audited context makes this a compliance problem, not just a
correctness one. Demonstrate with the `0.1 + 0.2` query; it takes ten seconds
and is more persuasive than any argument.

**Migration risks:**

- `ALTER TABLE ... ALTER COLUMN ... TYPE numeric(12,2)` rewrites the entire
  table and holds an `ACCESS EXCLUSIVE` lock for the duration — on 40M rows that
  is an outage, not a maintenance window.
- The conversion itself must **round**, and you must decide the rule and record
  it. Values that were "0.1 + 0.2" are now committed to being 0.30.
- Existing totals stored elsewhere will no longer match recomputed ones, so
  historical reports will shift slightly. Somebody must sign off on that.
- Application code comparing floats with tolerances may now behave differently.

**The safer path:** add a new `numeric` column, backfill in batches with
throttling, write to both columns during a transition period, verify the two
agree within tolerance, switch reads over, then drop the old column. Slower,
online, reversible at every step. (Day 62.)

**If the change is refused:** document the decision and its owner in writing;
add a reconciliation check that compares recomputed totals against expected
values and alerts on drift; ensure every *new* money column uses `numeric` so
the problem stops growing; and round consistently at every read site so at
least the displayed figures are stable. You cannot make a float exact, but you
can stop the blast radius expanding — and the written record matters when the
problem surfaces two years later.

---

## Day 14 Checklist

- [ ] I can name the three numeric families and when each is appropriate
- [ ] **I know money is `numeric`, never a float, and I can demonstrate why**
- [ ] I know `int / int` truncates toward zero
- [ ] **I cast the operand, not the result**
- [ ] I can use `round`, `ceil`, `floor`, `trunc` and know how they differ at .5
- [ ] I know `numeric` rounds half-away-from-zero and `float8` uses banker's
      rounding
- [ ] I know `round(x, d)` needs a `numeric`, not a `float8`
- [ ] I round once, at the end, never in the middle
- [ ] I know division by zero and integer overflow are hard errors
- [ ] I know `NULLIF(x, 0)` is the division guard, and why `WHERE` isn't
- [ ] I know `numeric` multiplication adds scales

---

## What's next

**Day 15 — Dates and times, part 1.** The four date/time types, why
`timestamptz` is almost always the right one, `EXTRACT`, `date_trunc`, and how
to ask "which month was this in?" without reaching for string functions.
