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