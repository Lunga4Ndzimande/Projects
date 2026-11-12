-- =========================================================
-- KSYS-13042 Cleanup — REL
-- Host: ew1r-aggr-03.rel.kurtosys-internal.net
-- Database: UDM__
-- =========================================================

-- 1. SELECT — confirm tables exist
-- ---------------------------------------------------------
SELECT table_name
FROM information_schema.tables
WHERE table_name IN (
    'tmp_ksys13042_refs',
    'tmp_ksys13042_dangling',
    'tmp_ksys13042_migver',
    'tmp_ksys13042_prever',
    'tmp_ksys13042_oldrefs',
    'tmp_ksys13042_fix_plan'
);

-- Output:
-- table_name            |
-- -----------------------+
-- tmp_ksys13042_dangling|
-- tmp_ksys13042_fix_plan|
-- tmp_ksys13042_migver  |
-- tmp_ksys13042_oldrefs |
-- tmp_ksys13042_prever  |
-- tmp_ksys13042_refs    |

-- ---------------------------------------------------------
-- 2. COUNTS — row count per table (before drop)
-- ---------------------------------------------------------
SELECT 'tmp_ksys13042_refs' AS table_name, COUNT(*) AS row_count FROM tmp_ksys13042_refs
UNION ALL SELECT 'tmp_ksys13042_dangling', COUNT(*) FROM tmp_ksys13042_dangling
UNION ALL SELECT 'tmp_ksys13042_migver', COUNT(*) FROM tmp_ksys13042_migver
UNION ALL SELECT 'tmp_ksys13042_prever', COUNT(*) FROM tmp_ksys13042_prever
UNION ALL SELECT 'tmp_ksys13042_oldrefs', COUNT(*) FROM tmp_ksys13042_oldrefs
UNION ALL SELECT 'tmp_ksys13042_fix_plan', COUNT(*) FROM tmp_ksys13042_fix_plan
ORDER BY 1;

-- Output:
-- table_name            |row_count|
-- -----------------------+---------+
-- tmp_ksys13042_refs    |      671|
-- tmp_ksys13042_dangling|      302|
-- tmp_ksys13042_migver  |        8|
-- tmp_ksys13042_prever  |        8|
-- tmp_ksys13042_oldrefs |       18|
-- tmp_ksys13042_fix_plan|       18|

-- ---------------------------------------------------------
-- 3. BACKUP — all tables (run in terminal, not as SQL)
-- ---------------------------------------------------------
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_refs > tmp_ksys13042_refs.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_dangling > tmp_ksys13042_dangling.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_migver > tmp_ksys13042_migver.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_prever > tmp_ksys13042_prever.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_oldrefs > tmp_ksys13042_oldrefs.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_fix_plan > tmp_ksys13042_fix_plan.sql

-- Output:
--

-- ---------------------------------------------------------
-- 4. DELETION — all tables
-- ---------------------------------------------------------
DROP TABLE IF EXISTS tmp_ksys13042_refs;
DROP TABLE IF EXISTS tmp_ksys13042_dangling;
DROP TABLE IF EXISTS tmp_ksys13042_migver;
DROP TABLE IF EXISTS tmp_ksys13042_prever;
DROP TABLE IF EXISTS tmp_ksys13042_oldrefs;
DROP TABLE IF EXISTS tmp_ksys13042_fix_plan;

-- =========================================================
-- KSYS-13042 Cleanup — US
-- Host: (REPLACE_WITH_ENDPOINT)
-- Database: UDM__
-- =========================================================

-- 1. SELECT — confirm tables exist
-- ---------------------------------------------------------
SELECT table_name
FROM information_schema.tables
WHERE table_name IN (
    'tmp_pre_ksys13042_refs',
    'tmp_pre_ksys13042_dangling',
    'tmp_pre_ksys13042_migver',
    'tmp_pre_ksys13042_prever',
    'tmp_pre_ksys13042_oldrefs',
    'tmp_pre_ksys13042_fix_plan',
    'tmp_ksys13042_refs',
    'tmp_ksys13042_dangling',
    'tmp_ksys13042_migver',
    'tmp_ksys13042_prever',
    'tmp_ksys13042_oldrefs',
    'tmp_ksys13042_fix_plan',
    'ksys13042_applied'
);

-- Output:
-- table_name                |
-- ----------------------------+
-- ksys13042_applied         |
-- tmp_ksys13042_dangling    |
-- tmp_ksys13042_fix_plan    |
-- tmp_ksys13042_migver      |
-- tmp_ksys13042_oldrefs     |
-- tmp_ksys13042_prever      |
-- tmp_ksys13042_refs        |
-- tmp_pre_ksys13042_dangling|
-- tmp_pre_ksys13042_fix_plan|
-- tmp_pre_ksys13042_migver  |
-- tmp_pre_ksys13042_oldrefs |
-- tmp_pre_ksys13042_prever  |
-- tmp_pre_ksys13042_refs    |

-- ---------------------------------------------------------
-- 2. COUNTS — row count per table (before drop)
-- ---------------------------------------------------------
SELECT 'tmp_pre_ksys13042_refs' AS table_name, COUNT(*) AS row_count FROM tmp_pre_ksys13042_refs
UNION ALL SELECT 'tmp_pre_ksys13042_dangling', COUNT(*) FROM tmp_pre_ksys13042_dangling
UNION ALL SELECT 'tmp_pre_ksys13042_migver', COUNT(*) FROM tmp_pre_ksys13042_migver
UNION ALL SELECT 'tmp_pre_ksys13042_prever', COUNT(*) FROM tmp_pre_ksys13042_prever
UNION ALL SELECT 'tmp_pre_ksys13042_oldrefs', COUNT(*) FROM tmp_pre_ksys13042_oldrefs
UNION ALL SELECT 'tmp_pre_ksys13042_fix_plan', COUNT(*) FROM tmp_pre_ksys13042_fix_plan
UNION ALL SELECT 'tmp_ksys13042_refs', COUNT(*) FROM tmp_ksys13042_refs
UNION ALL SELECT 'tmp_ksys13042_dangling', COUNT(*) FROM tmp_ksys13042_dangling
UNION ALL SELECT 'tmp_ksys13042_migver', COUNT(*) FROM tmp_ksys13042_migver
UNION ALL SELECT 'tmp_ksys13042_prever', COUNT(*) FROM tmp_ksys13042_prever
UNION ALL SELECT 'tmp_ksys13042_oldrefs', COUNT(*) FROM tmp_ksys13042_oldrefs
UNION ALL SELECT 'tmp_ksys13042_fix_plan', COUNT(*) FROM tmp_ksys13042_fix_plan
UNION ALL SELECT 'ksys13042_applied', COUNT(*) FROM ksys13042_applied
ORDER BY 1;

-- Output:
-- table_name                |row_count|
-- ----------------------------+---------+
-- tmp_pre_ksys13042_refs    |      421|
-- tmp_pre_ksys13042_dangling|       13|
-- tmp_pre_ksys13042_migver  |       12|
-- tmp_pre_ksys13042_prever  |       12|
-- tmp_pre_ksys13042_oldrefs |       12|
-- tmp_pre_ksys13042_fix_plan|       12|
-- tmp_ksys13042_refs        |      421|
-- tmp_ksys13042_dangling    |       13|
-- tmp_ksys13042_migver      |       12|
-- tmp_ksys13042_prever      |       12|
-- tmp_ksys13042_oldrefs     |       12|
-- tmp_ksys13042_fix_plan    |       12|
-- ksys13042_applied         |       12|

-- ---------------------------------------------------------
-- 3. BACKUP — all tables (run in terminal, not as SQL)
-- ---------------------------------------------------------
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_refs > tmp_pre_ksys13042_refs.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_dangling > tmp_pre_ksys13042_dangling.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_migver > tmp_pre_ksys13042_migver.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_prever > tmp_pre_ksys13042_prever.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_oldrefs > tmp_pre_ksys13042_oldrefs.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_fix_plan > tmp_pre_ksys13042_fix_plan.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_refs > tmp_ksys13042_refs.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_dangling > tmp_ksys13042_dangling.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_migver > tmp_ksys13042_migver.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_prever > tmp_ksys13042_prever.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_oldrefs > tmp_ksys13042_oldrefs.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_fix_plan > tmp_ksys13042_fix_plan.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ ksys13042_applied > ksys13042_applied.sql

-- Output:
--

-- ---------------------------------------------------------
-- 4. DELETION — all tables
-- ---------------------------------------------------------
DROP TABLE IF EXISTS tmp_pre_ksys13042_refs;
DROP TABLE IF EXISTS tmp_pre_ksys13042_dangling;
DROP TABLE IF EXISTS tmp_pre_ksys13042_migver;
DROP TABLE IF EXISTS tmp_pre_ksys13042_prever;
DROP TABLE IF EXISTS tmp_pre_ksys13042_oldrefs;
DROP TABLE IF EXISTS tmp_pre_ksys13042_fix_plan;
DROP TABLE IF EXISTS tmp_ksys13042_refs;
DROP TABLE IF EXISTS tmp_ksys13042_dangling;
DROP TABLE IF EXISTS tmp_ksys13042_migver;
DROP TABLE IF EXISTS tmp_ksys13042_prever;
DROP TABLE IF EXISTS tmp_ksys13042_oldrefs;
DROP TABLE IF EXISTS tmp_ksys13042_fix_plan;
DROP TABLE IF EXISTS ksys13042_applied;

-- Output:
-- =========================================================
-- ---------------------------------------------------------
-- =========================================================

-- =========================================================
-- KSYS-13042 Cleanup — UK
-- Host: (REPLACE_WITH_ENDPOINT)
-- Database: UDM__

-- =========================================================

-- ---------------------------------------------------------
-- 1. SELECT — confirm tables exist
-- ---------------------------------------------------------
SELECT table_name
FROM information_schema.tables
WHERE table_name IN (
    'tmp_pre_ksys13042_refs',
    'tmp_pre_ksys13042_dangling',
    'tmp_pre_ksys13042_migver',
    'tmp_pre_ksys13042_prever',
    'tmp_pre_ksys13042_oldrefs',
    'tmp_pre_ksys13042_fix_plan',
    'tmp_ksys13042_refs',
    'tmp_ksys13042_dangling',
    'tmp_ksys13042_migver',
    'tmp_ksys13042_prever',
    'tmp_ksys13042_oldrefs',
    'tmp_ksys13042_fix_plan',
    'ksys13042_applied'
);

-- Output:
-- table_name                |
-- ----------------------------+
-- ksys13042_applied         |
-- tmp_ksys13042_dangling    |
-- tmp_ksys13042_fix_plan    |
-- tmp_ksys13042_migver      |
-- tmp_ksys13042_oldrefs     |
-- tmp_ksys13042_prever      |
-- tmp_ksys13042_refs        |
-- tmp_pre_ksys13042_dangling|
-- tmp_pre_ksys13042_fix_plan|
-- tmp_pre_ksys13042_migver  |
-- tmp_pre_ksys13042_oldrefs |
-- tmp_pre_ksys13042_prever  |
-- tmp_pre_ksys13042_refs    |

-- ---------------------------------------------------------
-- 2. COUNTS — row count per table (before drop)
-- ---------------------------------------------------------
SELECT 'tmp_pre_ksys13042_refs' AS table_name, COUNT(*) AS row_count FROM tmp_pre_ksys13042_refs
UNION ALL SELECT 'tmp_pre_ksys13042_dangling', COUNT(*) FROM tmp_pre_ksys13042_dangling
UNION ALL SELECT 'tmp_pre_ksys13042_migver', COUNT(*) FROM tmp_pre_ksys13042_migver
UNION ALL SELECT 'tmp_pre_ksys13042_prever', COUNT(*) FROM tmp_pre_ksys13042_prever
UNION ALL SELECT 'tmp_pre_ksys13042_oldrefs', COUNT(*) FROM tmp_pre_ksys13042_oldrefs
UNION ALL SELECT 'tmp_pre_ksys13042_fix_plan', COUNT(*) FROM tmp_pre_ksys13042_fix_plan
UNION ALL SELECT 'tmp_ksys13042_refs', COUNT(*) FROM tmp_ksys13042_refs
UNION ALL SELECT 'tmp_ksys13042_dangling', COUNT(*) FROM tmp_ksys13042_dangling
UNION ALL SELECT 'tmp_ksys13042_migver', COUNT(*) FROM tmp_ksys13042_migver
UNION ALL SELECT 'tmp_ksys13042_prever', COUNT(*) FROM tmp_ksys13042_prever
UNION ALL SELECT 'tmp_ksys13042_oldrefs', COUNT(*) FROM tmp_ksys13042_oldrefs
UNION ALL SELECT 'tmp_ksys13042_fix_plan', COUNT(*) FROM tmp_ksys13042_fix_plan
UNION ALL SELECT 'ksys13042_applied', COUNT(*) FROM ksys13042_applied
ORDER BY 1;

-- Output:
-- table_name                |row_count|
-- ----------------------------+---------+
-- tmp_pre_ksys13042_refs    |     1608|
-- tmp_pre_ksys13042_dangling|      178|
-- tmp_pre_ksys13042_migver  |       44|
-- tmp_pre_ksys13042_prever  |       44|
-- tmp_pre_ksys13042_oldrefs |       44|
-- tmp_pre_ksys13042_fix_plan|       43|
-- tmp_ksys13042_refs        |     1608|
-- tmp_ksys13042_dangling    |      178|
-- tmp_ksys13042_migver      |       44|
-- tmp_ksys13042_prever      |       44|
-- tmp_ksys13042_oldrefs     |       44|
-- tmp_ksys13042_fix_plan    |       43|
-- ksys13042_applied         |       43|

-- ---------------------------------------------------------
-- 3. BACKUP — all tables (run in terminal, not as SQL)
-- ---------------------------------------------------------
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_refs > tmp_pre_ksys13042_refs.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_dangling > tmp_pre_ksys13042_dangling.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_migver > tmp_pre_ksys13042_migver.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_prever > tmp_pre_ksys13042_prever.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_oldrefs > tmp_pre_ksys13042_oldrefs.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_fix_plan > tmp_pre_ksys13042_fix_plan.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_refs > tmp_ksys13042_refs.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_dangling > tmp_ksys13042_dangling.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_migver > tmp_ksys13042_migver.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_prever > tmp_ksys13042_prever.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_oldrefs > tmp_ksys13042_oldrefs.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_fix_plan > tmp_ksys13042_fix_plan.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ ksys13042_applied > ksys13042_applied.sql

-- Output:

-- ---------------------------------------------------------
-- 4. DELETION — all tables
-- ---------------------------------------------------------
DROP TABLE IF EXISTS tmp_pre_ksys13042_refs;
DROP TABLE IF EXISTS tmp_pre_ksys13042_dangling;
DROP TABLE IF EXISTS tmp_pre_ksys13042_migver;
DROP TABLE IF EXISTS tmp_pre_ksys13042_prever;
DROP TABLE IF EXISTS tmp_pre_ksys13042_oldrefs;
DROP TABLE IF EXISTS tmp_pre_ksys13042_fix_plan;
DROP TABLE IF EXISTS tmp_ksys13042_refs;
DROP TABLE IF EXISTS tmp_ksys13042_dangling;
DROP TABLE IF EXISTS tmp_ksys13042_migver;
DROP TABLE IF EXISTS tmp_ksys13042_prever;
DROP TABLE IF EXISTS tmp_ksys13042_oldrefs;
DROP TABLE IF EXISTS tmp_ksys13042_fix_plan;
DROP TABLE IF EXISTS ksys13042_applied;

-- Output:
--


-- =========================================================
-- KSYS-13042 Cleanup — EU
-- Host: (REPLACE_WITH_ENDPOINT)
-- Database: UDM__
-- =========================================================
-- Run SELECT and COUNTS first. Only proceed to BACKUP, then
-- DELETION, once table existence and row counts are confirmed.
-- Output for Drop/Restore is intentionally left blank — fill
-- in upon execution.
-- =========================================================

-- ---------------------------------------------------------
-- 1. SELECT — confirm tables exist
-- ---------------------------------------------------------
SELECT table_name
FROM information_schema.tables
WHERE table_name IN (
    'tmp_pre_ksys13042_refs',
    'tmp_pre_ksys13042_dangling',
    'tmp_pre_ksys13042_migver',
    'tmp_pre_ksys13042_prever',
    'tmp_pre_ksys13042_oldrefs',
    'tmp_pre_ksys13042_fix_plan',
    'tmp_ksys13042_refs',
    'tmp_ksys13042_dangling',
    'tmp_ksys13042_migver',
    'tmp_ksys13042_prever',
    'tmp_ksys13042_oldrefs',
    'tmp_ksys13042_fix_plan',
    'ksys13042_applied'
);

-- Output:
--

-- ---------------------------------------------------------
-- 2. COUNTS — row count per table (before drop)
-- ---------------------------------------------------------
SELECT 'tmp_pre_ksys13042_refs' AS table_name, COUNT(*) AS row_count FROM tmp_pre_ksys13042_refs
UNION ALL SELECT 'tmp_pre_ksys13042_dangling', COUNT(*) FROM tmp_pre_ksys13042_dangling
UNION ALL SELECT 'tmp_pre_ksys13042_migver', COUNT(*) FROM tmp_pre_ksys13042_migver
UNION ALL SELECT 'tmp_pre_ksys13042_prever', COUNT(*) FROM tmp_pre_ksys13042_prever
UNION ALL SELECT 'tmp_pre_ksys13042_oldrefs', COUNT(*) FROM tmp_pre_ksys13042_oldrefs
UNION ALL SELECT 'tmp_pre_ksys13042_fix_plan', COUNT(*) FROM tmp_pre_ksys13042_fix_plan
UNION ALL SELECT 'tmp_ksys13042_refs', COUNT(*) FROM tmp_ksys13042_refs
UNION ALL SELECT 'tmp_ksys13042_dangling', COUNT(*) FROM tmp_ksys13042_dangling
UNION ALL SELECT 'tmp_ksys13042_migver', COUNT(*) FROM tmp_ksys13042_migver
UNION ALL SELECT 'tmp_ksys13042_prever', COUNT(*) FROM tmp_ksys13042_prever
UNION ALL SELECT 'tmp_ksys13042_oldrefs', COUNT(*) FROM tmp_ksys13042_oldrefs
UNION ALL SELECT 'tmp_ksys13042_fix_plan', COUNT(*) FROM tmp_ksys13042_fix_plan
UNION ALL SELECT 'ksys13042_applied', COUNT(*) FROM ksys13042_applied
ORDER BY 1;

-- Output:
--

-- ---------------------------------------------------------
-- 3. BACKUP — all tables (run in terminal, not as SQL)
-- ---------------------------------------------------------
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_refs > tmp_pre_ksys13042_refs.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_dangling > tmp_pre_ksys13042_dangling.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_migver > tmp_pre_ksys13042_migver.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_prever > tmp_pre_ksys13042_prever.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_oldrefs > tmp_pre_ksys13042_oldrefs.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_pre_ksys13042_fix_plan > tmp_pre_ksys13042_fix_plan.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_refs > tmp_ksys13042_refs.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_dangling > tmp_ksys13042_dangling.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_migver > tmp_ksys13042_migver.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_prever > tmp_ksys13042_prever.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_oldrefs > tmp_ksys13042_oldrefs.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ tmp_ksys13042_fix_plan > tmp_ksys13042_fix_plan.sql
-- mysqldump -h 0 -u root -p'' --hex-blob UDM__ ksys13042_applied > ksys13042_applied.sql

-- Output:
--

-- ---------------------------------------------------------
-- 4. DELETION — all tables
-- ---------------------------------------------------------
DROP TABLE IF EXISTS tmp_pre_ksys13042_refs;
DROP TABLE IF EXISTS tmp_pre_ksys13042_dangling;
DROP TABLE IF EXISTS tmp_pre_ksys13042_migver;
DROP TABLE IF EXISTS tmp_pre_ksys13042_prever;
DROP TABLE IF EXISTS tmp_pre_ksys13042_oldrefs;
DROP TABLE IF EXISTS tmp_pre_ksys13042_fix_plan;
DROP TABLE IF EXISTS tmp_ksys13042_refs;
DROP TABLE IF EXISTS tmp_ksys13042_dangling;
DROP TABLE IF EXISTS tmp_ksys13042_migver;
DROP TABLE IF EXISTS tmp_ksys13042_prever;
DROP TABLE IF EXISTS tmp_ksys13042_oldrefs;
DROP TABLE IF EXISTS tmp_ksys13042_fix_plan;
DROP TABLE IF EXISTS ksys13042_applied;

-- Output:
--
