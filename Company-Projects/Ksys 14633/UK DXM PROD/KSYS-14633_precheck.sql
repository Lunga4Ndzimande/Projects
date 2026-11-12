-- RUN THIS FIRST (read-only). Expect 135 rows in each count if the client-name columns are safe to use.
SELECT
  SUM(table_name='_wpsite')  AS schemas_with__wpsite,
  SUM(table_name='_wpblogs') AS schemas_with__wpblogs,
  SUM(table_name='_wpsitemeta') AS schemas_with__wpsitemeta
FROM information_schema.tables
WHERE table_name IN ('_wpsite','_wpblogs','_wpsitemeta')
  AND table_schema NOT IN ('information_schema','mysql','performance_schema','sys','Utilities','awsdms_control');
