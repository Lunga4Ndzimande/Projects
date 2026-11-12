/* =====================================================================
   TECH-4399 / KSYS-12922 - REL - PART 3: DELETION (WRITES, root)
   Host ew1r-kapp-db-primary.rel.kurtosys-internal.net (master aggregator ew1r-aggr-03)
   DB UDM__ | Jumpbox ew1r-jump-01.rel.kurtosys-internal.net
   STATUS: Secrets delete DONE (3 -> 0, total 2203 -> 2200). Strip NOT done. Tables are NOT dropped here: the upgrade does that.
   RULES: ONE statement at a time. Paste one command at a time, single line, no
   prompt or output text. mysql> = SQL only; shell prompt = shell only.
   A new shell (sudo su) loses DBHOST/TS: re-set and check  echo "[$TS] [$DBHOST]"
   Passwords only at the prompt. Writes are commented out and tagged [WRITE].
   ===================================================================== */


-- ===== STEP A. Confirm write account + REL host =====
DBHOST=ew1r-kapp-db-primary.rel.kurtosys-internal.net
TS=20261111
echo "[$DBHOST] [$TS] $(pwd)"
mysql -h "$DBHOST" -u root -p UDM__ -e "SELECT @@hostname, DATABASE(), CURRENT_USER();"

--Expect ew1r-aggr-03.rel... | UDM__ | root@...   (not rel? STOP)



-- Delete the 3 Secrets (before the tables are dropped) =====
-- Prereq: Part 2A dumps verified (DONE). Only Secrets rows go; client 53 and providers stay.
-- B1. Count before. Expect 3.
SELECT COUNT(*) AS before_delete FROM Secrets
WHERE id IN (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL);

-- B2. [WRITE] Delete (ran on 10 Nov). To repeat, uncomment ONLY these lines:
    DELETE FROM Secrets
    WHERE id IN ('a9f0e991-cfa3-44a9-a794-85a146bd7573',
                 '7d9582b0-5dc0-48ca-80f7-b3c5ebd82b42',
                 '25b6b4fc-1367-42e0-a949-47f902060ff2')
               AND clientId = 53;
     mysql -h "$DBHOST" -u root -p UDM__ -e "DELETE FROM Secrets WHERE id IN ('a9f0e991-cfa3-44a9-a794-85a146bd7573','7d9582b0-5dc0-48ca-80f7-b3c5ebd82b42','25b6b4fc-1367-42e0-a949-47f902060ff2') AND clientId = 53;"

        --B3. Check. Expect matching_left 0 | total_now 2200 | providers_untouched 3
SELECT
  (SELECT COUNT(*) FROM Secrets WHERE id IN
      (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL)) AS matching_left,
  (SELECT COUNT(*) FROM Secrets)    AS total_now,
  (SELECT COUNT(*) FROM AIProvider) AS providers_untouched;

-- ===== STEP C. Strip "AIProviders" from Client.modules (15 clients) =====
-- Quotes built with CHAR(34) so DBeaver cannot choke. Leaves "ChartAI" and "Secrets" module.
-- C1. PREVIEW. 15 rows; after_n = before_n - 1 and still_has_token = 0 on EVERY row.
SELECT clientId,
  JSON_LENGTH(modules) AS before_n,
  JSON_LENGTH(
    REPLACE(REPLACE(REPLACE(CAST(modules AS CHAR),
      CONCAT(',', CHAR(34), 'AIProviders', CHAR(34)), ''),
      CONCAT(CHAR(34), 'AIProviders', CHAR(34), ','), ''),
      CONCAT('[', CHAR(34), 'AIProviders', CHAR(34), ']'), '[]') :> JSON) AS after_n,
  (REPLACE(REPLACE(REPLACE(CAST(modules AS CHAR),
      CONCAT(',', CHAR(34), 'AIProviders', CHAR(34)), ''),
      CONCAT(CHAR(34), 'AIProviders', CHAR(34), ','), ''),
      CONCAT('[', CHAR(34), 'AIProviders', CHAR(34), ']'), '[]')
    LIKE '%AIProviders%') AS still_has_token
FROM Client
WHERE CAST(modules AS CHAR) LIKE '%AIProviders%'
ORDER BY clientId;

-- C2. DRY RUN (mysql client; rolls back). Proves ROLLBACK works on SingleStore.
        mysql -h "$DBHOST" -u root -p UDM__      then at mysql> one statement at a time:
        START TRANSACTION;
        UPDATE Client SET modules = REPLACE(REPLACE(REPLACE(CAST(modules AS CHAR),
        CONCAT(',', CHAR(34), 'AIProviders', CHAR(34)), ''),
        CONCAT(CHAR(34), 'AIProviders', CHAR(34), ','), ''),
        CONCAT('[', CHAR(34), 'AIProviders', CHAR(34), ']'), '[]')
        WHERE CAST(modules AS CHAR) LIKE '%AIProviders%';
        SELECT COUNT(*) AS should_be_0 FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%';
       SELECT COUNT(*) AS chartai_same FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%';

--     ROLLBACK;
--     SELECT COUNT(*) AS back_to_original FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%';
--   Expect 0 | 17 | 15. If back_to_original = 0 the rollback did not work: restore Client dump.

-- C3. REAL UPDATE in ONE open transaction. Nothing permanent until COMMIT.
--    Prereq: C1 clean (no still_has_token = 1), C2 passed.
      mysql -h "$DBHOST" -u root -p UDM__
--     SELECT @@hostname, DATABASE();       -- must be REL, else exit
       START TRANSACTION;
--     (same UPDATE as C2)                  -- expect 15 rows changed
       SELECT COUNT(*) AS should_be_0 FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%';
       SELECT COUNT(*) AS chartai_17   FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%';
--     0 AND 17  -> COMMIT;     anything else -> ROLLBACK; and paste output

-- C4. Check from a fresh session. Expect 0 | 17
SELECT
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%') AS should_be_0,
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%')     AS chartai_17;
