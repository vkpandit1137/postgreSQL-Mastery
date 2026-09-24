-- ============================================================================
-- 00_create_database.sql
-- Creates the practice database used by every day of this program.
--
-- HOW TO RUN (from your operating system shell, NOT from inside psql):
--     psql -U postgres -f 00_create_database.sql
--
-- Or, from inside psql connected to any database:
--     \i 00_create_database.sql
--
-- You do NOT need to understand this file yet. It is taught on Day 53.
-- (See RULES.md → R4, "The Sandbox Exception".)
-- ============================================================================

-- Drop it if a previous attempt left one behind. Harmless on a fresh machine.
DROP DATABASE IF EXISTS shopdb;

CREATE DATABASE shopdb
    ENCODING   'UTF8'
    TEMPLATE   template0
    LC_COLLATE 'C'
    LC_CTYPE   'C';

COMMENT ON DATABASE shopdb IS
    'Practice database for the PostgreSQL Zero-to-Senior program.';

-- ============================================================================
-- NEXT STEPS
--   \c shopdb
--   \i 01_schema.sql
--   \i 02_data.sql
-- ============================================================================
