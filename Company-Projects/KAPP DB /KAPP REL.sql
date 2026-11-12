-- KSYS-13993 — as_at_date shape audit
--
-- Purpose
--   Count how document as_at_date values are stored, per environment,
--   before any correction is written. The current draft correction only
--   rewrites active midnight-Z values on 1 Jan / 1 Apr / 1 Jul / 1 Oct
--   whose title matches K1, K-1, Tax, or GP Tax. These queries show that
--   population and everything outside it.
--
-- Run
--   Read-only. Schema UDM__.
--   Once on REL.
--   Once per production KApp primary (EU, UK, US).
--   Return the result sets, labelled by environment.
--   Do not INSERT, UPDATE, DELETE, or run the seed / backfill scripts.

-- ---------------------------------------------------------------------------
-- Query 1 — shape counts, active documents
-- ---------------------------------------------------------------------------
SELECT
  CASE
    WHEN meta::as_at_date::$value :> text REGEXP 'T00:00:00(\.0+)?Z$' THEN 'utc-midnight-z'
    WHEN meta::as_at_date::$value :> text REGEXP 'T00:00:00(\.0+)?[+-][0-9]{2}:?[0-9]{2}$' THEN 'midnight-offset'
    WHEN meta::as_at_date::$value :> text LIKE '%Z' THEN 'utc-z-other'
    WHEN meta::as_at_date::$value :> text REGEXP '[+-][0-9]{2}:?[0-9]{2}$' THEN 'offset-other'
    WHEN meta::as_at_date::$value :> text LIKE '%T%' THEN 'naive-datetime'
    WHEN CHAR_LENGTH(meta::as_at_date::$value :> text) = 10 THEN 'date-only'
    ELSE 'other'
  END AS value_shape,
  COUNT(*) AS n,
  COUNT(DISTINCT clientId) AS clients
FROM Documents
WHERE active = 1
  AND meta::as_at_date::$value IS NOT NULL
GROUP BY 1
ORDER BY n DESC;

--Output

value_shape|n|clients|
-----------+-+-------+

-- ---------------------------------------------------------------------------
-- Query 2 — non-date-only shapes per client
-- date-only (yyyy-MM-dd) is the stored form the application now writes.
-- ---------------------------------------------------------------------------
SELECT
  d.clientId,
  c.clientName,
  CASE
    WHEN d.meta::as_at_date::$value :> text REGEXP 'T00:00:00(\.0+)?Z$' THEN 'utc-midnight-z'
    WHEN d.meta::as_at_date::$value :> text REGEXP 'T00:00:00(\.0+)?[+-][0-9]{2}:?[0-9]{2}$' THEN 'midnight-offset'
    WHEN d.meta::as_at_date::$value :> text LIKE '%Z' THEN 'utc-z-other'
    WHEN d.meta::as_at_date::$value :> text REGEXP '[+-][0-9]{2}:?[0-9]{2}$' THEN 'offset-other'
    WHEN d.meta::as_at_date::$value :> text LIKE '%T%' THEN 'naive-datetime'
    ELSE 'other'
  END AS value_shape,
  COUNT(*) AS n
FROM Documents d
LEFT JOIN Client c ON c.clientId = d.clientId
WHERE d.active = 1
  AND d.meta::as_at_date::$value IS NOT NULL
  AND CHAR_LENGTH(d.meta::as_at_date::$value :> text) <> 10
GROUP BY 1, 2, 3
ORDER BY n DESC, d.clientId;

--- Output

clientId|clientName|value_shape|n|
--------+----------+-----------+-+

-- ---------------------------------------------------------------------------
-- Query 3 — midnight-Z rows against the current draft correction
-- in_current_correction = 1 only when the date list and the title filter
-- both match. Client 210 and 212 are not special-cased here.
-- ---------------------------------------------------------------------------
SELECT
  LEFT(meta::as_at_date::$value :> text, 10) AS utc_day,
  CASE
    WHEN LEFT(meta::as_at_date::$value :> text, 10) IN (
      '2024-01-01', '2024-04-01', '2024-07-01', '2024-10-01',
      '2025-01-01', '2025-04-01', '2025-07-01', '2025-10-01',
      '2026-01-01', '2026-04-01', '2026-07-01', '2026-10-01'
    ) THEN 1 ELSE 0
  END AS in_quarter_start_list,
  CASE
    WHEN title LIKE '%K1%'
      OR title LIKE '%K-1%'
      OR title LIKE '%Tax%'
      OR title LIKE '%GP Tax%'
    THEN 1 ELSE 0
  END AS title_matches_current_filter,
  COUNT(*) AS n,
  COUNT(DISTINCT clientId) AS clients
FROM Documents
WHERE active = 1
  AND meta::as_at_date::$value :> text REGEXP 'T00:00:00(\.0+)?Z$'
GROUP BY 1, 2, 3
ORDER BY n DESC;

--Output

utc_day|in_quarter_start_list|title_matches_current_filter|n|clients|
-------+---------------------+----------------------------+-+-------+


-- ---------------------------------------------------------------------------
-- Query 4 — sample of midnight-Z rows the current correction would not touch
-- ---------------------------------------------------------------------------
SELECT
  d.documentId,
  d.clientId,
  c.clientName,
  d.title,
  d.meta::as_at_date::$value :> text AS stored_value
FROM Documents d
LEFT JOIN Client c ON c.clientId = d.clientId
WHERE d.active = 1
  AND d.meta::as_at_date::$value :> text REGEXP 'T00:00:00(\.0+)?Z$'
  AND NOT (
    LEFT(d.meta::as_at_date::$value :> text, 10) IN (
      '2024-01-01', '2024-04-01', '2024-07-01', '2024-10-01',
      '2025-01-01', '2025-04-01', '2025-07-01', '2025-10-01',
      '2026-01-01', '2026-04-01', '2026-07-01', '2026-10-01'
    )
    AND (
      d.title LIKE '%K1%'
      OR d.title LIKE '%K-1%'
      OR d.title LIKE '%Tax%'
      OR d.title LIKE '%GP Tax%'
    )
  )
ORDER BY d.clientId, d.documentId
LIMIT 200;

--output

documentId|clientId|clientName|title|stored_value|
----------+--------+----------+-----+------------+ 

-- ---------------------------------------------------------------------------
-- Query 5 — sample of other non-date-only shapes (not midnight-Z)
-- ---------------------------------------------------------------------------
SELECT
  d.documentId,
  d.clientId,
  c.clientName,
  d.title,
  d.meta::as_at_date::$value :> text AS stored_value,
  CASE
    WHEN d.meta::as_at_date::$value :> text REGEXP 'T00:00:00(\.0+)?[+-][0-9]{2}:?[0-9]{2}$' THEN 'midnight-offset'
    WHEN d.meta::as_at_date::$value :> text LIKE '%Z' THEN 'utc-z-other'
    WHEN d.meta::as_at_date::$value :> text REGEXP '[+-][0-9]{2}:?[0-9]{2}$' THEN 'offset-other'
    WHEN d.meta::as_at_date::$value :> text LIKE '%T%' THEN 'naive-datetime'
    ELSE 'other'
  END AS value_shape
FROM Documents d
LEFT JOIN Client c ON c.clientId = d.clientId
WHERE d.active = 1
  AND d.meta::as_at_date::$value IS NOT NULL
  AND CHAR_LENGTH(d.meta::as_at_date::$value :> text) <> 10
  AND d.meta::as_at_date::$value :> text NOT REGEXP 'T00:00:00(\.0+)?Z$'
ORDER BY d.clientId, d.documentId
LIMIT 200;

--Output

documentId|clientId|clientName|title|stored_value|value_shape|
----------+--------+----------+-----+------------+-----------+

-- ---------------------------------------------------------------------------
-- Query 6 — inactive midnight-Z counts, by client
-- Not a correction list. Count only.
-- ---------------------------------------------------------------------------
SELECT
  d.clientId,
  c.clientName,
  COUNT(*) AS inactive_midnight_z
FROM Documents d
LEFT JOIN Client c ON c.clientId = d.clientId
WHERE d.active = 0
  AND d.meta::as_at_date::$value :> text REGEXP 'T00:00:00(\.0+)?Z$'
GROUP BY 1, 2
ORDER BY inactive_midnight_z DESC;

--output
clientId|clientName|inactive_midnight_z|
--------+----------+-------------------+