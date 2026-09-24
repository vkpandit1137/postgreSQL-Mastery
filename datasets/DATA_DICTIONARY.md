# DATA_DICTIONARY.md — the `shopdb` practice database

Keep this file open in a second window for the whole program. Every example and
every practice problem in all 115 days runs against these nine tables.

---

## Schema map

```
                      ┌──────────────┐
                      │  categories  │◄──┐ parent_category_id
                      └──────┬───────┘   │ (self-reference)
                             │           │
                             └───────────┘
                             ▲
                             │ category_id
   ┌───────────┐      ┌──────┴───────┐
   │ suppliers │◄─────┤   products   │◄──────────┐
   └───────────┘      └──────┬───────┘           │ product_id
                             │                   │
                             │ product_id  ┌─────┴──────┐
                             ▼             │  reviews   │
                      ┌──────────────┐     └─────┬──────┘
                      │ order_items  │           │ customer_id
                      └──────┬───────┘           │
                             │ order_id          │
                             ▼                   │
   ┌───────────┐      ┌──────────────┐     ┌─────▼──────┐
   │ employees │◄─────┤    orders    ├────►│ customers  │
   └─────┬─────┘      └──────┬───────┘     └────────────┘
         │ manager_id        │ order_id
         │ (self-reference)  ▼
         └──────────►  ┌──────────────┐
                       │   payments   │
                       └──────────────┘
```

**Relationship types you will meet**

| Relationship | Type | Where |
|---|---|---|
| category → parent category | 1:N, self-referencing | `categories.parent_category_id` |
| employee → manager | 1:N, self-referencing | `employees.manager_id` |
| supplier → products | 1:N | `products.supplier_id` |
| category → products | 1:N | `products.category_id` |
| customer → orders | 1:N | `orders.customer_id` |
| employee → orders | 1:N (optional) | `orders.employee_id` |
| order → order_items | 1:N | `order_items.order_id` |
| product → order_items | 1:N | `order_items.product_id` |
| order ↔ product | **M:N**, via `order_items` | — |
| order → payments | 1:N | `payments.order_id` |
| product → reviews | 1:N | `reviews.product_id` |
| customer → reviews | 1:N | `reviews.customer_id` |

---

## Tables

### `categories` — 10 rows
A tree. Top-level categories have `parent_category_id IS NULL`.

| Column | Type | Null? | Notes |
|---|---|---|---|
| `category_id` | integer | no | primary key |
| `category_name` | text | no | unique |
| `parent_category_id` | integer | **yes** | → `categories.category_id`; NULL = root |
| `description` | text | yes | |

Roots: Electronics (1), Home & Living (5), Books (8).

---

### `suppliers` — 6 rows

| Column | Type | Null? | Notes |
|---|---|---|---|
| `supplier_id` | integer | no | primary key |
| `supplier_name` | text | no | |
| `country` | text | yes | |
| `contact_email` | text | **yes** | supplier 3 has none |
| `rating` | numeric(2,1) | yes | 0.0 – 5.0 |
| `active_since` | date | yes | |

---

### `products` — 25 rows

| Column | Type | Null? | Notes |
|---|---|---|---|
| `product_id` | integer | no | primary key |
| `product_name` | text | no | |
| `category_id` | integer | yes | → `categories` |
| `supplier_id` | integer | **yes** | product 25 has no supplier |
| `price` | numeric(10,2) | no | what the customer pays |
| `cost` | numeric(10,2) | yes | what we pay; `price - cost` = margin |
| `stock_quantity` | integer | no | 0 for products 3, 6, 16, 25 |
| `weight_kg` | numeric(6,3) | yes | |
| `is_discontinued` | boolean | no | true for products 6 and 25 |
| `added_on` | date | no | 2020-05-01 .. 2023-10-05 |

Never ordered: **6, 16, 25**. Price range: 29.99 – 1899.00.

---

### `customers` — 24 rows

| Column | Type | Null? | Notes |
|---|---|---|---|
| `customer_id` | integer | no | primary key |
| `first_name`, `last_name` | text | no | note `O''Connor` (customer 19) — an embedded apostrophe |
| `email` | text | no | unique |
| `phone` | text | **yes** | 5 customers have none |
| `city` | text | **yes** | customers 7 and 18 have none |
| `country` | text | no | 19 distinct countries |
| `signup_date` | date | no | 2022-08-17 .. 2025-04-05 |
| `birth_date` | date | **yes** | customers 4 and 13 have none |
| `loyalty_tier` | text | **yes** | `bronze`/`silver`/`gold`/`platinum`, or NULL |
| `is_active` | boolean | no | false for customers 8 and 15 |

**No orders at all:** customers **13, 18, 22, 23**.

---

### `employees` — 12 rows
A hierarchy, 3 levels deep.

| Column | Type | Null? | Notes |
|---|---|---|---|
| `employee_id` | integer | no | primary key |
| `first_name`, `last_name` | text | no | note `O''Brien` (employee 12) |
| `email` | text | no | unique |
| `manager_id` | integer | **yes** | → `employees`; NULL only for employee 1 (the CEO) |
| `department` | text | no | Management, Sales, Support, Warehouse |
| `job_title` | text | no | |
| `hire_date` | date | no | 2016-02-01 .. 2023-11-13 |
| `salary` | numeric(10,2) | no | 36,500 .. 185,000 |
| `commission_pct` | numeric(4,3) | **yes** | only Sales roles have one |

```
1 Sofia Lindqvist (CEO)
├── 2 Marcus Webb (Sales Director)
│   ├── 5 Tom Becker
│   ├── 6 Lucia Moretti
│   ├── 7 Omar Haddad
│   └── 12 Liam O'Brien
├── 3 Aiko Tanaka (Support Lead)
│   ├── 8 Grace Okafor
│   └── 9 Ivan Petrov
└── 4 Priya Nair (Warehouse Manager)
    ├── 10 Chen Wei
    └── 11 Fatima Zahra
```

---

### `orders` — 60 rows

| Column | Type | Null? | Notes |
|---|---|---|---|
| `order_id` | integer | no | primary key |
| `customer_id` | integer | no | → `customers` |
| `employee_id` | integer | **yes** | NULL for self-service orders (5, 14, 22, 24, 35, 43) |
| `order_date` | date | no | 2024-01-08 .. 2025-07-07 |
| `status` | text | no | `pending`, `paid`, `shipped`, `delivered`, `cancelled`, `returned` |
| `shipping_city` | text | yes | |
| `shipping_country` | text | yes | may differ from the customer's country |
| `shipping_cost` | numeric(8,2) | no | 0.00 .. 13.00 |

Status counts: delivered 47, cancelled 3, pending 3, shipped 3, paid 2, returned 2.

> ⚠️ **There is no `total_amount` column on `orders`.** This is deliberate. An
> order's value is computed from its `order_items`. You will write that
> calculation dozens of times, and by Day 34 it will be automatic.

---

### `order_items` — 105 rows

| Column | Type | Null? | Notes |
|---|---|---|---|
| `order_item_id` | integer | no | primary key |
| `order_id` | integer | no | → `orders` |
| `product_id` | integer | no | → `products` |
| `quantity` | integer | no | 1 .. 3 |
| `unit_price` | numeric(10,2) | no | price **at the time of sale** (may differ from `products.price`) |
| `discount_pct` | numeric(4,3) | no | 0.000 .. 0.100 |

`UNIQUE (order_id, product_id)` — a product appears at most once per order.

**The line-total formula, used constantly from Day 14 onwards:**

```sql
quantity * unit_price * (1 - discount_pct)
```

---

### `payments` — 56 rows

| Column | Type | Null? | Notes |
|---|---|---|---|
| `payment_id` | integer | no | primary key |
| `order_id` | integer | no | → `orders` |
| `paid_at` | timestamptz | no | stored in UTC |
| `amount` | numeric(10,2) | no | |
| `method` | text | no | `card`, `paypal`, `bank_transfer`, `gift_card`, `cash_on_delivery` |
| `status` | text | no | `captured`, `refunded`, `failed` |

Orders 8 and 23 have **two** rows each: one `captured`, one `refunded`.
Orders 4, 14, 35 (cancelled) and 58, 59, 60 (pending) have **no** payment.

---

### `reviews` — 36 rows

| Column | Type | Null? | Notes |
|---|---|---|---|
| `review_id` | integer | no | primary key |
| `product_id` | integer | no | → `products` |
| `customer_id` | integer | no | → `customers` |
| `rating` | integer | no | 1 .. 5 |
| `title`, `body` | text | yes | |
| `created_at` | timestamptz | no | |
| `helpful_votes` | integer | no | 4 .. 88 |

`UNIQUE (product_id, customer_id)` — one review per customer per product.
Only 17 of the 25 products have any review at all.

---

## Facts worth memorising (you will use them to sanity-check answers)

| Question | Answer |
|---|---|
| Rows in `customers` | 24 |
| Rows in `products` | 25 |
| Rows in `orders` | 60 |
| Rows in `order_items` | 105 |
| Rows in `payments` | 56 |
| Rows in `reviews` | 36 |
| Rows in `employees` | 12 |
| Customers with zero orders | 4 |
| Products never ordered | 3 |
| Employees with no manager | 1 |
| Distinct countries in `customers` | 19 |
| Date range of `orders` | 2024-01-08 → 2025-07-07 |

> 💡 If a query returns 24 rows when you expected 60, you have almost certainly
> joined in the wrong direction. Knowing the row counts by heart turns silent
> wrong answers into obvious ones.

---

## Resetting

Broke something? Good — that means you were experimenting.

```
\i 99_reset.sql
```

This drops and rebuilds every table and reloads the seed data. It takes about a
second. Use it without guilt.
