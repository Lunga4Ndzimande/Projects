/* =====================================================================
===================================================================== */

/* =====================================================================
   STAGE 4 - SWITCH TO A WRITE ACCOUNT AND RE-CHECK ENVIRONMENT
   CSE is SELECT-only. Use the write account your team authorises (root on
   REL/DEV). Password at the prompt only.
   [SHELL] mysql -h "$DBHOST" -u root -p UDM__ -e "SELECT @@hostname, DATABASE(), CURRENT_USER();"
   Hostname must be the UK prod host. If access is refused, ask the DB owner;
   do not try other accounts.
   ===================================================================== */


/* =====================================================================
   STAGE 5 - DELETE THE PROVIDER SECRETS (BEFORE the tables are dropped)
   Only Secrets rows are deleted. Client 109 and the providers are NOT touched.
   ===================================================================== */

-- 5a. Count before. Must equal matching_secrets from 2b.

--     mysql -h "$DBHOST" -u root -p UDM__ -e "SELECT COUNT(*) AS before_delete FROM Secrets WHERE id IN (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL);"
SELECT COUNT(*) AS before_delete FROM Secrets
WHERE id IN (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL);

-- 5b. [WRITE] Delete. Use the IDs and clientId from 2c. Run ONLY in the session
--     where Stage 4 printed the UK host. Uncomment ONLY when ready:
   DELETE FROM Secrets
   WHERE id IN ('57a3e32b-50fa-4005-b05b-30164a9ba7c6')
   AND clientId = 109;
--     mysql -h "$DBHOST" -u root -p UDM__ -e "DELETE FROM Secrets WHERE id IN ('57a3e32b-50fa-4005-b05b-30164a9ba7c6') AND clientId = 109;"

-- 5c. Check. matching_left = 0 | total_now = total_secrets - matching_secrets | providers unchanged
SELECT
  (SELECT COUNT(*) FROM Secrets WHERE id IN
      (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL)) AS matching_left,
  (SELECT COUNT(*) FROM Secrets)    AS total_now,
  (SELECT COUNT(*) FROM AIProvider) AS providers_untouched;

-- Restore test: already proven on REL (3 secrets restored from the same kind
-- of dump). On prod it is optional and your team's call. If the delete ever
-- needs undoing:
  cd  /tmp/KSYS-12922-uk
mysql -h "$DBHOST" -u root -p UDM__ < Secrets_aiprovider_backup_$TS.sql

--   then re-run 5c: matching_left returns to its original count.


/* =====================================================================
   STAGE 6 - STRIP "AIProviders" FROM Client.modules
   Double quotes are built with CHAR(34) so DBeaver cannot choke on them.
   Leaves "ChartAI" and the separate "Secrets" module alone.
   ===================================================================== */

-- 6a. PREVIEW. after_n = before_n - 1 and still_has_token = 0 on EVERY row.
--     If any row differs (especially still_has_token = 1) do NOT go on; paste it.
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

--6b. [WRITE] REAL UPDATE in ONE open transaction. Nothing is permanent until
--     you type COMMIT. (Run this the same way as the REL dry run, which should
--     already have proved ROLLBACK works on SingleStore.)
--     [SHELL] mysql -h "$DBHOST" -u root -p UDM__     (client prompts for the password)
--     Then at mysql>, one statement at a time:
--
--       SELECT @@hostname, DATABASE();        -- must be the UK prod host; else type exit
--       START TRANSACTION;
--       UPDATE Client SET modules = REPLACE(REPLACE(REPLACE(CAST(modules AS CHAR),
--           CONCAT(',', CHAR(34), 'AIProviders', CHAR(34)), ''),
--           CONCAT(CHAR(34), 'AIProviders', CHAR(34), ','), ''),
--           CONCAT('[', CHAR(34), 'AIProviders', CHAR(34), ']'), '[]')
--         WHERE CAST(modules AS CHAR) LIKE '%AIProviders%';   -- rows changed = clients_with_module
--       SELECT COUNT(*) AS should_be_0 FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%';
--       SELECT COUNT(*) AS chartai FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%';
--
--     should_be_0 = 0 AND chartai = chartai_baseline from 2b  ->  COMMIT;
--     anything else                                           ->  ROLLBACK;  (paste me the output)
--     Then type exit and re-run 6c from a fresh session.

-- 6c. Check (fresh session): should_be_0 = 0 | chartai = baseline from 2b
SELECT
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%') AS should_be_0,
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%')     AS chartai;


