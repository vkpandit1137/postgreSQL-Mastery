# Day 03 — Build the Practice Database & `SELECT ... FROM`

> **Phase** 1 · Foundations
> **Level** Absolute Beginner
> **Time** 100–130 minutes
> **Prerequisites** Days 01–02
> **New concepts** `CREATE DATABASE` (by running a script) · `\i` · `SELECT * FROM` · reading a result set · `\d` to inspect a table · `count(*)` as a sanity check · the shape of `shopdb`

---

## Why this matters

Today you get data. From here to Day 115, every single query runs against the
same nine tables. By Day 30 you will know this database the way you know your
own kitchen — which drawer holds what, without looking.

That familiarity is the hidden curriculum. Learning SQL on a database you don't
know means fighting two unknowns at once. Learning it on one database you know
cold means every new concept lands against a fixed background.

---

## Part 1 — The Sandbox Exception

You are about to run three SQL files you cannot yet read. They contain
`CREATE TABLE` and `INSERT`, which are Days 53 and 59.

That is allowed, once, by **Rule R4** in `RULES.md`. *Running* a script someone
else wrote is not the same as *writing* a query. Everything you write yourself,
from now until Day 115, uses only concepts already taught.

On Day 53 you will re-open `datasets/01_schema.sql` as a comprehension
exercise and find you understand every line of it. That moment is a good
milestone to look forward to.

---

## Part 2 — Building it

From your **operating-system shell** (not inside `psql`):

```bash
cd path/to/postgresql-mastery/datasets

psql -U postgres -f 00_create_database.sql
psql -U postgres -d shopdb -f 01_schema.sql
psql -U postgres -d shopdb -f 02_data.sql
```

On Linux, prefix each with `sudo -u postgres` if that's how you connect.

Alternatively, from **inside `psql`**:

```
\i 00_create_database.sql
\c shopdb
\i 01_schema.sql
\i 02_data.sql
```

`\i` means "read this file and execute it as if I had typed it". It is the
meta-command you'll use every time you need to reset.

Expected tail of the output:

```
02_data.sql : seed data loaded.
```

### Connect and verify

```bash
psql -U postgres -d shopdb
```

```
shopdb=#
```

The prompt says `shopdb`. If it says anything else, you are in the wrong
database and nothing today will work.

```
\dt
```

```
          List of relations
 Schema |    Name     | Type  |  Owner
--------+-------------+-------+----------
 public | categories  | table | postgres
 public | customers   | table | postgres
 public | employees   | table | postgres
 public | order_items | table | postgres
 public | orders      | table | postgres
 public | payments    | table | postgres
 public | products    | table | postgres
 public | reviews     | table | postgres
 public | suppliers   | table | postgres
(9 rows)
```

Nine tables. `public` is the default schema — the "folder" tables live in when
you don't say otherwise.

⚠️ **Trap** — If `\dt` says `Did not find any relations`, check `\conninfo`.
Nine times out of ten you are connected to `postgres` instead of `shopdb`.

---

## Part 3 — `SELECT ... FROM`

Yesterday: `SELECT <expressions>;`
Today: `SELECT <expressions> FROM <table>;`

```sql
SELECT * FROM suppliers;
```

```
 supplier_id |    supplier_name    | country |        contact_email         | rating | active_since
-------------+---------------------+---------+------------------------------+--------+--------------
           1 | TechSource Global   | Germany | orders@techsource.example    |    4.5 | 2019-03-01
           2 | Pacific Components  | Taiwan  | sales@pacificcomp.example    |    4.2 | 2020-07-15
           3 | Nordic Home Goods   | Sweden  |                              |    4.8 | 2018-01-20
           4 | Delhi Print House   | India   | hello@delhiprint.example     |    3.9 | 2021-11-02
           5 | Atlas Furniture Co  | Poland  | b2b@atlasfurniture.example   |    4.0 | 2017-06-30
           6 | Quantum Peripherals | China   | export@quantumper.example    |    3.5 | 2022-02-11
(6 rows)
```

The mental model has two steps:

1. **`FROM suppliers`** — "start with all the rows in the `suppliers` table."
2. **`SELECT *`** — "for each of those rows, give me every column."

Read it in that order — `FROM` first, then `SELECT`. That is not the order you
*write* it, but it is the order PostgreSQL *evaluates* it, and internalising
this now will save you enormous confusion on Day 21, where the full evaluation
order becomes the central idea of the day.

### What `*` means

`*` means "all columns, in the order they were defined in the table."

```sql
SELECT * FROM categories;
```

Ten rows, four columns. Note row 1: `parent_category_id` is blank. That's
`NULL` — Electronics has no parent because it is a top-level category.

▶ **Try it** — run `SELECT * FROM` for each of the nine tables. Just look. You
are building a mental picture, not analysing anything.

```sql
SELECT * FROM categories;
SELECT * FROM suppliers;
SELECT * FROM products;
SELECT * FROM customers;
SELECT * FROM employees;
SELECT * FROM orders;
SELECT * FROM order_items;
SELECT * FROM payments;
SELECT * FROM reviews;
```

---

## Part 4 — Reading a result set

```
 supplier_id |    supplier_name    | country
-------------+---------------------+---------
           1 | TechSource Global   | Germany
           2 | Pacific Components  | Taiwan
(2 rows)
```

Four things to read every single time:

1. **The header** — column names.
2. **The rows** — the data.
3. **Alignment** — numbers right-aligned, text left-aligned. This is `psql`
   telling you the *type* without being asked. A "number" that is left-aligned
   is actually text, and that is often a bug worth noticing.
4. **`(2 rows)`** — the row count. **Read this every time.** It is your fastest
   correctness check: if you asked for customers and got 60 rows, something is
   very wrong, because there are only 24 customers.

### Wide tables: `\x`

`products` has ten columns and wraps horribly. Turn on expanded display:

```
\x
SELECT * FROM products;
```

```
-[ RECORD 1 ]---+--------------
product_id      | 1
product_name    | Laptop Pro 14
category_id     | 3
supplier_id     | 1
price           | 1899.00
cost            | 1400.00
stock_quantity  | 12
weight_kg       | 1.600
is_discontinued | f
added_on        | 2023-01-15
```

One record per block, one column per line. `\x` off to go back.

💡 **Note** — `\x auto` is better than `\x on`: `psql` uses expanded display
only when the row would be too wide for your terminal. Add it to `~/.psqlrc`.

---

## Part 5 — Inspecting a table with `\d`

Before querying a table you have never seen, describe it:

```
\d customers
```

```
                          Table "public.customers"
    Column    |  Type   | Collation | Nullable |             Default
--------------+---------+-----------+----------+----------------------------------
 customer_id  | integer |           | not null | generated by default as identity
 first_name   | text    |           | not null |
 last_name    | text    |           | not null |
 email        | text    |           | not null |
 phone        | text    |           |          |
 city         | text    |           |          |
 country      | text    |           | not null |
 signup_date  | date    |           | not null |
 birth_date   | date    |           |          |
 loyalty_tier | text    |           |          |
 is_active    | boolean |           | not null | true
Indexes:
    "customers_pkey" PRIMARY KEY, btree (customer_id)
    "customers_email_key" UNIQUE CONSTRAINT, btree (email)
Check constraints:
    "customers_loyalty_tier_check" CHECK (loyalty_tier = ANY (ARRAY['bronze'::text, ...]))
Referenced by:
    TABLE "orders" CONSTRAINT "orders_customer_id_fkey" FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    TABLE "reviews" CONSTRAINT "reviews_customer_id_fkey" FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
```

Even on Day 3, four things are readable:

- **Column** and **Type** — the shape of the table.
- **Nullable** — a blank in this column means the column *can* be NULL. So
  `phone`, `city`, `birth_date` and `loyalty_tier` can be missing.
- **Indexes** — Day 74.
- **Referenced by** — which other tables point at this one. `orders` and
  `reviews` both reference `customers`. That is the map of the database, and
  it's Day 26.

🎯 **Interview** — "You're dropped into an unfamiliar Postgres database. First
three commands?" → `\dt` (what tables exist), `\d tablename` (what's in them),
`\d+ tablename` (plus sizes and descriptions). Then
`SELECT * FROM t LIMIT 10;` to see real values. Saying this fluently marks you
as someone who has actually worked in a terminal.

---

## Part 6 — Counting rows

```sql
SELECT count(*) FROM customers;
```

```
 count
-------
    24
```

`count(*)` returns the number of rows. It is an **aggregate function** — it
collapses many rows into one number — and aggregates are Day 19. You are
allowed it today for exactly one purpose: sanity-checking.

The full set, which you should verify right now:

```sql
SELECT count(*) FROM categories;    -- 10
SELECT count(*) FROM suppliers;     --  6
SELECT count(*) FROM products;      -- 25
SELECT count(*) FROM customers;     -- 24
SELECT count(*) FROM employees;     -- 12
SELECT count(*) FROM orders;        -- 60
SELECT count(*) FROM order_items;   -- 105
SELECT count(*) FROM payments;      -- 56
SELECT count(*) FROM reviews;       -- 36
```

▶ **Try it** — run all nine. If any number differs, re-run
`\i 99_reset.sql` before going further.

**Memorise these nine numbers.** It takes five minutes and it pays off for a
hundred days. When a query returns 105 rows and you expected 60, you will know
instantly that you have accidentally multiplied `orders` by `order_items` —
a mistake you will otherwise make silently a dozen times in Phase 4.

---

## Part 7 — The database you'll live in

Open `datasets/DATA_DICTIONARY.md` and keep it open in a second window for the
rest of the program. Here is the one-paragraph version.

**A shop.** `customers` buy things. Each purchase is an `orders` row, and the
individual products on that purchase are `order_items` rows. The things for sale
are `products`, which belong to `categories` (a tree — categories can have
parent categories) and come from `suppliers`. Money arrives as `payments`
against an order. Customers leave `reviews` on products. The shop has
`employees`, arranged in a hierarchy where each employee has a manager.

```
categories ──< products >── suppliers
                   │
                   │
   customers ──< orders >── order_items
       │            │
       │            └──< payments
       └──< reviews >──┘

employees (self-referencing: employee → manager)
```

Six features of the data that were put there on purpose, and that you will use
repeatedly:

| Feature | Where | Used from |
|---|---|---|
| Missing values (`NULL`) | `customers.city`, `phone`, `birth_date`, `loyalty_tier` | Day 9 |
| Customers with no orders | customers 13, 18, 22, 23 | Day 29 |
| Products never ordered | products 6, 16, 25 | Day 29 |
| A tree | `categories.parent_category_id` | Day 43 |
| A hierarchy | `employees.manager_id` | Day 32 |
| No stored order total | you compute it from `order_items` | Day 19 onward |

That last one is the most important. **`orders` has no `total_amount` column.**
An order's value is `quantity * unit_price * (1 - discount_pct)`, summed across
its items, plus `shipping_cost`. You will write that expression so many times it
becomes reflex. That is deliberate — it is also exactly what real schemas look
like.

---

## Traps & Gotchas

| # | Trap | The fix |
|---|---|---|
| 1 | Running `\i 01_schema.sql` while connected to `postgres` | `\c shopdb` first. Check the prompt. |
| 2 | `SELECT * FROM customer;` (singular) | Tables here are plural: `customers` |
| 3 | `SELECT * FROM "Customers";` | Double quotes make the name case-sensitive. There is no `Customers`. |
| 4 | Using `SELECT *` in application code | Fine while learning; a bug in production — a new column silently changes your result shape. |
| 5 | Assuming the row order you see is stable | It isn't. `ORDER BY` is Day 5. |
| 6 | Not reading `(n rows)` | Your cheapest correctness check, free on every query. |
| 7 | Panicking after breaking the data | `\i 99_reset.sql`. One second. Break things. |

### About case sensitivity

```sql
SELECT * FROM CUSTOMERS;   -- works
SELECT * FROM Customers;   -- works
SELECT * FROM "customers"; -- works
SELECT * FROM "Customers"; -- ERROR: relation "Customers" does not exist
```

Unquoted identifiers are **folded to lowercase**. So `CUSTOMERS`, `Customers`
and `customers` are all the table `customers`. But a *quoted* identifier is
taken exactly as written, and there is no table literally named `Customers`.

🎯 **Interview** — "Why do people say never to use quoted identifiers in
Postgres?" Because once a table is created as `"myTable"`, every single query
against it forever must also quote it exactly. One missing pair of quotes and
it breaks. Use `snake_case` and never quote. This bites hardest when an ORM
creates camelCase tables.

---

## Interview angles

- **Junior** — "How do you see all the tables in a database?" → `\dt` in psql,
  or `SELECT tablename FROM pg_tables WHERE schemaname = 'public';`
- **Junior** — "What does `SELECT *` do and why avoid it in code?" → All
  columns; avoid because it breaks when the schema changes, transfers data you
  don't need, and prevents index-only scans (Day 74).
- **Mid** — "What's the `public` schema?" → The default schema, first on the
  default `search_path`. Since Postgres 15 it is no longer world-writable by
  default, which was a long-standing security wart.
- **Senior** — "How would you explore an unfamiliar 400-table production
  database?" → `\dt+` sorted by size, `pg_stat_user_tables` for which tables
  are actually read and written, foreign keys from `information_schema` to
  reconstruct the ER diagram, and `pg_stat_statements` for what queries actually
  run. Never start by reading all 400 tables.

---

## Practice

### Section A — Drill (new concept only)

1. Show every column and row of `suppliers`.
2. Show every column and row of `categories`.
3. Show every column and row of `employees`.
4. Show every column and row of `products`. Use `\x` if it wraps.
5. Show every column and row of `customers`.
6. Show every column and row of `orders`.
7. Show every column and row of `order_items`.
8. Show every column and row of `payments`.
9. Show every column and row of `reviews`.
10. How many rows are in `products`?
11. How many rows are in `orders`?
12. How many rows are in `order_items`?
13. How many rows are in `reviews`?
14. Describe the `orders` table. Which columns can be NULL?
15. Describe the `products` table. What type is `price`?
16. Describe the `employees` table. Which column refers back to the same table?
17. Describe `order_items`. Which two tables does it reference?
18. Which tables reference `customers`? (Read the bottom of `\d customers`.)
19. Turn on expanded display, show `reviews`, turn it off.
20. List all nine tables.

### Section B — Combination (with Days 01–02)

21. Using `SELECT` with no table, return the text `'shopdb loaded'`.
22. Return the current date and the current user in one row.
23. Show every row of `categories`, then state in one sentence what
    `parent_category_id` being NULL means.
24. Look at `products` and find, by eye, the most expensive product. Write down
    its name. (Doing this by eye now makes Day 5's `ORDER BY` feel like a
    superpower.)
25. Look at `customers` and count by eye how many have no `city`.
26. Look at `orders` and count by eye how many have no `employee_id`.
27. Compute, with no table, what 20% of 1899.00 is.
28. Compute, with no table, the line total for 2 units at 89.99 with a 10%
    discount, using the formula `quantity * unit_price * (1 - discount_pct)`.
29. Using `generate_series`, produce the numbers 1 to 9 — one for each table in
    this database.
30. Show the PostgreSQL version and confirm it is 14 or newer.

### Section C — Recall (Days 01–02)

31. Which database are you connected to? Prove it two ways.
32. Return `'It''s a table'` as text.
33. What is `pg_typeof(1899.00)`?
34. What is `144 / 5`? Make it return a decimal.
35. Concatenate `'Order #'` and the number `1001`.
36. What does `'abc' || NULL` return?
37. Cast `'25'` to an integer and add 17 to it.
38. Get `psql` help for `CREATE TABLE`. (You won't understand it. Look anyway —
    on Day 53 you'll come back and it will read like English.)

### Section D — Challenge

39. Find out how much disk space the `orders` table occupies. (Hint: `\dt+`.)
40. Find out how many columns the `products` table has, using SQL rather than
    counting by eye. (Hint: there's a catalog view called
    `information_schema.columns`, and you already know `count(*)` and `FROM`.
    You do not yet know `WHERE` — so try it, see what number you get, and work
    out why it's enormous.)
41. `SELECT * FROM orders;` twice in a row. Is the row order identical? Should
    you rely on that?
42. Without using `\d`, find the names of all nine tables using a `SELECT`
    against `pg_tables`. What extra rows do you get and why?
43. Deliberately break something: `DELETE FROM reviews;` then
    `SELECT count(*) FROM reviews;`. Then restore with `\i 99_reset.sql` and
    verify you are back to 36. (You have not been taught `DELETE`. Run it
    anyway — the point of this exercise is to prove to yourself that the reset
    works, so you stop being afraid of the database.)

---

## Solutions

**1–9.** `SELECT * FROM <table>;` for each. Row counts: suppliers 6,
categories 10, employees 12, products 25, customers 24, orders 60,
order_items 105, payments 56, reviews 36.

**10.** `SELECT count(*) FROM products;` → 25
**11.** `SELECT count(*) FROM orders;` → 60
**12.** `SELECT count(*) FROM order_items;` → 105
**13.** `SELECT count(*) FROM reviews;` → 36

**14.** `\d orders` — nullable: `employee_id`, `shipping_city`,
`shipping_country`. Everything else is `not null`. `employee_id` is nullable
because some orders are self-service, placed with no salesperson involved.

**15.** `\d products` — `price` is `numeric(10,2)`: up to 10 total digits, 2
after the decimal point. Exact, not floating point. Correct choice for money.

**16.** `manager_id` references `employees(employee_id)`. A self-referencing
foreign key. That's what makes a hierarchy — Day 32 and Day 43.

**17.** `order_items` references `orders(order_id)` and
`products(product_id)`. A table that exists to connect two other tables is
called a **junction** or **bridge** table, and it's how you model a many-to-many
relationship. Day 26.

**18.** `orders` and `reviews`.

**19.** `\x` → `SELECT * FROM reviews;` → `\x`

**20.** `\dt`

**21.** `SELECT 'shopdb loaded';`
**22.** `SELECT current_date, current_user;`
**23.** `SELECT * FROM categories;` — a NULL `parent_category_id` means the
category is top-level: it has no parent. There are three (Electronics,
Home & Living, Books).
**24.** `Laptop Pro 14`, at 1899.00.
**25.** Two — customers 7 (Marie Dubois) and 18 (Nina Petrova).
**26.** Six — orders 5, 14, 22, 24, 35, 43.
**27.** `SELECT 1899.00 * 0.20;` → 379.8000
**28.** `SELECT 2 * 89.99 * (1 - 0.10);` → 161.982
**29.** `SELECT generate_series(1, 9);`
**30.** `SELECT version();`

**31.** `\conninfo`, and the prompt itself (`shopdb=#`). A third way:
`SELECT current_database();`
**32.** `SELECT 'It''s a table';`
**33.** `numeric`
**34.** `SELECT 144 / 5;` → 28. `SELECT 144::numeric / 5;` → 28.8
**35.** `SELECT 'Order #' || 1001;`
**36.** `NULL`
**37.** `SELECT '25'::integer + 17;` → 42
**38.** `\h CREATE TABLE`

**39.**
```
\dt+ orders
```
Around 16 kB — trivially small. Keep this number in mind: on Day 73 you'll load
a 5-million-row table and watch the same command report gigabytes.

**40.**
```sql
SELECT count(*) FROM information_schema.columns;
```
You get a number in the thousands, because that view lists every column of
**every table in the database**, including hundreds of internal catalog tables.
To narrow it to `products` you need `WHERE`, which is Day 7. Come back to this
question on Day 7 — it is question 47 of Day 07's Section C, and you'll answer
it in one line.

This is what the waterfall looks like from the inside: you meet a question, you
can't answer it yet, and four days later you can. Note it in `mistakes.md` as an
open question.

**41.** In practice, yes — the rows come back in physical storage order and
nothing has moved them. But it is **not guaranteed**, and it will stop being
true the moment rows are updated, the table is vacuumed, or the planner chooses
an index scan or a parallel scan. Never rely on it. `ORDER BY` is Day 5, and
the rule is: *if the order matters, say so*.

**42.**
```sql
SELECT schemaname, tablename FROM pg_tables;
```
You get around 70 rows, not 9 — because `pg_tables` includes the system catalog
tables in the `pg_catalog` and `information_schema` schemas. Filtering to
`schemaname = 'public'` needs `WHERE` (Day 7).

**43.**
```sql
DELETE FROM reviews;
SELECT count(*) FROM reviews;   -- 0
\i 99_reset.sql
SELECT count(*) FROM reviews;   -- 36
```
That's the point of the exercise. The reset works. You cannot permanently ruin
anything. Experiment freely from here on — the learners who poke at the database
learn twice as fast as the learners who tiptoe around it.

---

## Day 03 Checklist

- [ ] `shopdb` exists and `\dt` shows nine tables
- [ ] I have run `SELECT *` against all nine and looked at the data
- [ ] I know the nine row counts by heart (10, 6, 25, 24, 12, 60, 105, 56, 36)
- [ ] I can use `\d tablename` and read the Nullable column
- [ ] I know `*` means "all columns" and why not to use it in application code
- [ ] I know unquoted identifiers fold to lowercase
- [ ] I have run `\i 99_reset.sql` at least once and seen it work
- [ ] I know `orders` has no total column and how an order total is computed
- [ ] `DATA_DICTIONARY.md` is open in a second window

---

## What's next

**Day 04 — Columns, aliases and expressions.** You stop saying `*` and start
choosing exactly what you want, naming it properly, and computing new columns
that don't exist in the table at all — including that order-line total you will
be writing for the next 112 days.
