-- ============================================================================
-- 99_reset.sql  —  Put the practice database back to a known-good state.
--
-- Run it from inside psql while connected to shopdb:
--     \i 99_reset.sql
--
-- Safe to run as often as you like. Everything you added, changed or deleted
-- in the nine practice tables is wiped and the seed data is reloaded.
--
-- It does NOT drop anything you created outside those nine tables (your own
-- practice tables, views, functions). Drop those yourself if you want a
-- completely clean database.
--
-- `\ir` means "include, relative to the directory this script lives in", so
-- this works no matter which directory you launched psql from.
-- ============================================================================

\echo 'Resetting shopdb ...'

\ir 01_schema.sql
\ir 02_data.sql

\echo ''
\echo 'Reset complete. Expected row counts:'

SELECT 'categories'  AS table_name, count(*) AS rows FROM categories
UNION ALL SELECT 'suppliers',   count(*) FROM suppliers
UNION ALL SELECT 'products',    count(*) FROM products
UNION ALL SELECT 'customers',   count(*) FROM customers
UNION ALL SELECT 'employees',   count(*) FROM employees
UNION ALL SELECT 'orders',      count(*) FROM orders
UNION ALL SELECT 'order_items', count(*) FROM order_items
UNION ALL SELECT 'payments',    count(*) FROM payments
UNION ALL SELECT 'reviews',     count(*) FROM reviews
ORDER BY table_name;

-- Expected:
--   categories   10
--   customers    24
--   employees    12
--   order_items 105
--   orders       60
--   payments     56
--   products     25
--   reviews      36
--   suppliers     6
