# Day 02 — The Relational Model & `SELECT` Without a Table

> **Phase** 1 · Foundations
> **Level** Absolute Beginner
> **Time** 90–120 minutes
> **Prerequisites** Day 01 (you can connect with `psql` and run a statement)
> **New concepts** Tables/rows/columns · `SELECT` with no `FROM` · literals · data types · arithmetic & text operators · `::` casting · `NULL` (first sighting) · comparison operators returning booleans

---

## Why this matters

Almost every SQL tutorial starts by throwing you at a table with fifteen columns
and saying "here, select from it." You then spend a month unable to tell which
part of the query is *the selection* and which part is *the table*.

We're going to separate those. Today you learn what `SELECT` does — compute
things and hand them back — with no table involved at all. Tomorrow you add the
table. Two ideas, learned one at a time.

---

## Part 1 — What a table actually is

A **table** is a grid. That's it.

```
                     ← columns (also: fields, attributes) →
             ┌──────────────┬──────────────┬──────────────┬─────────┐
             │ customer_id  │ first_name   │ country      │ is_active│
             ├──────────────┼──────────────┼──────────────┼─────────┤
      ↑      │      1       │ Anna         │ Germany      │  true   │  ← a row
   rows      │      2       │ Rajesh       │ India        │  true   │
  (records,  │      3       │ Emily        │ USA          │  true   │
   tuples)   │      4       │ Liu          │ China        │  true   │
      ↓      └──────────────┴──────────────┴──────────────┴─────────┘
```

Four properties that are non-negotiable and that beginners routinely assume
wrong:

1. **Every column has a fixed type.** `customer_id` holds integers. You cannot
   put the word "banana" in it. The database will refuse, loudly. This is a
   feature — it is the database defending your data from your application.

2. **Every row in a table has exactly the same columns.** There is no such thing
   as "this row has an extra field." (If you come from MongoDB, this is the
   single biggest adjustment.)

3. **Rows have no inherent order.** None. A table is a *set* of rows, not a
   list. If you want them in an order you must say so — that's Day 5's `ORDER
   BY`. A query without `ORDER BY` may return rows in a different order
   tomorrow, and PostgreSQL is entirely within its rights to do that.

4. **A cell can be empty in a special way: `NULL`.** `NULL` is not zero and not
   an empty string. It means *"no value here"*. You meet it properly on Day 9,
   and it will be the source of more of your bugs than any other single thing
   in SQL.

⚠️ **Trap** — "Rows have no order" is the rule beginners break first. They run
a query, see the rows come back in insertion order, and assume that's
guaranteed. It is not. The moment the table gets an index, or grows, or gets
`VACUUM`ed, the order can change silently. Your report is then wrong and nobody
notices for a month.

---

## Part 2 — `SELECT` with nothing to select from

In most databases `SELECT` requires a `FROM`. In PostgreSQL it does not.

```sql
SELECT 1;
```

```
 ?column?
----------
        1
(1 row)
```

You asked PostgreSQL to compute the expression `1` and give it back. It made a
result with **one row and one column**.

This is the purest form of `SELECT`: *"compute these expressions, give me the
answers."* Where the values come from is a separate question — that's `FROM`,
and that's tomorrow.

### Several columns

Separate expressions with commas:

```sql
SELECT 1, 2, 3;
```

```
 ?column? | ?column? | ?column?
----------+----------+----------
        1 |        2 |        3
(1 row)
```

Three columns, one row. Note that PostgreSQL is happy to give three columns the
same name. Column names in a result set do not have to be unique — only
*table* column names do.

### Expressions, not just literals

```sql
SELECT 2 + 3, 10 * 4, 100 - 1;
```

```
 ?column? | ?column? | ?column?
----------+----------+----------
        5 |       40 |       99
(1 row)
```

PostgreSQL is now a calculator. That sounds trivial; it is not. It means you can
test *any* expression instantly without needing data. You will use this
technique for the rest of your career: when you're unsure what a function does,
`SELECT` it on its own first.

▶ **Try it** — run all four of the above before reading on.

---

## Part 3 — Literals: writing values by hand

A **literal** is a value written directly in the query.

### Numbers

```sql
SELECT 42, -7, 3.14, 0.5, 1e3;
```

```
 ?column? | ?column? | ?column? | ?column? | ?column?
----------+----------+----------+----------+----------
       42 |       -7 |     3.14 |      0.5 |     1000
```

No quotes. `1e3` is scientific notation for 1000.

### Text

**Single quotes. Always single quotes.**

```sql
SELECT 'hello';
```

```
 ?column?
----------
 hello
```

⚠️ **Trap — the single most common beginner error in PostgreSQL:**

```sql
SELECT "hello";
```

```
ERROR:  column "hello" does not exist
LINE 1: SELECT "hello";
               ^
```

In PostgreSQL:

| Quote | Means |
|---|---|
| `'single'` | a **text value** |
| `"double"` | an **identifier** — the name of a table or column |

So `"hello"` means "the column called hello", which doesn't exist. If you come
from MySQL (where double quotes often work for strings) or from a programming
language (where `"x"` is a string), this will catch you. PostgreSQL follows the
SQL standard here and the standard is strict.

Say it to yourself once: **single quotes for data, double quotes for names.**

### An apostrophe inside text

What if the value itself contains a `'`?

```sql
SELECT 'O'Connor';        -- broken
```

You get the `'#` prompt, because PostgreSQL saw the string end at `O`, then
`Connor` as garbage, then an unterminated quote. Double the apostrophe:

```sql
SELECT 'O''Connor';
```

```
 ?column?
----------
 O'Connor
```

Two single quotes inside a string mean one literal apostrophe. Note this is
`''` (two singles), **not** `"` (one double). This matters in the practice
database: customer 19 is `O''Connor` in the seed file.

🐘 **Postgres-only** — there is a nicer alternative, dollar quoting:

```sql
SELECT $$O'Connor$$;
```

Everything between `$$` and `$$` is literal. This becomes essential on Day 92
when you write functions containing whole SQL statements.

### Booleans

```sql
SELECT true, false;
```

```
 bool | bool
------+------
 t    | f
```

`psql` displays booleans as `t` and `f`. They are not the strings `'t'` and
`'f'` — they are the boolean values. PostgreSQL also accepts `TRUE`, `'yes'`,
`'on'`, `'1'` as boolean input, but write `true` and `false`.

### Dates and timestamps

```sql
SELECT DATE '2024-03-15';
SELECT TIMESTAMP '2024-03-15 14:30:00';
```

```
    date
------------
 2024-03-15
```

The type name in front tells PostgreSQL how to interpret the string.
Full treatment on Days 15–16. For now: `YYYY-MM-DD` is the unambiguous format,
and you should use it exclusively. `'03/15/2024'` is ambiguous (is it March 15
or the 3rd day of month 15?) and its meaning depends on a server setting. Never
write it.

### `NULL`

```sql
SELECT NULL;
```

```
 ?column?
----------

(1 row)
```

Blank. Not zero, not empty string — *absent*. (If you set
`\pset null '␀'` from Day 1, you'll see `␀` instead, which is why that setting
is worth having.) Day 9 is entirely about `NULL` and it is one of the most
important days in this program.

---

## Part 4 — Data types, first pass

Every value in PostgreSQL has a type. Ask what type something is:

```sql
SELECT pg_typeof(1), pg_typeof(1.5), pg_typeof('hi'), pg_typeof(true);
```

```
 pg_typeof | pg_typeof | pg_typeof | pg_typeof
-----------+-----------+-----------+-----------
 integer   | numeric   | unknown   | boolean
```

Interesting results:

- `1` → **`integer`**. Whole numbers up to about 2.1 billion.
- `1.5` → **`numeric`**. Exact decimal. PostgreSQL chooses `numeric` over
  `float` for decimal literals because `numeric` is exact, and exactness is the
  safer default for anything resembling money.
- `'hi'` → **`unknown`**. A bare quoted literal has no type yet; PostgreSQL
  works it out from context. In practice it becomes `text`.
- `true` → **`boolean`**.

The types you will actually use, in rough order of frequency:

| Type | Holds | Example |
|---|---|---|
| `integer` (`int4`) | whole numbers ±2.1 billion | `42` |
| `bigint` (`int8`) | whole numbers ±9.2 quintillion | `9000000000` |
| `numeric(p,s)` | exact decimal, `p` digits, `s` after the point | `numeric(10,2)` for money |
| `text` | any-length string | `'hello'` |
| `varchar(n)` | string up to `n` characters | `varchar(50)` |
| `boolean` | true / false / NULL | `true` |
| `date` | a calendar day | `2024-03-15` |
| `timestamptz` | an instant in time, timezone-aware | `2024-03-15 14:30:00+00` |
| `jsonb` | structured JSON | `'{"a":1}'` |
| `uuid` | 128-bit identifier | `gen_random_uuid()` |

🎯 **Interview** — "`text` vs `varchar(n)` in Postgres?" Performance is
**identical**; `varchar(n)` merely adds a length check. Use `text` unless you
have a genuine business rule about maximum length, and if you do, prefer a
`CHECK` constraint so you can change it without a table rewrite. This answer
signals immediately that you know Postgres specifically, not "SQL in general" —
in SQL Server and Oracle the trade-offs are different.

### Casting with `::`

Convert a value from one type to another:

```sql
SELECT '42'::integer;
SELECT 42::text;
SELECT '2024-03-15'::date;
SELECT 3.7::integer;
```

```
 int4
------
   42
```

```
 int4
------
    4
```

Note that last one: `3.7::integer` gives **4**, not 3. Casting to integer
**rounds**, it does not truncate. (Integer *division*, which you met in Day 1's
practice, truncates. Different operation, different rule. Both on Day 14.)

The standard SQL spelling also works and is more portable:

```sql
SELECT CAST('42' AS integer);
```

🐘 **Postgres-only** — `::` is a PostgreSQL shorthand. `CAST(x AS type)` is the
standard. Use `::` in Postgres-only code (it's far more readable in long
queries); use `CAST` if the SQL must run elsewhere.

A cast that can't work fails loudly:

```sql
SELECT 'banana'::integer;
```

```
ERROR:  invalid input syntax for type integer: "banana"
```

Good. That is the database protecting you.

---

## Part 5 — Operators

### Arithmetic

```sql
SELECT 10 + 3, 10 - 3, 10 * 3, 10 / 3, 10 % 3, 10 ^ 3;
```

```
 ?column? | ?column? | ?column? | ?column? | ?column? | ?column?
----------+----------+----------+----------+----------+----------
       13 |        7 |       30 |        3 |        1 |     1000
```

| Operator | Meaning | Note |
|---|---|---|
| `+` `-` `*` | as expected | |
| `/` | division | **integer ÷ integer = integer, truncated** |
| `%` | modulo (remainder) | `10 % 3` = 1 |
| `^` | exponentiation | `10 ^ 3` = 1000 |

⚠️ **Trap** — `10 / 3` is `3`. Not 3.33. Not 4. PostgreSQL sees two integers,
so it does integer division and throws away the fraction. To get a decimal,
make at least one side non-integer:

```sql
SELECT 10 / 3, 10.0 / 3, 10::numeric / 3;
```

```
 ?column? |      ?column?      |      ?column?
----------+--------------------+--------------------
        3 | 3.3333333333333333 | 3.3333333333333333
```

This trap causes real financial bugs. `total_cents / 100` silently drops the
pennies. Remember it now; Day 14 drills it.

### Text

```sql
SELECT 'Hello' || ' ' || 'World';
```

```
  ?column?
-------------
 Hello World
```

`||` is concatenation. Not `+` (that's SQL Server) and not `.` (that's PHP).

⚠️ **Trap** — concatenating anything with `NULL` gives `NULL`:

```sql
SELECT 'Hello' || NULL;
```

```
 ?column?
----------

```

The whole thing vanishes. This is why a customer with no middle name can make
their entire full name disappear from a report. Day 9 explains why; Day 17
gives you `COALESCE` to fix it.

### Comparison

Comparison operators return **booleans**:

```sql
SELECT 5 > 3, 5 < 3, 5 = 5, 5 <> 3, 5 >= 5, 'apple' < 'banana';
```

```
 ?column? | ?column? | ?column? | ?column? | ?column? | ?column?
----------+----------+----------+----------+----------+----------
 t        | f        | t        | t        | t        | t
```

| Operator | Meaning |
|---|---|
| `=` | equal (**one** `=`, not `==`) |
| `<>` or `!=` | not equal (`<>` is standard; both work) |
| `<` `>` `<=` `>=` | ordering |

Two things worth noticing:

- `=` is a single equals sign. There is no `==` in SQL.
- Text compares alphabetically — `'apple' < 'banana'` is true. *How*
  alphabetically depends on the database's collation. Our practice database
  uses `C` collation, which compares by raw byte value, which means **all
  uppercase letters sort before all lowercase ones**. So `'Zebra' < 'apple'` is
  true. That surprises everyone; it's covered properly on Day 66.

These comparisons are the raw material of `WHERE`, which arrives on Day 7. It is
worth realising now that `WHERE price > 100` is not special syntax — it is just
the expression `price > 100` being evaluated to true or false for each row.

---

## Part 6 — Functions

A function takes arguments and returns a value. You call it with parentheses.

```sql
SELECT upper('hello'), lower('WORLD'), length('postgresql');
```

```
 upper | lower |  length
-------+-------+--------
 HELLO | world |     10
```

Notice the column names: when a value comes from a function, PostgreSQL names
the column after the function. That's nicer than `?column?`, and it's why
`SELECT version();` gave you a column called `version` yesterday.

A few to try now — you'll meet them all properly later:

```sql
SELECT abs(-42);              -- 42
SELECT round(3.7);            -- 4
SELECT current_date;          -- today
SELECT now();                 -- this instant, with timezone
SELECT random();              -- a number in [0,1)
SELECT repeat('ab', 3);       -- ababab
```

Some "functions" are called without parentheses — `current_date`,
`current_user`, `now` needs them, `current_timestamp` doesn't. These are SQL
standard oddities. Don't try to find a rule; there isn't a good one.

▶ **Try it** — run `SELECT random();` five times. Different answer each time.
Now run `SELECT random(), random();` — two different values in one row. Each
call is evaluated independently.

---

## Part 7 — Multiple rows without a table

One more thing `SELECT` can do without a table: produce many rows.

```sql
SELECT generate_series(1, 5);
```

```
 generate_series
-----------------
               1
               2
               3
               4
               5
(5 rows)
```

Five rows from nothing. `generate_series(start, stop)` produces every integer in
the range.

```sql
SELECT generate_series(0, 20, 5);
```

```
 generate_series
-----------------
               0
               5
              10
              15
              20
```

The third argument is the step.

This is not a toy. `generate_series` is how you build calendars with no missing
days (Day 43), how you generate five million test rows (Day 73), and how you
fill gaps in time-series reports (Day 112). Remember that it exists.

▶ **Try it** — `SELECT generate_series(1, 5) * 10;` — what happens? The
expression is applied to every generated row. You now have a five-row, one-column
result computed entirely from a function call.

---

## Traps & Gotchas

| # | Trap | The fix |
|---|---|---|
| 1 | `"double quotes"` for a text value | Use `'single quotes'`. Doubles are for identifiers. |
| 2 | `10 / 3` = `3` | Cast one side: `10::numeric / 3` |
| 3 | `3.7::integer` = `4` (rounds) | Use `trunc(3.7)` if you want 3 |
| 4 | `'a' || NULL` = `NULL` | `COALESCE` (Day 17) |
| 5 | Writing `==` for equality | SQL uses a single `=` |
| 6 | `'O'Connor'` breaks the parser | `'O''Connor'` or `$$O'Connor$$` |
| 7 | Assuming result rows have an order | They don't, until `ORDER BY` (Day 5) |
| 8 | Ambiguous date literals like `'03/15/2024'` | Always `'2024-03-15'` |

---

## Interview angles

- **Junior** — "Difference between single and double quotes in Postgres?"
  → Single = string literal; double = identifier.
- **Junior** — "What does `SELECT 1` do and why would anyone run it?"
  → Returns a one-row, one-column result. Used as a connection health check by
  every connection pool and load balancer in existence.
- **Mid** — "Why is `SELECT 10/3` equal to 3?"
  → Integer division. Both operands are `integer`, so the result type is
  `integer` and the fraction is truncated toward zero.
- **Mid** — "`numeric` vs `float8` for money?"
  → `numeric` — exact decimal arithmetic. `float8` is binary floating point;
  `0.1 + 0.2 <> 0.3`. Never store money in a float.
- **Senior** — "What's the `unknown` type?"
  → A quoted literal starts as `unknown` and gets resolved by context during
  type resolution. It's why `SELECT 'a' || 'b'` works but `pg_typeof('a')` says
  `unknown`. Occasionally it produces surprising function-overload resolution,
  fixed with an explicit cast.

---

## Practice

All of today's problems run with **no table**. Type every one.

### Section A — Drill (new concept only)

1. Return the number 100.
2. Return the text `PostgreSQL`.
3. Return three columns in one row: `1`, `'two'`, `true`.
4. Compute `17 + 25`.
5. Compute `144 / 12`.
6. Compute `144 / 13` — is the answer what you expected? Why?
7. Now compute `144 / 13` so that you get a decimal answer.
8. Compute the remainder of `144` divided by `13`.
9. Compute `2` raised to the power `10`.
10. Concatenate `'Post'` and `'greSQL'` into one value.
11. Concatenate `'Hello'`, a space, and `'World'` in one expression.
12. Return the text `It's fine` (note the apostrophe).
13. Return the same text using dollar quoting.
14. Convert the text `'2024'` to an integer.
15. Convert the integer `2024` to text.
16. Convert `'2024-07-04'` to a date.
17. Convert `9.99` to an integer. Is it 9 or 10? Why?
18. Find the data type of `100`.
19. Find the data type of `100.0`.
20. Find the data type of `true`.
21. Find the data type of `'2024-01-01'::date`.
22. Return `true` if 10 is greater than 7.
23. Return whether `'zebra'` is less than `'apple'`. Explain the result.
24. Return the uppercase form of `'postgres'`.
25. Return the length of `'international'`.
26. Return `NULL`.
27. Return the result of `'abc' || NULL`. What did you get?
28. Generate the numbers 1 through 10.
29. Generate the even numbers from 2 to 20.
30. Generate the numbers 10 down to 1. (Hint: a negative step.)

### Section B — Combination

31. In one row, return: the text `'Total:'`, the number `250`, and `250 * 0.2`.
32. Compute 20% of 250, as a decimal, and concatenate it onto the text
    `'VAT is '`.
33. Return `'The answer is 42'` by concatenating text with the *number* 42.
    (You will need a cast — why?)
34. Compute `(100 - 20) / 4` and then the same expression without parentheses.
    Explain the difference.
35. Return the length of the text form of the number `1234567`.
36. Return whether the length of `'postgresql'` is greater than 5.
37. Generate the numbers 1 to 5, and for each, return its square.
38. Generate the numbers 1 to 12 and return each multiplied by 100.
39. Build the text `'Row 1'`, `'Row 2'` … `'Row 5'` using `generate_series` and
    concatenation.
40. Compute the average of 10, 20 and 30 using only arithmetic — and get a
    decimal answer, not an integer.

### Section C — Recall (Day 01)

41. Without leaving `psql`, display which database you are connected to.
42. List all databases on the server.
43. Show the PostgreSQL version using SQL (not `psql --version`).
44. Show the server setting `max_connections`.
45. Get `psql`'s built-in help for the `SELECT` command.
46. Toggle expanded display on, run `SELECT 1, 2, 3;`, and toggle it off.
    What's different?
47. Deliberately write a query with a typo and read the caret in the error.
48. Recall your previous statement from history and re-run it.

### Section D — Challenge

49. Without running it, predict the output of:
    ```sql
    SELECT 7 / 2, 7 % 2, 7.0 / 2, 7 / 2.0, (7 / 2)::numeric, 7::numeric / 2;
    ```
    Then run it and check all six.
50. Predict, then check:
    ```sql
    SELECT 'a' || 'b' || NULL || 'c';
    ```
51. Why does `SELECT 'hello' = 'hello';` return `t`, but
    `SELECT NULL = NULL;` does **not** return `t`? Write down your guess.
    (Day 9 gives the real answer — guessing first is the point.)
52. Generate the numbers 1 to 100 and return only their total count using no
    aggregate function. (Hint: read the last line of `psql`'s output.)
53. `SELECT 0.1 + 0.2 = 0.3;` returns `t` in PostgreSQL but the equivalent is
    `false` in most programming languages. Why? (Hint: `pg_typeof(0.1)`.)
    Now make it return `f`.

---

## Solutions

**1.** `SELECT 100;`
**2.** `SELECT 'PostgreSQL';`
**3.** `SELECT 1, 'two', true;`
**4.** `SELECT 17 + 25;` → 42
**5.** `SELECT 144 / 12;` → 12
**6.** `SELECT 144 / 13;` → **11**, not 11.08. Both operands are `integer`, so
integer division truncates the fraction.
**7.** `SELECT 144::numeric / 13;` → `11.0769...`. `144.0 / 13` also works.
**8.** `SELECT 144 % 13;` → 1
**9.** `SELECT 2 ^ 10;` → 1024
**10.** `SELECT 'Post' || 'greSQL';`
**11.** `SELECT 'Hello' || ' ' || 'World';`
**12.** `SELECT 'It''s fine';`
**13.** `SELECT $$It's fine$$;`
**14.** `SELECT '2024'::integer;`
**15.** `SELECT 2024::text;`
**16.** `SELECT '2024-07-04'::date;`
**17.** `SELECT 9.99::integer;` → **10**. Casting to an integer type rounds to
nearest. Use `trunc(9.99)` → `9` if you want truncation.
**18.** `SELECT pg_typeof(100);` → `integer`
**19.** `SELECT pg_typeof(100.0);` → `numeric`
**20.** `SELECT pg_typeof(true);` → `boolean`
**21.** `SELECT pg_typeof('2024-01-01'::date);` → `date`
**22.** `SELECT 10 > 7;` → `t`
**23.** `SELECT 'zebra' < 'apple';` → `f`. Both start lowercase, and `z` comes
after `a`, so `'zebra'` is greater. (Try `SELECT 'Zebra' < 'apple';` — under the
`C` collation this database uses, that one is **true**, because uppercase `Z`
(byte 90) sorts before lowercase `a` (byte 97). Day 66.)
**24.** `SELECT upper('postgres');`
**25.** `SELECT length('international');` → 13
**26.** `SELECT NULL;`
**27.** `SELECT 'abc' || NULL;` → NULL (blank). Any concatenation involving
NULL is NULL.
**28.** `SELECT generate_series(1, 10);`
**29.** `SELECT generate_series(2, 20, 2);`
**30.** `SELECT generate_series(10, 1, -1);`

**31.** `SELECT 'Total:', 250, 250 * 0.2;` → `Total: | 250 | 50.0`
**32.** `SELECT 'VAT is ' || (250 * 0.2);` → `VAT is 50.0`. PostgreSQL casts
the numeric to text automatically for `||` when one side is already text.
**33.** `SELECT 'The answer is ' || 42;` actually works — `||` accepts a
non-text operand when the other side is text. The explicit version is
`SELECT 'The answer is ' || 42::text;`. The explicit cast is safer habit: if
*both* sides were non-text, `||` would be ambiguous.
**34.** `(100 - 20) / 4` = 20. `100 - 20 / 4` = `100 - 5` = 95. `/` binds
tighter than `-`. Precedence rules are the subject of Day 8; the lesson today
is: when in doubt, use parentheses. Nobody has ever been criticised in code
review for over-parenthesising a formula.
**35.** `SELECT length(1234567::text);` → 7
**36.** `SELECT length('postgresql') > 5;` → `t`
**37.** `SELECT generate_series(1,5) ^ 2;` → 1, 4, 9, 16, 25
**38.** `SELECT generate_series(1,12) * 100;`
**39.** `SELECT 'Row ' || generate_series(1,5);`
**40.** `SELECT (10 + 20 + 30)::numeric / 3;` → 20. Here `60 / 3` happens to be
exact, so you'd get 20 either way — but the cast is the habit that saves you
when the numbers aren't so tidy. Try `(10 + 20 + 31)::numeric / 3`.

**41.** `\conninfo`
**42.** `\l`
**43.** `SELECT version();`
**44.** `SHOW max_connections;`
**45.** `\h SELECT`
**46.** `\x` then the query: each column prints on its own line, as
`?column? | 1` etc. Invaluable for wide rows from Day 3 onwards.
**47.** e.g. `SELCT 1;` — note the `^` under `SELCT`.
**48.** ↑ then Enter.

**49.**
```
 7 / 2            → 3          integer division
 7 % 2            → 1          remainder
 7.0 / 2          → 3.5        numeric / integer → numeric
 7 / 2.0          → 3.5        integer / numeric → numeric
 (7 / 2)::numeric → 3.0        division happened FIRST, in integers — the cast
                               came too late. This is the bug.
 7::numeric / 2   → 3.5        cast BEFORE dividing — this is the fix.
```
The fifth and sixth are the whole lesson. Cast the *operand*, not the *result*.

**50.** `NULL`. One NULL anywhere in a chain of `||` poisons the entire result.

**51.** `NULL = NULL` returns `NULL`, not true. NULL means "unknown value", and
two unknowns can't be shown to be equal — so the answer is itself unknown. This
is three-valued logic, and it is Day 9. The practical consequence is that
`WHERE x = NULL` never matches anything, which silently returns zero rows
instead of erroring. It is the number one source of wrong query results in the
industry.

**52.** `SELECT generate_series(1, 100);` and read `(100 rows)` at the bottom.
The row count is part of the output. (Learning to read it is worth more than it
sounds — it is your fastest sanity check on every query you write.)

**53.** `pg_typeof(0.1)` is `numeric` — exact decimal, so `0.1 + 0.2` is exactly
`0.3` and the comparison is true. Force binary floating point and it breaks:
```sql
SELECT 0.1::float8 + 0.2::float8 = 0.3::float8;   -- f
```
This is the reason `numeric` is the correct type for money and `float8` is not.
A senior engineer should be able to produce this demonstration from memory.

---

## Day 02 Checklist

- [ ] I can explain what a table is in four properties
- [ ] I know rows have no guaranteed order
- [ ] I can `SELECT` literals and expressions with no `FROM`
- [ ] I know single quotes are data and double quotes are names
- [ ] I can write a string containing an apostrophe, two ways
- [ ] I know `10 / 3` is `3` and I know how to fix it
- [ ] I can cast with `::` and with `CAST()`
- [ ] I know `||` concatenates, and that `NULL` poisons it
- [ ] I know `=` is a single equals sign
- [ ] I can use `generate_series` to produce rows from nothing
- [ ] I added at least one line to `mistakes.md`

---

## What's next

**Day 03 — Build the practice database & `SELECT ... FROM`.** You install the
nine-table `shopdb` database you'll use for the next 113 days, and you learn the
one piece that was missing today: where the rows come from.
