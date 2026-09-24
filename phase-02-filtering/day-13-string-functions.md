# Day 13 — String Functions

> **Phase** 2 · Filtering & Expressions
> **Level** Absolute Beginner
> **Time** 110–140 minutes
> **Prerequisites** Days 01–12
> **New concepts** `length` · `upper`/`lower`/`initcap` · `trim`/`ltrim`/`rtrim`/`btrim` · `substring`/`substr` · `position`/`strpos` · `left`/`right` · `replace` · `split_part` · `lpad`/`rpad` · `concat`/`concat_ws` · `repeat`/`reverse` · `starts_with` · `regexp_replace` · 1-based indexing · NULL-safe concatenation

---

## Why this matters

Data arrives messy. Names have stray spaces, emails need their domain
extracted, phone numbers need reformatting, report columns need padding to line
up. Every one of those is a string function.

Today also hands you the first real answer to a problem you've had since Day 4:
`concat_ws` concatenates while **ignoring NULLs**, so a customer with no city
stops vanishing from your output.

---

## Part 1 — SQL strings are 1-indexed

Before anything else, the rule that trips up every programmer:

```sql
SELECT substring('PostgreSQL' FROM 1 FOR 4);   -- 'Post'
```

**The first character is position 1, not 0.** Every string function in SQL —
`substring`, `position`, `left`, `right` — counts from 1. If you come from
Python, Java, C or JavaScript, you will get this wrong at least twice today.

```sql
SELECT position('S' IN 'PostgreSQL');          -- 9, not 8
```

---

## Part 2 — Length and case

```sql
SELECT length('PostgreSQL'),
       upper('postgres'),
       lower('POSTGRES'),
       initcap('hello world postgres');
```

```
 length | upper    | lower    |      initcap
--------+----------+----------+---------------------
     10 | POSTGRES | postgres | Hello World Postgres
```

| Function | Does |
|---|---|
| `length(s)` | number of **characters** (not bytes) |
| `upper(s)` | uppercase |
| `lower(s)` | lowercase |
| `initcap(s)` | Capitalises The First Letter Of Each Word |

On real data:

```sql
SELECT product_name, length(product_name) AS len
FROM   products
ORDER  BY len DESC
LIMIT  3;
```

```
             product_name             | len
--------------------------------------+-----
 Designing Data-Intensive Applications |  37
 Noise Cancelling Headphones           |  27
 SQL Performance Explained             |  25
```

⚠️ **Trap** — `length()` counts characters; `octet_length()` counts bytes. For
ASCII they agree. For anything else they don't:

```sql
SELECT length('café'), octet_length('café');   -- 4, 5
```

The `é` is two bytes in UTF-8. When a `varchar(50)` column rejects a string that
"is only 40 characters", this is usually why — except that in PostgreSQL
`varchar(n)` counts *characters*, so it isn't. It's why in **other** databases.
Know both functions exist.

⚠️ **Trap** — `initcap` is naive. `initcap('o''connor')` gives `O'Connor`
(correct by luck) but `initcap('MCDONALD')` gives `Mcdonald` and
`initcap('van der berg')` gives `Van Der Berg`. Never use it to "fix"人 names.
Store what the user typed.

---

## Part 3 — Trimming whitespace

```sql
SELECT '[' || '  hello  '         || ']' AS original,
       '[' || trim('  hello  ')   || ']' AS trimmed,
       '[' || ltrim('  hello  ')  || ']' AS left_trimmed,
       '[' || rtrim('  hello  ')  || ']' AS right_trimmed;
```

```
 original   | trimmed  | left_trimmed | right_trimmed
------------+----------+--------------+---------------
 [  hello  ]| [hello]  | [hello  ]    | [  hello]
```

Wrapping in brackets to make whitespace visible is a habit worth keeping — you
cannot debug what you cannot see.

Trimming other characters:

```sql
SELECT trim(BOTH '0' FROM '000123000');       -- '123'
SELECT trim(LEADING '0' FROM '000123000');    -- '123000'
SELECT trim(TRAILING '0' FROM '000123000');   -- '000123'
SELECT btrim('xxhelloxx', 'x');               -- 'hello'
```

`btrim(s, chars)` is the shorthand form of `trim(BOTH chars FROM s)`.

💡 **Where this actually matters:** trailing whitespace from a CSV import or a
web form is invisible and breaks every `=` comparison. `WHERE email = 'a@b.com'`
finds nothing when the stored value is `'a@b.com '`. If you ever have a
"the value is right there and the query can't find it" bug, check for whitespace
first:

```sql
SELECT '[' || email || ']' FROM customers WHERE customer_id = 1;
```

---

## Part 4 — Extracting parts of a string

### `substring`

Two spellings, same function:

```sql
SELECT substring('PostgreSQL' FROM 5 FOR 3);   -- 'gre'   (SQL standard)
SELECT substr('PostgreSQL', 5, 3);             -- 'gre'   (shorthand)
```

`FROM` is the start position (1-based), `FOR` is the length. Omit `FOR` to take
everything to the end:

```sql
SELECT substring('PostgreSQL' FROM 5);         -- 'greSQL'
```

### `left` and `right`

```sql
SELECT left('PostgreSQL', 4),    -- 'Post'
       right('PostgreSQL', 3);   -- 'SQL'
```

Negative arguments mean "all but the last/first n":

```sql
SELECT left('PostgreSQL', -3),   -- 'Postgre'  (all but last 3)
       right('PostgreSQL', -4);  -- 'greSQL'   (all but first 4)
```

### `position` / `strpos`

```sql
SELECT position('SQL' IN 'PostgreSQL'),   -- 8
       strpos('PostgreSQL', 'SQL');       -- 8
```

Returns **0** when not found — not `NULL`, and not `-1`:

```sql
SELECT position('xyz' IN 'PostgreSQL');   -- 0
```

That's the check for "does this contain that", though `LIKE '%SQL%'` reads
better.

### Putting them together: extracting an email domain

```sql
SELECT email,
       substring(email FROM position('@' IN email) + 1) AS domain
FROM   customers
LIMIT  3;
```

```
            email             |   domain
------------------------------+-------------
 anna.mueller@example.com     | example.com
 rajesh.kumar@example.com     | example.com
 emily.carter@example.com     | example.com
```

Readable? Barely. There is a much better tool.

---

## Part 5 — `split_part` 🐘

```sql
SELECT split_part('anna.mueller@example.com', '@', 1);   -- 'anna.mueller'
SELECT split_part('anna.mueller@example.com', '@', 2);   -- 'example.com'
```

`split_part(string, delimiter, n)` splits on the delimiter and returns the
**n-th** field, 1-based. The email-domain query becomes:

```sql
SELECT email, split_part(email, '@', 2) AS domain FROM customers;
```

This is one of the most useful functions in PostgreSQL. It handles the common
90% of "parse this delimited value" work in one call.

```sql
SELECT phone, split_part(phone, '-', 1) AS country_code
FROM   customers
WHERE  phone IS NOT NULL;
```

```sql
-- first name from a full name
SELECT split_part('Anna Muller', ' ', 1);    -- 'Anna'
SELECT split_part('Anna Muller', ' ', 2);    -- 'Muller'
```

Out-of-range requests return an **empty string**, not NULL and not an error:

```sql
SELECT split_part('a-b', '-', 5);            -- '' (empty)
SELECT length(split_part('a-b', '-', 5));    -- 0
```

Negative `n` counts from the end (PostgreSQL 14+):

```sql
SELECT split_part('a.b.c.d', '.', -1);       -- 'd'
```

---

## Part 6 — `replace` and `translate`

```sql
SELECT replace('2024-01-15', '-', '/');      -- '2024/01/15'
SELECT replace('hello world', 'o', '0');     -- 'hell0 w0rld'
```

`replace` swaps every occurrence of a **substring**.

`translate` maps characters one-for-one:

```sql
SELECT translate('+49-30-1234567', '+-', '');   -- '49301234567'
```

Here `+` and `-` map to nothing and are deleted. Useful for stripping formatting
from phone numbers and card numbers.

```sql
SELECT phone, translate(phone, '+- ', '') AS digits_only
FROM   customers
WHERE  phone IS NOT NULL
LIMIT  5;
```

For anything more complex, use `regexp_replace`:

```sql
SELECT regexp_replace('+49-30-1234567', '[^0-9]', '', 'g');   -- '49301234567'
```

The fourth argument `'g'` means **global** — replace all matches, not just the
first. Forgetting the `'g'` is the most common `regexp_replace` mistake:

```sql
SELECT regexp_replace('a1b2c3', '[0-9]', '', 'g');   -- 'abc'
SELECT regexp_replace('a1b2c3', '[0-9]', '');        -- 'ab2c3'  ← only the first
```

---

## Part 7 — Building strings

### `concat` and `concat_ws` — the NULL fix

You have used `||` since Day 4, and you know its flaw: one `NULL` destroys the
whole string. Two functions behave differently:

```sql
SELECT 'Anna' || NULL || 'Muller'          AS pipes,       -- NULL
       concat('Anna', NULL, 'Muller')      AS concat,      -- 'AnnaMuller'
       concat_ws(' ', 'Anna', NULL, 'Muller') AS concat_ws;-- 'Anna Muller'
```

```
 pipes | concat     | concat_ws
-------+------------+-------------
 ␀     | AnnaMuller | Anna Muller
```

| Function | NULL handling | Separator |
|---|---|---|
| `\|\|` | one NULL → whole result NULL | none |
| `concat(...)` | NULLs treated as empty string | none |
| `concat_ws(sep, ...)` | NULLs **skipped entirely** | yes |

**`concat_ws` is the one you want**, and the distinction is subtle but real:
`concat` turns a NULL into `''` and *still emits the separator around it*;
`concat_ws` drops the argument altogether so you don't get a doubled separator.

Apply it to the query that has been broken since Day 4:

```sql
SELECT first_name,
       city,
       first_name || ' lives in ' || city          AS broken,
       concat_ws(', ', first_name, city)           AS fixed
FROM   customers
WHERE  city IS NULL;
```

```
 first_name | city | broken |  fixed
------------+------+--------+---------
 Marie      | ␀    | ␀      | Marie
 Nina       | ␀    | ␀      | Nina
```

The `fixed` column keeps the part that *is* known. That is almost always what a
human wants.

⚠️ **Trap** — `concat_ws` skips NULLs but **not** empty strings:

```sql
SELECT concat_ws(', ', 'a', NULL, 'b');   -- 'a, b'
SELECT concat_ws(', ', 'a', '',   'b');   -- 'a, , b'   ← doubled separator
```

One more reason to store missing data as `NULL` rather than `''`.

💡 `concat` and `concat_ws` also cast their arguments automatically, so
`concat('Order #', 42)` works without an explicit `::text`.

### `lpad`, `rpad`, `repeat`, `reverse`

```sql
SELECT lpad('42', 6, '0'),        -- '000042'
       rpad('abc', 6, '.'),       -- 'abc...'
       repeat('-', 20),           -- '--------------------'
       reverse('PostgreSQL');     -- 'LQSergtsoP'
```

`lpad` is how you build zero-padded reference numbers:

```sql
SELECT 'ORD-' || lpad(order_id::text, 6, '0') AS reference
FROM   orders
LIMIT  3;
```

```
  reference
-------------
 ORD-000001
 ORD-000002
 ORD-000003
```

⚠️ **Trap** — `lpad` **truncates** if the string is longer than the target:

```sql
SELECT lpad('1234567', 4, '0');   -- '1234'  ← silently lost three digits
```

That is a genuinely dangerous behaviour for identifiers. Size your padding
generously.

### `starts_with`

```sql
SELECT starts_with('PostgreSQL', 'Post');   -- true
```

Equivalent to `LIKE 'Post%'`, but it takes a plain string rather than a
pattern — so user input needs no escaping. Use it when the prefix comes from
outside.

---

## Part 8 — String functions in `WHERE`

Everything today works in a `WHERE` clause:

```sql
SELECT email FROM customers WHERE split_part(email, '@', 2) = 'example.com';

SELECT product_name FROM products WHERE length(product_name) > 25;

SELECT first_name FROM customers WHERE lower(first_name) = 'anna';

SELECT phone FROM customers WHERE length(translate(phone, '+- ', '')) > 11;
```

⚠️ **The performance note, again.** Wrapping a column in a function makes a
plain B-tree index on that column **unusable**:

```sql
WHERE email = 'anna.mueller@example.com'            -- ✅ index usable
WHERE lower(email) = 'anna.mueller@example.com'     -- ❌ not usable
WHERE split_part(email, '@', 2) = 'example.com'     -- ❌ not usable
```

The index stores `email`; it does not store `lower(email)`. The fix is an
**expression index** — `CREATE INDEX ON customers (lower(email))` — which is
Day 79. For now, notice when you're doing it.

🎯 **Interview** — "Why is `WHERE lower(email) = $1` slow?" → The function makes
the predicate non-sargable; a B-tree on `email` can't be used. Fix with an
expression index on `lower(email)`, or a `citext` column. Using the word
*sargable* (Search-ARGument-ABLE) is a good signal.

---

## Reference table

| Function | Example | Result |
|---|---|---|
| `length(s)` | `length('abc')` | `3` |
| `upper(s)` | `upper('abc')` | `ABC` |
| `lower(s)` | `lower('ABC')` | `abc` |
| `initcap(s)` | `initcap('a b')` | `A B` |
| `trim(s)` | `trim('  a  ')` | `a` |
| `btrim(s,c)` | `btrim('xax','x')` | `a` |
| `substring(s FROM a FOR b)` | `substring('abcdef' FROM 2 FOR 3)` | `bcd` |
| `left(s,n)` | `left('abcdef',2)` | `ab` |
| `right(s,n)` | `right('abcdef',2)` | `ef` |
| `position(x IN s)` | `position('c' IN 'abc')` | `3` |
| `strpos(s,x)` | `strpos('abc','c')` | `3` |
| `replace(s,from,to)` | `replace('a-b','-','+')` | `a+b` |
| `translate(s,from,to)` | `translate('abc','ab','xy')` | `xyc` |
| `split_part(s,d,n)` | `split_part('a-b','-',2)` | `b` |
| `lpad(s,n,c)` | `lpad('7',3,'0')` | `007` |
| `rpad(s,n,c)` | `rpad('7',3,'0')` | `700` |
| `repeat(s,n)` | `repeat('ab',2)` | `abab` |
| `reverse(s)` | `reverse('abc')` | `cba` |
| `concat(...)` | `concat('a',NULL,'b')` | `ab` |
| `concat_ws(sep,...)` | `concat_ws('-','a',NULL,'b')` | `a-b` |
| `starts_with(s,p)` | `starts_with('abc','ab')` | `true` |
| `regexp_replace(s,p,r,'g')` | `regexp_replace('a1b','[0-9]','','g')` | `ab` |
| `md5(s)` | `md5('abc')` | 32-char hash |

---

## Traps & Gotchas

| # | Trap | What happens |
|---|---|---|
| 1 | Assuming 0-based indexing | Off by one everywhere |
| 2 | `\|\|` with a nullable column | Whole string becomes NULL — use `concat_ws` |
| 3 | `position` returns 0 when not found | Not `NULL`, not `-1` |
| 4 | `regexp_replace` without `'g'` | Only the first match is replaced |
| 5 | `lpad` with too small a length | Silently truncates |
| 6 | `length` vs `octet_length` | Characters vs bytes |
| 7 | `initcap` on real names | `Mcdonald`, `Van Der Berg` |
| 8 | Function on a column in `WHERE` | Kills B-tree index usage |
| 9 | `concat_ws` with `''` arguments | Doubled separators — `''` is not NULL |
| 10 | Invisible trailing whitespace | `=` fails mysteriously |

---

## Interview angles

- **Junior** — "Extract the domain from an email." →
  `split_part(email, '@', 2)`
- **Junior** — "Is `substring` 0- or 1-based in SQL?" → 1-based.
- **Mid** — "Concatenate three columns where any may be NULL." →
  `concat_ws(' ', a, b, c)`. Explain why `||` fails.
- **Mid** — "Why is `WHERE upper(name) = 'X'` slow?" → Non-sargable; needs an
  expression index.
- **Senior** — "Store emails case-insensitively — design options?" →
  (a) normalise to lowercase on write with a `CHECK (email = lower(email))`;
  (b) `citext` extension; (c) a unique expression index on `lower(email)`.
  Trade-offs: (a) is fastest and most explicit but requires application
  discipline; (b) is transparent but a non-core type; (c) keeps the original
  casing while enforcing uniqueness — usually the best answer. Days 66, 79.

---

## Practice

> Available: everything from Days 1–12 plus today's string functions.

### Section A — Drill (new concept only)

1. The length of `'PostgreSQL'`.
2. `'postgres'` in uppercase and `'POSTGRES'` in lowercase, in one row.
3. `initcap('the pragmatic programmer')`.
4. `trim('   spaced   ')`, wrapped in brackets so you can see it worked.
5. `ltrim` and `rtrim` of the same string, bracketed.
6. `btrim('000123000', '0')`.
7. Characters 5 to 7 of `'PostgreSQL'` using `substring ... FROM ... FOR`.
8. The same using `substr`.
9. The first 4 characters of `'PostgreSQL'`.
10. The last 3 characters of `'PostgreSQL'`.
11. The position of `'SQL'` in `'PostgreSQL'`.
12. The position of `'xyz'` in `'PostgreSQL'`. What do you get?
13. `replace('2024-01-15', '-', '/')`.
14. `translate('+49-30-123', '+-', '')`.
15. `regexp_replace('a1b2c3', '[0-9]', '', 'g')`.
16. The same without the `'g'` flag. Explain the difference.
17. `split_part('anna@example.com', '@', 1)` and `... 2)`.
18. `split_part('a-b-c', '-', 5)`. What do you get, and what is its length?
19. `lpad('42', 8, '0')`.
20. `rpad('abc', 8, '.')`, bracketed.
21. `repeat('=', 30)`.
22. `reverse('PostgreSQL')`.
23. `concat('a', NULL, 'b')`.
24. `concat_ws('-', 'a', NULL, 'b')`.
25. `'a' || NULL || 'b'`. Compare with 23 and 24.
26. `starts_with('PostgreSQL', 'Post')`.
27. `length('café')` and `octet_length('café')`. Explain.
28. `md5('postgres')`.
29. `lpad('1234567', 4, '0')`. What happened?
30. `concat_ws(', ', 'a', '', 'b')`. Compare with 24.

### Section B — Combination (with Days 01–12)

31. Every product's name and its length, longest first.
32. Every product's name in uppercase.
33. Every customer's email and its domain, using `split_part`.
34. Every customer's email local part (before the `@`).
35. Every customer's full name built with `concat_ws`, so nothing is lost.
36. Every customer's name and city joined with `', '`, using `concat_ws` —
    confirm the two city-less customers still appear with their name.
37. Every order's reference as `ORD-000001` style, using `lpad`.
38. Every product's name truncated to its first 15 characters.
39. Every customer's initials, e.g. `A.M.`, using `left`.
40. Every employee's email domain.
41. Every customer's phone with all `+`, `-` and spaces stripped.
42. Every customer's country code — the digits between `+` and the first `-`.
43. Products whose name is longer than 25 characters, showing the length.
44. Customers whose email domain is exactly `example.com`.
45. Customers whose lowercase first name is `anna`.
46. Products whose uppercase name contains `LAPTOP`.
47. Employees whose job title's first word is `Sales`, using `split_part`.
48. Customers whose phone, stripped of formatting, is longer than 11
    characters.
49. Products where the first character of the name is a letter after `M` in the
    alphabet, using `left`.
50. A single text column per product reading
    `Laptop Pro 14 ............ 1899.00`, with `rpad` to line the prices up at
    column 30.
51. Every employee as `LASTNAME, Firstname` — surname uppercased.
52. Every review's title with the word `great` replaced by `GREAT`,
    case-sensitive.
53. Distinct email domains among customers.
54. Distinct first letters of customer first names, sorted.
55. The 5 products whose name has the most words. (Hint: count spaces — compare
    `length` with `length` after removing spaces.)

### Section C — Recall (Days 01–12)

56. Products in categories 3 or 4 priced between 200 and 1200.
57. Customers with no city, including their country.
58. `NOT IN (1, 2, NULL)` on `supplier_id` — count and explanation.
59. Payments in October 2024, half-open range.
60. Employees whose commission is not 0.045, including those with none.
61. Products whose name contains `phone`, any case.
62. `true OR NULL` and `NOT NULL`.
63. The most expensive in-stock product in each category.
64. Distinct loyalty tiers — how many rows and why?
65. Reset the database and verify the counts.

### Section D — Challenge

66. Write a query returning each customer's name and city, where a missing city
    shows as the customer's name alone — with no trailing comma or separator.
67. Extract the top-level domain (`com`, `org`, …) from every customer email,
    two different ways.
68. Every customer's phone number reformatted from `+49-30-1234567` to
    `49 30 1234567` (spaces instead of the `+` and `-`).
69. Build a fixed-width report line for each product:
    name padded to 40 characters, then price right-aligned in 10 characters.
    Verify the columns line up by eye.
70. Find products whose name contains the same letter twice in a row, using a
    regex back-reference, and show the name with that doubled letter uppercased.
71. Without using `length()`, find the products whose name is exactly 10
    characters long.
72. `SELECT lpad('1234567', 4, '0');` silently truncates. Write a version that
    pads when short but leaves the value intact when long. (Hint: `greatest` —
    you've not met it, but guess what it does, then check with `\h` or the
    docs.)
73. Explain which of these could use a B-tree index on `customers(email)`:
    ```sql
    WHERE email = 'a@b.com'
    WHERE lower(email) = 'a@b.com'
    WHERE email LIKE 'a%'
    WHERE split_part(email, '@', 2) = 'b.com'
    WHERE starts_with(email, 'a')
    ```
74. You are handed a CSV import where some emails have trailing spaces. Write
    one query that finds every affected row, and one that shows what the value
    *should* be.
75. Design question: a `full_name` column contains `"Anna Muller"`. The product
    team wants to sort by surname. Give two approaches and say which you'd ship.

---

## Solutions

### Section A

**1.** `SELECT length('PostgreSQL');` → 10
**2.** `SELECT upper('postgres'), lower('POSTGRES');`
**3.** `SELECT initcap('the pragmatic programmer');` → `The Pragmatic Programmer`
**4.** `SELECT '[' || trim('   spaced   ') || ']';` → `[spaced]`
**5.** `SELECT '[' || ltrim('   spaced   ') || ']', '[' || rtrim('   spaced   ') || ']';`
**6.** `SELECT btrim('000123000', '0');` → `123`
**7.** `SELECT substring('PostgreSQL' FROM 5 FOR 3);` → `gre`
**8.** `SELECT substr('PostgreSQL', 5, 3);` → `gre`
**9.** `SELECT left('PostgreSQL', 4);` → `Post`
**10.** `SELECT right('PostgreSQL', 3);` → `SQL`
**11.** `SELECT position('SQL' IN 'PostgreSQL');` → 8
**12.** `SELECT position('xyz' IN 'PostgreSQL');` → **0**. Not NULL, not −1.
**13.** `SELECT replace('2024-01-15', '-', '/');` → `2024/01/15`
**14.** `SELECT translate('+49-30-123', '+-', '');` → `4930123`
**15.** `SELECT regexp_replace('a1b2c3', '[0-9]', '', 'g');` → `abc`
**16.** `SELECT regexp_replace('a1b2c3', '[0-9]', '');` → `ab2c3`. Without `'g'`
only the **first** match is replaced.
**17.** → `anna`, `example.com`
**18.** `SELECT split_part('a-b-c', '-', 5), length(split_part('a-b-c','-',5));`
→ empty string, length **0**. Not NULL, not an error.
**19.** `SELECT lpad('42', 8, '0');` → `00000042`
**20.** `SELECT '[' || rpad('abc', 8, '.') || ']';` → `[abc.....]`
**21.** `SELECT repeat('=', 30);`
**22.** `SELECT reverse('PostgreSQL');` → `LQSergtsoP`
**23.** `SELECT concat('a', NULL, 'b');` → `ab`
**24.** `SELECT concat_ws('-', 'a', NULL, 'b');` → `a-b`
**25.** `SELECT 'a' || NULL || 'b';` → `NULL`. Three functions, three different
NULL behaviours. This is the table to memorise.
**26.** `SELECT starts_with('PostgreSQL', 'Post');` → `t`
**27.** `SELECT length('café'), octet_length('café');` → 4, 5. `length` counts
characters; `é` is two bytes in UTF-8.
**28.** `SELECT md5('postgres');`
**29.** `SELECT lpad('1234567', 4, '0');` → `1234`. It **truncated** — three
digits silently gone. Dangerous for identifiers.
**30.** `SELECT concat_ws(', ', 'a', '', 'b');` → `a, , b`. `concat_ws` skips
NULL but not the empty string, so you get a doubled separator.

### Section B

**31.** `SELECT product_name, length(product_name) AS len FROM products ORDER BY len DESC;`
**32.** `SELECT upper(product_name) FROM products;`
**33.** `SELECT email, split_part(email, '@', 2) AS domain FROM customers;`
**34.** `SELECT split_part(email, '@', 1) AS local_part FROM customers;`
**35.** `SELECT concat_ws(' ', first_name, last_name) AS full_name FROM customers;`
**36.**
```sql
SELECT customer_id, concat_ws(', ', first_name, city) AS label
FROM   customers WHERE city IS NULL;
```
→ `Marie`, `Nina` — the name survives, which `||` could not manage.
**37.** `SELECT 'ORD-' || lpad(order_id::text, 6, '0') AS reference FROM orders;`
**38.** `SELECT left(product_name, 15) FROM products;`
**39.**
```sql
SELECT left(first_name,1) || '.' || left(last_name,1) || '.' AS initials
FROM   customers;
```
**40.** `SELECT split_part(email, '@', 2) FROM employees;` → all `shop.example`
**41.** `SELECT phone, translate(phone, '+- ', '') AS digits FROM customers;`
(NULL phones stay NULL — `translate(NULL, ...)` is NULL.)
**42.** `SELECT phone, split_part(translate(phone, '+', ''), '-', 1) AS cc FROM customers WHERE phone IS NOT NULL;`
**43.** `SELECT product_name, length(product_name) FROM products WHERE length(product_name) > 25;`
**44.** `SELECT email FROM customers WHERE split_part(email, '@', 2) = 'example.com';` → 24
**45.** `SELECT * FROM customers WHERE lower(first_name) = 'anna';` → 1
**46.** `SELECT product_name FROM products WHERE upper(product_name) LIKE '%LAPTOP%';` → 4
**47.** `SELECT job_title FROM employees WHERE split_part(job_title, ' ', 1) = 'Sales';` → 2
(`Sales Director`, `Sales Rep`… check: `Senior Sales Rep` starts with `Senior`,
`Junior Sales Rep` with `Junior`. So 2.) A nice demonstration that "first word"
and "contains" are different questions.
**48.** `SELECT phone FROM customers WHERE length(translate(phone, '+- ', '')) > 11;`
**49.** `SELECT product_name FROM products WHERE left(product_name, 1) > 'M';`
**50.**
```sql
SELECT rpad(product_name, 30, '.') || lpad(price::text, 8, ' ') AS line
FROM   products;
```
**51.**
```sql
SELECT upper(last_name) || ', ' || first_name AS name FROM employees;
```
**52.** `SELECT replace(title, 'great', 'GREAT') FROM reviews;`
**53.** `SELECT DISTINCT split_part(email, '@', 2) FROM customers;` → 1 row
**54.** `SELECT DISTINCT left(first_name, 1) AS initial FROM customers ORDER BY initial;`
**55.**
```sql
SELECT product_name,
       length(product_name) - length(replace(product_name, ' ', '')) + 1 AS words
FROM   products
ORDER  BY words DESC, product_name
LIMIT  5;
```
Counting a character by "length before minus length after removing it" is a
classic SQL idiom. Learn it; you will use it for commas, pipes and newlines too.

### Section C

**56.** `WHERE category_id IN (3,4) AND price BETWEEN 200 AND 1200;`
**57.** `SELECT first_name, last_name, country FROM customers WHERE city IS NULL;`
**58.** 0 rows — a `NULL` in the list makes every comparison `UNKNOWN`.
**59.** `WHERE paid_at >= '2024-10-01' AND paid_at < '2024-11-01';`
**60.** `WHERE commission_pct IS DISTINCT FROM 0.045;` → 11
**61.** `WHERE product_name ILIKE '%phone%';` → 4
**62.** `t`, `NULL`
**63.** `SELECT DISTINCT ON (category_id) category_id, product_name, price FROM products ORDER BY category_id, price DESC;`
**64.** 5 — four tiers plus NULL.
**65.** `\i 99_reset.sql`

### Section D

**66.**
```sql
SELECT customer_id, concat_ws(', ', first_name || ' ' || last_name, city) AS label
FROM   customers;
```
`concat_ws` drops the NULL `city` **and** its separator, so you get
`Marie Dubois` with no trailing comma. Note the inner `||` is safe here because
both names are `NOT NULL`.

**67.**
```sql
SELECT email, split_part(email, '.', -1)                     AS tld_a,
              split_part(split_part(email,'@',2), '.', -1)   AS tld_b
FROM   customers;
```
Method A is wrong in general — `anna.mueller@example.com` has dots in the local
part, and `split_part(..., '.', -1)` happens to still work because the TLD is
last. Method B is correct: take the domain first, *then* the last dot-segment.
The lesson: parse in the order the format is structured, not in the order that
happens to work on today's data.

**68.** `SELECT translate(phone, '+-', '  ') FROM customers WHERE phone IS NOT NULL;`
→ replaces `+` and `-` each with a space. (`translate` maps position-for-position,
so the `to` string must be the same length or shorter.)

**69.**
```sql
SELECT rpad(product_name, 40, ' ') || lpad(price::text, 10, ' ') AS line
FROM   products
ORDER  BY product_name;
```
Beware `Designing Data-Intensive Applications` at 37 characters — it fits. A
38-plus character name would be truncated by `rpad`, which is the same trap as
`lpad`.

**70.**
```sql
SELECT product_name FROM products WHERE product_name ~ '(.)\1';
```
→ e.g. `Noise Cancelling Headphones` (`ll`), `Office Chair` (`ff`),
`Bookshelf` (`oo`), `Coffee Maker` (`ff`, `ee`). Uppercasing just the doubled
letter needs `regexp_replace` with a back-reference in the replacement:
```sql
SELECT regexp_replace(product_name, '(.)\1', upper('\1') || '\1')
FROM   products WHERE product_name ~ '(.)\1';
```
…which does **not** work, because `upper('\1')` uppercases the literal string
`\1` before the regex ever runs. Doing this properly needs a function that can
transform a captured group, which SQL's `regexp_replace` cannot do directly —
you would need PL/pgSQL (Day 92). A worthwhile dead end: it teaches you that
replacement strings are literals, not expressions.

**71.** `SELECT product_name FROM products WHERE product_name LIKE '__________';`
(exactly ten underscores) → `Chef Knife`, `Tablet 10`. Correct but horrible;
`length(product_name) = 10` is the query you should actually write. The
exercise's point is that `_` counts characters, and that counting underscores by
eye is exactly the kind of thing computers should do.

**72.**
```sql
SELECT lpad('1234567', greatest(length('1234567'), 4), '0');   -- '1234567'
SELECT lpad('42',      greatest(length('42'), 4),      '0');   -- '0042'
```
`greatest(a, b)` returns the larger argument — you meet it formally on Day 17.
Using the greater of "desired width" and "actual length" makes `lpad` pad
without ever truncating.

**73.**

| Clause | Index on `email` usable? |
|---|---|
| `email = 'a@b.com'` | ✅ |
| `lower(email) = 'a@b.com'` | ❌ — needs an index on `lower(email)` |
| `email LIKE 'a%'` | ✅ — prefix range |
| `split_part(email,'@',2) = 'b.com'` | ❌ — needs an index on that expression |
| `starts_with(email, 'a')` | ❌ — not recognised as a range predicate |

That last one surprises people: `starts_with` is semantically a prefix match but
the planner does not rewrite it into a range the way it does for `LIKE 'a%'`.
Use `LIKE` when you want the index and the prefix is trusted.

**74.**
```sql
-- find affected rows
SELECT customer_id, '[' || email || ']' AS raw
FROM   customers
WHERE  email <> trim(email);

-- show the corrected value
SELECT customer_id, email AS current, trim(email) AS should_be
FROM   customers
WHERE  email <> trim(email);
```
`WHERE col <> trim(col)` is the general "find rows a cleanup would change"
pattern — the same shape as Day 7's `price <> price::integer`. In the practice
database it returns zero rows, which is the correct answer for clean data. The
`UPDATE` that fixes them is Day 60, and a `CHECK (email = trim(email))` that
prevents them is Day 55.

**75.** Two approaches:

**A. Parse at query time:** `ORDER BY split_part(full_name, ' ', 2)`.
Cheap to implement, no schema change. But it is wrong for `Anna van der Berg`
and `Michael O'Connor Jr`, it cannot use an index, and every consumer of the
data has to repeat the same fragile parsing.

**B. Store `first_name` and `last_name` separately** — which is what this
practice database does. Then `ORDER BY last_name` is correct, indexable and
obvious. The migration cost is real and one-off; the parsing cost is forever.

**Ship B.** The general principle: if you find yourself parsing the same column
in more than one query, the parsing belongs in the schema, not in the queries.
You'll meet this again on Day 63 as **First Normal Form** — a column should hold
one atomic value — and again on Day 107 as an anti-pattern.

The honest caveat, worth saying in an interview: *some* names genuinely do not
split into first and last, and a global product may be better served by a single
`display_name` plus a separate `sort_name`. There is no universally correct
answer, only a defensible one.

---

## Day 13 Checklist

- [ ] I know SQL strings are 1-indexed
- [ ] I can use `length`, `upper`, `lower`, `trim`
- [ ] I can extract substrings with `substring`, `left`, `right`, `split_part`
- [ ] I know `position` returns 0 when not found
- [ ] I know `regexp_replace` needs `'g'` to replace all matches
- [ ] **I know `\|\|`, `concat` and `concat_ws` handle NULL three different ways**
- [ ] I reach for `concat_ws` when any argument may be NULL
- [ ] I know `lpad` truncates when the target is too small
- [ ] I know a function around a column makes the predicate non-sargable
- [ ] I can find rows that a cleanup would change: `WHERE col <> f(col)`

---

## What's next

**Day 14 — Numeric types and math functions.** `integer` vs `numeric` vs
`float`, the rounding functions, and a proper treatment of the integer-division
trap you met on Day 2 — plus why money must never be stored in a float.
