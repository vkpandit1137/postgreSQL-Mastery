# Day 11 — `LIKE`, `ILIKE` and Pattern Matching

> **Phase** 2 · Filtering & Expressions
> **Level** Absolute Beginner
> **Time** 100–130 minutes
> **Prerequisites** Days 01–10
> **New concepts** `LIKE` · `%` and `_` wildcards · `ILIKE` · `NOT LIKE` · `ESCAPE` · `SIMILAR TO` · `~` `~*` `!~` regex operators · leading-wildcard index implications · `LIKE` vs `=`

---

## Why this matters

Everything you have matched so far has been exact: `= 'delivered'`,
`IN ('gold','platinum')`. Real questions are fuzzier — *"products with 'laptop'
in the name"*, *"customers on a gmail address"*, *"orders whose reference starts
with INV-2024"*.

`LIKE` is the tool, and it is also your first meeting with a theme that runs
through the rest of the program: **some `WHERE` clauses can use an index and
some cannot**, and pattern matching is where the line gets drawn. You cannot act
on that until Day 74, but today is where you learn to notice it.

---

## Part 1 — `LIKE` and the two wildcards

```sql
SELECT product_name
FROM   products
WHERE  product_name LIKE 'Laptop%';
```

```
  product_name
---------------
 Laptop Pro 14
 Laptop Air 13
 Laptop Stand
(3 rows)
```

Two wildcards, and only two:

| Wildcard | Matches |
|---|---|
| `%` | **any sequence** of characters, including none |
| `_` | **exactly one** character |

| Pattern | Means |
|---|---|
| `'Laptop%'` | starts with `Laptop` |
| `'%Laptop'` | ends with `Laptop` |
| `'%Laptop%'` | contains `Laptop` anywhere |
| `'Laptop'` | equals exactly `Laptop` (no wildcards = same as `=`) |
| `'L_ptop%'` | `L`, any one character, then `ptop`, then anything |
| `'____'` | exactly four characters |

Note the difference between the first and third:

```sql
SELECT count(*) FROM products WHERE product_name LIKE 'Laptop%';   -- 3
SELECT count(*) FROM products WHERE product_name LIKE '%Laptop%';  -- 4
```

The fourth is `Budget Laptop 15` — it *contains* "Laptop" but does not *start*
with it.

▶ **Try it** — run both and find the extra row yourself.

### `_` — exactly one character

```sql
SELECT first_name FROM customers WHERE first_name LIKE '_a%';
```

Eight rows: Rajesh, James, Marie, Carlos, Daniel, Laura, Fatima, Hannah —
every first name whose **second** letter is `a`.

```sql
SELECT product_name FROM products WHERE product_name LIKE 'Tablet 1_';
```

One row: `Tablet 10`. The `_` matches the `0`, and only one character.

### `%` matches nothing, too

```sql
SELECT 'abc' LIKE 'abc%';    -- true — % matched zero characters
SELECT 'abc' LIKE 'abc_';    -- false — _ requires exactly one
```

That asymmetry catches people. `%` is "zero or more"; `_` is "exactly one".

---

## Part 2 — `LIKE` is case-sensitive; `ILIKE` is not

```sql
SELECT count(*) FROM products WHERE product_name LIKE '%Phone%';   -- 1
SELECT count(*) FROM products WHERE product_name LIKE '%phone%';   -- 3
SELECT count(*) FROM products WHERE product_name ILIKE '%phone%';  -- 4
```

Three different answers to what a human would call the same question.

- `'%Phone%'` (capital P) → only `Old Phone 2020`.
- `'%phone%'` (lowercase) → `Smartphone X`, `Smartphone Mini`,
  `Noise Cancelling Headphones`.
- `ILIKE '%phone%'` → all four.

🐘 **`ILIKE` is PostgreSQL-only.** The portable equivalent is
`lower(col) LIKE lower(pattern)`. Both defeat a plain B-tree index in the same
way, so there is no performance reason to prefer one; use `ILIKE` in
Postgres-only code because it says what it means.

```sql
-- these three are equivalent
WHERE product_name ILIKE '%phone%'
WHERE lower(product_name) LIKE '%phone%'
WHERE product_name ~* 'phone'          -- regex, Part 6
```

⚠️ **Trap** — `ILIKE` handles ASCII case reliably. For non-ASCII text
(`'STRASSE'` vs `'straße'`, Turkish dotless `ı`) case folding depends on
collation and gets genuinely subtle. Day 66.

---

## Part 3 — `NOT LIKE`

```sql
SELECT product_name FROM products WHERE product_name NOT LIKE '%Laptop%';
```

21 rows — 25 minus the 4 that contain "Laptop".

⚠️ **Trap — the Day 9 rule applies here too.** `NOT LIKE` on a nullable column
silently drops the NULL rows:

```sql
SELECT count(*) FROM customers WHERE city LIKE '%a%';        --  ?
SELECT count(*) FROM customers WHERE city NOT LIKE '%a%';    --  ?
SELECT count(*) FROM customers WHERE city IS NULL;           --  2
```

Run all three. The first two will **not** sum to 24, because `NULL LIKE 'x'` is
`NULL`, and `NOT NULL` is still `NULL`. Same failure, new operator. By now this
should be the first thing you check whenever a column is nullable.

---

## Part 4 — Escaping `%` and `_`

What if you want to find a literal percent sign or underscore?

```sql
SELECT 'discount_pct' LIKE '%_pct';     -- true, but for the wrong reason
```

That `_` is a wildcard matching any single character, so this would also match
`'discountXpct'`. To match a **literal** underscore, escape it with a backslash:

```sql
SELECT 'discount_pct' LIKE '%\_pct';    -- true — literal underscore
SELECT 'discountXpct' LIKE '%\_pct';    -- false
```

The default escape character is `\`. You can choose another with `ESCAPE`, which
is useful when the pattern itself is full of backslashes:

```sql
SELECT 'a_b' LIKE 'a!_b' ESCAPE '!';    -- true
SELECT '50%' LIKE '%!%'  ESCAPE '!';    -- true
```

This matters most when the pattern is **user input**. A search box where someone
types `100%` will, unescaped, match far more than they expected — and a search
for `_` matches everything. Applications must escape user-supplied patterns
before interpolating them, exactly as they escape quotes.

🎯 **Interview** — "A user searches for `50%` and gets every row back. Why?"
→ `%` is a `LIKE` wildcard; the input was not escaped. This is a small cousin of
SQL injection: untrusted input reaching a place where it has syntactic meaning.

---

## Part 5 — Realistic patterns

```sql
-- email domain
SELECT first_name, email FROM customers WHERE email LIKE '%@example.com';

-- surnames ending in "son"
SELECT first_name, last_name FROM customers WHERE last_name LIKE '%son';
```

Two rows: James Wilson, Ingrid Nilsson.

```sql
-- German phone numbers
SELECT first_name, phone FROM customers WHERE phone LIKE '+49%';

-- employees whose email is on the shop domain
SELECT first_name, email FROM employees WHERE email LIKE '%@shop.example';

-- products whose name contains a digit... LIKE can't do this.
```

That last comment is the honest limitation: `LIKE` has no concept of character
classes. "Contains a digit", "starts with three letters then a dash", "is a
valid email shape" — none of those are expressible. That is what regular
expressions are for.

### Combining with everything so far

```sql
SELECT product_name, price, category_id
FROM   products
WHERE  product_name ILIKE '%laptop%'
  AND  stock_quantity > 0
  AND  price BETWEEN 500 AND 2000
ORDER  BY price DESC;
```

```sql
SELECT first_name, last_name, country, email
FROM   customers
WHERE  country IN ('Germany', 'France')
  AND  email LIKE '%@example.com'
  AND  phone IS NOT NULL
ORDER  BY last_name;
```

---

## Part 6 — Regular expressions 🐘

PostgreSQL has full POSIX regular expressions built in, via four operators:

| Operator | Means |
|---|---|
| `~` | matches regex, case-sensitive |
| `~*` | matches regex, case-insensitive |
| `!~` | does **not** match, case-sensitive |
| `!~*` | does **not** match, case-insensitive |

```sql
SELECT product_name FROM products WHERE product_name ~ '[0-9]';
```

Every product name containing a digit — `Laptop Pro 14`, `Laptop Air 13`,
`Budget Laptop 15`, `Old Phone 2020`, `Blender 500W`, `Tablet 10`. `LIKE`
cannot express this at all.

A starter vocabulary — enough to be useful today:

| Pattern | Matches |
|---|---|
| `.` | any single character |
| `*` | zero or more of the preceding |
| `+` | one or more of the preceding |
| `?` | zero or one of the preceding |
| `^` | start of string |
| `$` | end of string |
| `[0-9]` | any digit |
| `[A-Za-z]` | any letter |
| `[^0-9]` | any non-digit |
| `\d` `\s` `\w` | digit, whitespace, word character |
| `(a\|b)` | `a` or `b` |
| `{2,4}` | between 2 and 4 of the preceding |

```sql
-- names starting with a vowel
SELECT first_name FROM customers WHERE first_name ~ '^[AEIOU]';

-- names ending in a vowel
SELECT first_name FROM customers WHERE first_name ~ '[aeiou]$';

-- product names containing a 3- or 4-digit number
SELECT product_name FROM products WHERE product_name ~ '[0-9]{3,4}';

-- emails that look roughly valid
SELECT email FROM customers WHERE email ~ '^[^@]+@[^@]+\.[a-z]{2,}$';

-- phone numbers that are NOT German or Indian
SELECT phone FROM customers WHERE phone !~ '^\+(49|91)';
```

### `LIKE` vs `SIMILAR TO` vs regex

There is a third operator, `SIMILAR TO`, which is SQL-standard and sits
awkwardly between the other two:

```sql
SELECT product_name FROM products WHERE product_name SIMILAR TO 'Laptop%';
SELECT product_name FROM products WHERE product_name SIMILAR TO '%(Pro|Air)%';
```

It uses `%` and `_` like `LIKE`, plus `|`, `*`, `+`, `()` and `[]` from regex.

**Do not use it.** It is a hybrid that resembles both and is neither, it is
implemented by translating to a regex anyway, and almost nobody reads it
fluently. Use `LIKE` for simple patterns and `~` for complex ones. Recognise
`SIMILAR TO` when you inherit it; don't write it.

| Need | Use |
|---|---|
| starts with / ends with / contains | `LIKE` |
| the same, case-insensitively | `ILIKE` |
| character classes, anchors, alternation, repetition | `~` / `~*` |
| anything at all | **not** `SIMILAR TO` |

---

## Part 7 — The index conversation starts here

You cannot create an index until Day 74. But today you meet the rule that makes
pattern matching a performance topic.

A B-tree index stores values **in sorted order**, exactly like a dictionary.
That makes some questions cheap and others impossible:

| Pattern | Index usable? | Why |
|---|---|---|
| `LIKE 'Laptop%'` | ✅ yes | It's a prefix — a contiguous range in sort order |
| `LIKE '%Laptop'` | ❌ no | No known starting point; every row must be read |
| `LIKE '%Laptop%'` | ❌ no | Same |
| `ILIKE 'Laptop%'` | ❌ no | The stored value isn't case-folded |
| `~ '^Laptop'` | ✅ yes | An anchored regex is a prefix too |
| `~ 'Laptop'` | ❌ no | Unanchored |

The analogy: finding every word starting with "pre" in a dictionary is easy —
flip to P. Finding every word *containing* "pre" means reading all of it.

> **The leading-wildcard rule:** `LIKE '%anything'` cannot use an ordinary
> B-tree index. On a large table it is a full scan.

This is not a reason to avoid it — sometimes "contains" is the question you
have. It is a reason to *know* which of your queries do it. PostgreSQL has three
answers, all later in the program:

- **`pg_trgm`** — a trigram index that makes `LIKE '%foo%'` fast (Days 79, 103).
- **Full-text search** — the right tool for searching prose (Day 67).
- **Expression index** on `lower(col)` — makes `lower(col) LIKE 'x%'` indexable
  (Day 79).

💡 **Note** — a subtlety for Day 74: even `LIKE 'Laptop%'` only uses an index if
the column's collation supports it. Under a non-`C` collation you need an index
declared with `text_pattern_ops`. Our practice database uses `C` collation, so
this works out of the box.

🎯 **Interview** — "Why is `WHERE name LIKE '%smith%'` slow on ten million
rows?" → A leading wildcard means a B-tree index cannot be used, so it's a
sequential scan with a per-row pattern match. Fixes: a GIN index with `pg_trgm`,
or full-text search if the data is prose. Naming `pg_trgm` specifically is what
marks the answer as experienced.

---

## Traps & Gotchas

| # | Trap | What happens |
|---|---|---|
| 1 | `LIKE 'Phone%'` when data is `'phone'` | 0 rows. `LIKE` is case-sensitive. |
| 2 | `LIKE 'Laptop%'` when you meant "contains" | Misses `Budget Laptop 15` |
| 3 | `_` used where a literal underscore was meant | Matches any character |
| 4 | Unescaped user input containing `%` | Matches far too much |
| 5 | `NOT LIKE` on a nullable column | NULL rows silently dropped |
| 6 | `LIKE '%x%'` on a big table | Full scan; no B-tree index possible |
| 7 | `SIMILAR TO` | Confusing hybrid; use `LIKE` or `~` |
| 8 | `LIKE` with no wildcards | Just a slower `=` |
| 9 | Expecting `ILIKE` to handle all Unicode casing | Collation-dependent (Day 66) |

---

## Interview angles

- **Junior** — "Products with 'laptop' in the name, any case." →
  `WHERE product_name ILIKE '%laptop%'`
- **Junior** — "Difference between `%` and `_`?" → Any sequence (including
  empty) vs exactly one character.
- **Mid** — "Why is `LIKE '%foo%'` slow?" → Leading wildcard; no B-tree range.
- **Mid** — "How do you match a literal `%`?" → Escape it: `'\%'`, or
  `ESCAPE` with a chosen character.
- **Mid** — "`LIKE` vs `ILIKE` vs `~`?" → Simple patterns / case-insensitive
  simple patterns / full regex. `ILIKE` and unanchored regex are both
  unindexable by a plain B-tree.
- **Senior** — "Design search for a 50M-row product catalogue." → Discuss what
  "search" means: prefix (`text_pattern_ops` B-tree), substring (GIN +
  `pg_trgm`), natural language (`tsvector` + GIN, with ranking), fuzzy
  (`pg_trgm` similarity or `levenshtein`). Mention that the right answer often
  isn't Postgres at all once you need relevance tuning and facets — but that
  Postgres gets you a very long way. Days 67, 79, 103.

---

## Practice

> Available: everything from Days 1–10, plus `LIKE`, `ILIKE`, `NOT LIKE`,
> `ESCAPE`, `~`, `~*`, `!~`, `!~*`.

### Section A — Drill (new concept only)

1. Products whose name starts with `Laptop`.
2. Products whose name contains `Laptop` anywhere.
3. Products whose name ends with `15`.
4. Products whose name contains `phone`, case-sensitive.
5. Products whose name contains `phone`, case-insensitive.
6. Products whose name does **not** contain `Laptop`.
7. Products whose name starts with `S`.
8. Products whose name is exactly 9 characters long, using `_` only.
9. Products whose name has `a` as its second letter.
10. Customers whose first name starts with `A`.
11. Customers whose first name starts with `A`, `B` or `C` (one `LIKE` per
    letter, combined).
12. Customers whose last name ends with `son`.
13. Customers whose email ends with `@example.com`.
14. Customers whose phone starts with `+49`.
15. Customers whose city contains `o`, case-insensitive.
16. Employees whose email is on the `shop.example` domain.
17. Employees whose job title contains `Sales`.
18. Employees whose job title does **not** contain `Sales`.
19. Suppliers whose name contains `Global` or `Components`.
20. Suppliers whose contact email starts with `sales` or `orders`.
21. Reviews whose title contains `great`, case-insensitive.
22. Reviews whose body contains `battery`, case-insensitive.
23. Orders whose shipping city starts with `S`.
24. Show `'discount_pct' LIKE '%_pct'` and `'discount_pct' LIKE '%\_pct'`.
    Explain the difference.
25. Show `'50%' LIKE '%!%' ESCAPE '!'`.
26. Product names containing a digit, using a regex.
27. Customer first names starting with a vowel, using a regex.
28. Customer first names ending with a vowel, using a regex.
29. Product names containing a 3- or 4-digit number, using a regex.
30. Phone numbers that are **not** German (`+49`), using a regex.

### Section B — Combination (with Days 01–10)

31. In-stock products whose name contains `laptop` (any case), priced between
    500 and 2000, most expensive first.
32. Active customers in Germany or France whose email ends with
    `@example.com` and who have a phone number, ordered by last name.
33. Products in categories 9 or 10 whose name contains an `a`, showing the
    margin, best margin first.
34. Employees in Sales whose job title contains `Rep`, showing full name and
    salary, highest first.
35. Customers whose first name starts with a vowel **and** who have a loyalty
    tier.
36. Orders shipped to a city starting with `B`, placed in 2024, that were
    delivered.
37. Products whose name contains a digit and whose price is over 100.
38. Reviews with rating 4 or 5 whose title contains `great` or `excellent`,
    case-insensitive.
39. Customers with no city whose name starts with `M` or `N`.
40. Products not containing `Laptop`, in stock, priced under 100, cheapest
    first.
41. Distinct countries of customers whose email starts with the letter `a`.
42. The 5 most expensive products whose name contains a space.
43. Suppliers with no contact email **or** whose email contains `export`.
44. Employees whose first name and last name both start with the same letter.
    (Hint: a regex with a back-reference, or compare two `left()` calls — but
    `left()` is Day 13, so try the regex.)
45. Customers whose phone contains a `-` and whose country is not Germany.
46. Products whose name is longer than 20 characters and contains `Applications`
    or `Programmer`.
47. Count of customers whose city contains `a` (case-insensitive), the count
    whose city does not, and the count with no city. Do they sum to 24?
48. The cheapest in-stock product in each category whose name contains a letter
    `e` (`DISTINCT ON`).
49. Orders whose shipping country differs from the string `Germany` but whose
    shipping city starts with `B`.
50. Customers whose email local part (before the `@`) contains a dot, using a
    regex.

### Section C — Recall (Days 01–10)

51. Products in categories 3 or 4 priced between 200 and 1200.
52. Customers with no loyalty tier.
53. `5 NOT IN (1, 2, NULL)` — how many rows and why?
54. Employees with no commission, including them in a "not 0.040" query.
55. Payments in December 2024 using a half-open range.
56. `NULL IS DISTINCT FROM 1`.
57. The 3 most expensive in-stock products.
58. Distinct order statuses that are not `delivered`.
59. `NOT (price > 500)` on `products` — row count, and why not 20 if `price`
    were nullable?
60. Reset the database and verify the counts.

### Section D — Challenge

61. Write three counts for `city` and `LIKE '%a%'` that sum to 24, proving the
    partition needs the `IS NULL` branch.
62. A user types `100%` into a product search box, which your application
    interpolates into `WHERE product_name LIKE '%<input>%'`. Show what the
    resulting query matches, and write the escaped version that behaves
    correctly.
63. Find all products whose name contains a literal underscore. (There are
    none — write the query so it would work, and prove it returns 0 while a
    naive version returns something else.)
64. Using a regex, find customers whose phone number has exactly the shape
    `+CC-N...-N...` — a plus, two digits, a hyphen, digits, a hyphen, digits.
    Which rows fail to match, and why?
65. Explain, without running anything, which of these could use a B-tree index
    on `product_name` and which could not:
    ```sql
    WHERE product_name = 'Laptop Pro 14'
    WHERE product_name LIKE 'Laptop%'
    WHERE product_name LIKE '%Laptop'
    WHERE product_name ILIKE 'Laptop%'
    WHERE product_name ~ '^Laptop'
    WHERE product_name ~ 'Laptop'
    WHERE lower(product_name) LIKE 'laptop%'
    ```
66. `WHERE product_name LIKE 'Laptop'` returns how many rows? Why is writing
    `LIKE` with no wildcard a (mild) mistake?
67. Write the same query three ways — with `ILIKE`, with `lower() LIKE`, and
    with `~*` — and confirm all three return the same rows.
68. Find every customer whose first name and last name, concatenated, contains
    a double letter (e.g. `nn`, `ss`, `ll`). Use a regex with a back-reference.
69. You inherit a query using `SIMILAR TO '%(Pro|Air)%'`. Rewrite it with
    `LIKE` + `OR`, and again with a regex. Which of the three would you ship,
    and why?
70. Design question: the product search box must support substring matching on
    a 50-million-row catalogue. Sketch what you would do, naming the specific
    PostgreSQL features. You have not been taught any of them — name what you
    would go and read about.

---

## Solutions

### Section A

**1.** `SELECT product_name FROM products WHERE product_name LIKE 'Laptop%';` → 3
**2.** `... LIKE '%Laptop%';` → 4 (adds `Budget Laptop 15`)
**3.** `... LIKE '%15';` → 1 (`Budget Laptop 15`)
**4.** `... LIKE '%phone%';` → 3 (`Smartphone X`, `Smartphone Mini`,
`Noise Cancelling Headphones`)
**5.** `... ILIKE '%phone%';` → 4 (adds `Old Phone 2020`)
**6.** `... NOT LIKE '%Laptop%';` → 21
**7.** `... LIKE 'S%';` → 5 (`Smartphone X`, `Smartphone Mini`, `Standing Desk`,
`Smart Watch`, `SQL Performance Explained`)
**8.** `SELECT product_name FROM products WHERE product_name LIKE '_________';`
(nine underscores) → `Chef Knife`, `Tablet 10`. Count the underscores carefully;
this is a fiddly, honest demonstration of why `length()` (Day 13) is better.
**9.** `... LIKE '_a%';` → `Tablet 10`, `Laptop Pro 14`, `Laptop Air 13`,
`Laptop Stand`. Run it.
**10.** `SELECT first_name FROM customers WHERE first_name LIKE 'A%';` → 3
(Anna, Ahmed, Arjun)
**11.** `... WHERE first_name LIKE 'A%' OR first_name LIKE 'B%' OR first_name LIKE 'C%';`
→ Anna, Ahmed, Arjun, Carlos, Chloe. (A regex is nicer: `~ '^[ABC]'`.)
**12.** `SELECT first_name, last_name FROM customers WHERE last_name LIKE '%son';`
→ 2 (Wilson, Nilsson)
**13.** `SELECT email FROM customers WHERE email LIKE '%@example.com';` → 24
**14.** `SELECT first_name, phone FROM customers WHERE phone LIKE '+49%';` → 3
(Anna, Tom, Lucas — Hannah has no phone)
**15.** `SELECT city FROM customers WHERE city ILIKE '%o%';`
**16.** `SELECT email FROM employees WHERE email LIKE '%@shop.example';` → 12
**17.** `SELECT job_title FROM employees WHERE job_title LIKE '%Sales%';` → 5
**18.** `... NOT LIKE '%Sales%';` → 7
**19.** `SELECT supplier_name FROM suppliers WHERE supplier_name LIKE '%Global%' OR supplier_name LIKE '%Components%';` → 2
**20.** `SELECT contact_email FROM suppliers WHERE contact_email LIKE 'sales%' OR contact_email LIKE 'orders%';` → 2
**21.** `SELECT title FROM reviews WHERE title ILIKE '%great%';`
**22.** `SELECT body FROM reviews WHERE body ILIKE '%battery%';` → 3
**23.** `SELECT DISTINCT shipping_city FROM orders WHERE shipping_city LIKE 'S%';`
→ Shanghai, Sao Paulo, Stockholm.
**24.**
```sql
SELECT 'discount_pct' LIKE '%_pct'  AS unescaped,   -- t
       'discount_pct' LIKE '%\_pct' AS escaped,     -- t
       'discountXpct' LIKE '%_pct'  AS unescaped2,  -- t  ← the problem
       'discountXpct' LIKE '%\_pct' AS escaped2;    -- f
```
Unescaped, `_` matches *any* character, so `discountXpct` matches too.
**25.** `SELECT '50%' LIKE '%!%' ESCAPE '!';` → `t`
**26.** `SELECT product_name FROM products WHERE product_name ~ '[0-9]';` → 6
**27.** `SELECT first_name FROM customers WHERE first_name ~ '^[AEIOU]';`
→ Anna, Emily, Olivia, Ahmed, Ingrid, Arjun.
**28.** `SELECT first_name FROM customers WHERE first_name ~ '[aeiou]$';`
**29.** `SELECT product_name FROM products WHERE product_name ~ '[0-9]{3,4}';`
→ `Old Phone 2020`, `Blender 500W`.
**30.** `SELECT phone FROM customers WHERE phone !~ '^\+49';` → 16 rows (the 19
with a phone, minus the 3 German ones). Note the NULL-phone customers are
excluded — `NULL !~ x` is `NULL`.

### Section B

**31.**
```sql
SELECT product_name, price FROM products
WHERE  product_name ILIKE '%laptop%'
  AND  stock_quantity > 0
  AND  price BETWEEN 500 AND 2000
ORDER  BY price DESC;
```
**32.**
```sql
SELECT first_name, last_name, country, email FROM customers
WHERE  is_active
  AND  country IN ('Germany','France')
  AND  email LIKE '%@example.com'
  AND  phone IS NOT NULL
ORDER  BY last_name;
```
**33.**
```sql
SELECT product_name, price - cost AS margin FROM products
WHERE  category_id IN (9,10) AND product_name LIKE '%a%'
ORDER  BY margin DESC;
```
**34.**
```sql
SELECT first_name || ' ' || last_name AS full_name, salary FROM employees
WHERE  department = 'Sales' AND job_title LIKE '%Rep%'
ORDER  BY salary DESC;
```
**35.** `SELECT * FROM customers WHERE first_name ~ '^[AEIOU]' AND loyalty_tier IS NOT NULL;`
**36.**
```sql
SELECT * FROM orders
WHERE  shipping_city LIKE 'B%'
  AND  order_date BETWEEN DATE '2024-01-01' AND DATE '2024-12-31'
  AND  status = 'delivered';
```
**37.** `SELECT product_name, price FROM products WHERE product_name ~ '[0-9]' AND price > 100;`
**38.**
```sql
SELECT * FROM reviews
WHERE  rating IN (4,5)
  AND  (title ILIKE '%great%' OR title ILIKE '%excellent%');
```
**39.** `SELECT * FROM customers WHERE city IS NULL AND (first_name LIKE 'M%' OR first_name LIKE 'N%');`
→ Marie Dubois, Nina Petrova. Both of them.
**40.**
```sql
SELECT product_name, price FROM products
WHERE  product_name NOT LIKE '%Laptop%' AND stock_quantity > 0 AND price < 100
ORDER  BY price;
```
**41.** `SELECT DISTINCT country FROM customers WHERE email LIKE 'a%';`
→ Germany (anna), Egypt (ahmed), India (arjun).
**42.** `SELECT product_name, price FROM products WHERE product_name LIKE '% %' ORDER BY price DESC LIMIT 5;`
**43.** `SELECT * FROM suppliers WHERE contact_email IS NULL OR contact_email LIKE '%export%';` → 2
**44.**
```sql
SELECT first_name, last_name FROM customers
WHERE  first_name || ' ' || last_name ~ '^(.)\w* \1';
```
This is case-sensitive, so it finds pairs sharing an exact initial. Run it and
check. A more forgiving version uses `~*`. The `\1` is a back-reference to the
first captured group — a genuinely useful regex feature that `LIKE` cannot
touch.
**45.** `SELECT * FROM customers WHERE phone LIKE '%-%' AND country <> 'Germany';`
**46.**
```sql
SELECT product_name FROM products
WHERE  length(product_name) > 20
  AND  (product_name LIKE '%Applications%' OR product_name LIKE '%Programmer%');
```
**47.**
```sql
SELECT count(*) FROM customers WHERE city ILIKE '%a%';
SELECT count(*) FROM customers WHERE city NOT ILIKE '%a%';
SELECT count(*) FROM customers WHERE city IS NULL;      -- 2
```
The first two sum to 22; adding the third gives 24. Same lesson as Days 9 and
10, third operator.
**48.**
```sql
SELECT DISTINCT ON (category_id) category_id, product_name, price
FROM   products
WHERE  stock_quantity > 0 AND product_name ILIKE '%e%'
ORDER  BY category_id, price;
```
**49.** `SELECT * FROM orders WHERE shipping_country <> 'Germany' AND shipping_city LIKE 'B%';`
**50.** `SELECT email FROM customers WHERE email ~ '^[^@]*\.[^@]*@';` → all 24,
since every seeded email is `first.last@example.com`.

### Section C

**51.** `SELECT * FROM products WHERE category_id IN (3,4) AND price BETWEEN 200 AND 1200;`
**52.** `SELECT * FROM customers WHERE loyalty_tier IS NULL;` → 4
**53.** 0 rows. `FALSE OR UNKNOWN = UNKNOWN`, then `NOT UNKNOWN = UNKNOWN`.
**54.** `SELECT * FROM employees WHERE commission_pct IS DISTINCT FROM 0.040;` → 10
**55.** `SELECT count(*) FROM payments WHERE paid_at >= '2024-12-01' AND paid_at < '2025-01-01';`
**56.** `t`
**57.** `SELECT product_name, price FROM products WHERE stock_quantity > 0 ORDER BY price DESC LIMIT 3;`
**58.** `SELECT DISTINCT status FROM orders WHERE status <> 'delivered' ORDER BY status;`
**59.** 20 rows. If `price` were nullable, rows with `price IS NULL` would give
`UNKNOWN` for `price > 500`, and `NOT UNKNOWN` is `UNKNOWN` — so they would be
dropped and the count would be lower than 20.
**60.** `\i 99_reset.sql`

### Section D

**61.** See B47. The three branches are `ILIKE '%a%'`, `NOT ILIKE '%a%'` and
`IS NULL`, summing to 24. Two branches alone give 22.

**62.** Naive:
```sql
SELECT product_name FROM products WHERE product_name LIKE '%100%%';
```
The user's `%` becomes a wildcard, so the pattern is `%100%%` — effectively
"contains 100", and the trailing `%%` matches anything. If the user had typed
just `%`, the pattern would be `%%%` and **every row** would match.

Escaped:
```sql
SELECT product_name FROM products WHERE product_name LIKE '%100\%%';
```
In application code, escape `%`, `_` and `\` in the user input before
interpolation, or use a parameter with a pre-escaped value. Treat `LIKE`
patterns as a small language that untrusted input must not be allowed to write.

**63.**
```sql
SELECT product_name FROM products WHERE product_name LIKE '%\_%';   -- 0 rows
SELECT product_name FROM products WHERE product_name LIKE '%_%';    -- 25 rows
```
The naive version matches every product whose name is at least one character
long — i.e. all of them — because `_` is "any single character". The escaped
version correctly finds none, because no product name contains a literal
underscore.

**64.**
```sql
SELECT first_name, phone FROM customers
WHERE  phone ~ '^\+[0-9]{2}-[0-9]+-[0-9]+$';
```
Rows that fail: the five customers with `phone IS NULL` (the comparison is
`UNKNOWN`), plus any number whose country code is not exactly two digits —
`+1-416-5551234` (one digit), `+353-1-6677889` and `+420-2-99887755` and
`+254-20-334455` and `+971-4-3344556` (three digits). That is the useful lesson:
real phone numbers do not have a fixed shape, and regexes that assume one
quietly exclude whole countries. Validating phone numbers with a regex is a
classic mistake; use a library, or store what the user typed.

**65.**

| Clause | Index usable? |
|---|---|
| `= 'Laptop Pro 14'` | ✅ exact match, single point in the index |
| `LIKE 'Laptop%'` | ✅ prefix = contiguous range |
| `LIKE '%Laptop'` | ❌ leading wildcard |
| `ILIKE 'Laptop%'` | ❌ index holds original case, not folded |
| `~ '^Laptop'` | ✅ anchored regex is a prefix |
| `~ 'Laptop'` | ❌ unanchored |
| `lower(product_name) LIKE 'laptop%'` | ❌ **unless** an expression index on `lower(product_name)` exists |

The last row is the important one: the fix for case-insensitive prefix search is
an index on the *expression you actually query*. Day 79.

**66.** `SELECT count(*) FROM products WHERE product_name LIKE 'Laptop';` → **0**.
No product is named exactly `Laptop`. `LIKE` with no wildcards is just `=` with
extra ceremony — it works, but it misleads the reader into thinking a pattern is
intended, and it may prevent some planner optimisations. Write `=` when you mean
equality.

**67.**
```sql
SELECT product_name FROM products WHERE product_name ILIKE '%laptop%';
SELECT product_name FROM products WHERE lower(product_name) LIKE '%laptop%';
SELECT product_name FROM products WHERE product_name ~* 'laptop';
```
All three → the same 4 rows. All three are unindexable by a plain B-tree.

**68.**
```sql
SELECT first_name, last_name FROM customers
WHERE  first_name || last_name ~ '(.)\1';
```
`(.)` captures any character and `\1` requires the same character immediately
after — a doubled letter. Matches include `Anna` (nn), `Nilsson` (ss),
`O'Connor` (nn), `Al-Sayed`? no. Run it and read the list.

**69.**
```sql
-- inherited
WHERE product_name SIMILAR TO '%(Pro|Air)%'
-- LIKE + OR
WHERE product_name LIKE '%Pro%' OR product_name LIKE '%Air%'
-- regex
WHERE product_name ~ '(Pro|Air)'
```
All three return `Laptop Pro 14` and `Laptop Air 13`.

Ship the **regex**. It is the most widely understood of the three, it is the
most expressive if the condition grows, and unlike `SIMILAR TO` every reader
will know what it does. The `LIKE + OR` version is acceptable and becomes
unwieldy past three alternatives. `SIMILAR TO` is the one to retire, because it
looks like `LIKE` while behaving like a regex, which is the worst combination.

**70.** Sketch, naming what to go and read:

1. **Decide what "search" means.** Prefix ("lap…" → "Laptop") and substring
   ("…top…") and natural-language ("cheap fast laptop") are three different
   problems with three different solutions. Ask the product owner before
   choosing.
2. **Prefix search** → a B-tree index on `product_name`, declared with
   `text_pattern_ops` if the database uses a non-`C` collation. Supports
   `LIKE 'lap%'` and `~ '^lap'`. → *Day 74, Day 79.*
3. **Substring search** → the `pg_trgm` extension plus a **GIN** index on
   `product_name gin_trgm_ops`. This makes `LIKE '%top%'` and `ILIKE` fast, and
   also enables fuzzy matching via the `%` similarity operator and
   `similarity()`. → *Day 79, Day 103.*
4. **Natural-language search** → a `tsvector` column (ideally a **generated**
   column so it can never drift), a GIN index on it, and `websearch_to_tsquery`
   for user input, with `ts_rank` for ordering. → *Day 67, Day 71.*
5. **Know the limit.** Once you need relevance tuning, synonyms, facets and
   typo tolerance across tens of millions of documents, a dedicated search
   engine is the right tool. Postgres gets you remarkably far — often all the
   way — and the honest senior answer says both parts. → *Day 108.*

Writing this list down now, before you know any of it, is deliberate. When you
reach Day 67 and Day 79 you will already know *why* you are there.

---

## Day 11 Checklist

- [ ] I know `%` is "any sequence" and `_` is "exactly one character"
- [ ] I know `LIKE` is case-sensitive and `ILIKE` is not
- [ ] I can write starts-with, ends-with and contains patterns
- [ ] I know `NOT LIKE` drops NULL rows, like every other negation
- [ ] I can escape a literal `%` or `_`, and I know why user input must be escaped
- [ ] I can use `~`, `~*`, `!~` and a basic regex vocabulary
- [ ] I know why `SIMILAR TO` should be read but not written
- [ ] **I know a leading wildcard prevents a B-tree index from being used**
- [ ] I can name `pg_trgm` and full-text search as the two real fixes

---

## What's next

**Day 12 — ✅ Checkpoint 2.** No new material. Seventy mixed problems across
Days 7–11: filtering, boolean logic, `NULL`, `IN`/`BETWEEN` and pattern
matching. Pass mark 49/70.
