/* =====================================================================
   TECH-4399 / KSYS-12922  -  Drop AIProvider schema, purge Secrets,
   strip AIProviders from Client.modules
   ENVIRONMENT : REL  (UDM__ on SingleStore)
   REL numbers : providers 3 | calls 85 | matching secrets 3
                 clients with module 15 | ChartAI baseline 17
                 total Secrets 2203 (expect 2200 after)

   PROGRESS (updated 10 Nov 2026)
     [x] Step 2  Inventory done: 3 | 85 | 3 | 15 | 17 | 2203 (client 53 owns all 3 providers)
     [x] Step 3  Dumps taken and verified (3 IDs, 15 client rows, 3 INSERTs,
                 all end "Dump completed", checksums saved)
     [x] Step 5  3 Secrets deleted as root: count 3 -> matching_left 0,
                 total_secrets 2203 -> 2200, providers untouched 3
     [x] Step 6  Restore test PASSED: restoring Secrets_aiprovider_backup_20261110-112806.sql
                 brought the 3 secrets back (confirmed by user)
     [ ] Step 6  Confirm final state is clean again: matching_left 0, total 2200, providers 3
     [ ] Step 1  Root hostname evidence line (expect ew1r-aggr-03) still to attach
     [ ] Step 2e Duplicate-token query result still to attach (expect no rows)
     [ ] Step 7  Client.modules strip (preview 7a, dry run 7b, transaction 7c): NOT done
     [ ] Step 8  Upgrade deploy, then Step 9 verification (incl. 9d): NOT done
     [ ] Postgres: not covered; ask whether REL Postgres is in this pass

   SHELL HYGIENE (lessons from the run)
   - Paste ONE command at a time; never paste output lines back in.
   - Paste long commands as a single line. Wrapped lines inject '>' into
     IDs and drop the dashes of --where.
   - mysql> is SQL only; the shell prompt is shell only.
   - A new shell loses DBHOST and TS: re-set them and check with
       echo "[$DBHOST]"   (nothing after .net)
   - Switching user (sudo su) starts a new shell: $TS and $DBHOST are empty.
     An empty $TS gives "Secrets_aiprovider_backup_.sql: No such file".
     Re-set TS=20261110-112806 and check  echo "[$TS] [$DBHOST]"  first.
   - A failed dump still leaves a file: always check "Dump completed".

   HOW TO USE THIS FILE
   - Do NOT run the whole file at once. Run ONE statement at a time
     (select it, Ctrl+Enter in DBeaver).
   - Lines starting with  [SHELL]  are shell commands for the REL
     jumpbox, not SQL. Never paste them into mysql> or DBeaver.
   - Accounts: CSE = read-only (inventory, dumps).
               root = writes (delete, update). Type passwords only at
               the prompt, never in the command or in chat.
   - Stop and paste the output if ANY number differs from "expect".
   - v3: every statement that CHANGES data (5b, 7c) is now commented out
     with the tag [WRITE]. Pasting this file into a write connection
     cannot delete or update anything. To run a write you must
     deliberately remove the leading '-- ' after its prerequisites pass.
   ===================================================================== */


/* =====================================================================
   STEP 0 - PREREQUISITES (no SQL)
   - KSYS-12922 is Done
   - TECH-4399's parent TECH-4398 shows udm_ai uninstalled in REL
   - Someone agrees REL rows can be deleted (ticket says not retained)
   ===================================================================== */


/* =====================================================================
   STEP 1 - CONFIRM ENVIRONMENT (read-only)
   Host must contain 'rel'. DATABASE() must be UDM__ (not NULL).
   If NULL: right-click UDM__ > Set as Default, or run:  USE UDM__;
   ===================================================================== */
SELECT @@hostname, DATABASE(), CURRENT_USER();


/* =====================================================================
   STEP 2 - INVENTORY (read-only). Attach results to the ticket.
   ===================================================================== */

-- 2a. Do the tables exist? (2 rows expected on REL)
SELECT TABLE_NAME FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('AIProvider','AIProviderCall');

-- 2b. Counts + ChartAI baseline. Expect 3 | 85 | 3 | 15 | 17 | 2203
SELECT
  (SELECT COUNT(*) FROM AIProvider)     AS providers,
  (SELECT COUNT(*) FROM AIProviderCall) AS calls,
  (SELECT COUNT(*) FROM Secrets WHERE id IN
      (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL)) AS matching_secrets,
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%') AS clients_with_module,
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%')     AS chartai_baseline,
  (SELECT COUNT(*) FROM Secrets) AS total_secrets;

-- 2c. Providers and their credentials (no secret values shown)
SELECT p.aiProviderId, p.clientId, p.name, p.credentialId, s.id AS secret_id
FROM AIProvider p LEFT JOIN Secrets s ON s.id = p.credentialId;

-- 2d. Owning client (expect client 53, Kurtovest Demo)
SELECT DISTINCT c.clientId, c.clientName, c.s3Folder
FROM AIProvider p JOIN Client c ON c.clientId = p.clientId
ORDER BY c.clientId;

-- 2e. Any client with the token more than once? (expect NO rows)
SELECT clientId,
  (LENGTH(CAST(modules AS CHAR)) - LENGTH(REPLACE(CAST(modules AS CHAR), 'AIProviders', '')))
    / LENGTH('AIProviders') AS occ
FROM Client
WHERE CAST(modules AS CHAR) LIKE '%AIProviders%'
HAVING occ > 1;

-- 2f. Token position (expect 15 rows, pos > 0 on every row)
SELECT clientId, JSON_LENGTH(modules) AS n,
       LOCATE('AIProviders', CAST(modules AS CHAR)) AS pos
FROM Client
WHERE CAST(modules AS CHAR) LIKE '%AIProviders%'
ORDER BY clientId;


/* =====================================================================
   STEP 3 - BACKUP WITH MYSQLDUMP (read-only, REL jumpbox ew1r-jump-01)
   STATUS: DONE on 10 Nov 2026, TS=20261110-112806, folder /tmp/KSYS-12922-rel
   Take ALL dumps BEFORE any change. Never attach the Secrets dump to
   Jira; attach only checksums.
   ===================================================================== */

-- [SHELL] 3a. Variables and folder. REL host = Route 53 primary (master aggregator
--             ew1r-aggr-03). Do NOT use the replica or leaf nodes.
--   DBHOST=ew1r-kapp-db-primary.rel.kurtosys-internal.net
--   echo "[$DBHOST]"; getent hosts "$DBHOST"; nc -zv "$DBHOST" 3306
--   mysql -h "$DBHOST" -u CSE -p UDM__ -e "SELECT @@hostname, DATABASE(), CURRENT_USER();"
--   umask 077
--   mkdir -p /tmp/KSYS-12922-rel && chmod 700 /tmp/KSYS-12922-rel && cd /tmp/KSYS-12922-rel
--   TS=$(date +%Y%m%d-%H%M%S); echo $TS

-- [SHELL] 3b. Secrets: the 3 REL credentials (ONE LINE)
--   mysqldump -h "$DBHOST" -u CSE -p --column-statistics=0 --hex-blob --no-create-info --complete-insert --skip-lock-tables --skip-disable-keys --skip-add-locks --max_allowed_packet=512M UDM__ Secrets --where="id IN ('a9f0e991-cfa3-44a9-a794-85a146bd7573','7d9582b0-5dc0-48ca-80f7-b3c5ebd82b42','25b6b4fc-1367-42e0-a949-47f902060ff2')" > Secrets_aiprovider_backup_$TS.sql

-- [SHELL] 3c. Client rows that have the module, 15 rows (ONE LINE)
--   mysqldump -h "$DBHOST" -u CSE -p --column-statistics=0 --hex-blob --no-create-info --complete-insert --replace --skip-lock-tables --skip-disable-keys --skip-add-locks --max_allowed_packet=512M UDM__ Client --where="CAST(modules AS CHAR) LIKE '%AIProviders%'" > Client_modules_backup_$TS.sql

-- [SHELL] 3d. The two tables, structure + data (ONE LINE)
--   mysqldump -h "$DBHOST" -u CSE -p --column-statistics=0 --hex-blob --complete-insert --skip-lock-tables --skip-disable-keys --skip-add-locks --max_allowed_packet=512M UDM__ AIProvider AIProviderCall > AIProvider_tables_backup_$TS.sql

-- [SHELL] 3e. Verify, one command at a time. DO NOT CONTINUE unless all pass.
--   ls -l                                                                              # 3 files, none 0 bytes
--   tail -n 2 Secrets_aiprovider_backup_$TS.sql                                        # "-- Dump completed"
--   tail -n 2 Client_modules_backup_$TS.sql                                            # "-- Dump completed"
--   tail -n 2 AIProvider_tables_backup_$TS.sql                                         # "-- Dump completed"
--   grep -o "'[0-9a-f-]\{36\}'" Secrets_aiprovider_backup_$TS.sql | sort -u | wc -l  # expect 3
--   grep -o "([0-9]*,'" Client_modules_backup_$TS.sql | wc -l                          # expect 15
--   grep -c "INSERT INTO" AIProvider_tables_backup_$TS.sql                             # at least 2 (REL: 3)
--   sha256sum *.sql > checksums_$TS.txt; cat checksums_$TS.txt

-- RECORDED RESULT (REL, 20261110-112806):
--   fa6c6479...8246b  AIProvider_tables_backup_20261110-112806.sql  (1,515,721 B)
--   274b4004...20728  Client_modules_backup_20261110-112806.sql     (16,977 B)
--   9ae57b5a...70a17  Secrets_aiprovider_backup_20261110-112806.sql (3,044 B)
--   Attach checksums_20261110-112806.txt to the ticket, NOT the Secrets dump.


/* =====================================================================
   STEP 4 - SWITCH TO A WRITE ACCOUNT (root) AND RE-CHECK ENVIRONMENT
   CSE is SELECT-only. In DBeaver use a root connection, or on the
   jumpbox (the client prompts for the password; never type it in the command):
   [SHELL] mysql -h "$DBHOST" -u root -p UDM__ -e "SELECT @@hostname, DATABASE(), CURRENT_USER();"
   Expect ew1r-aggr-03.rel.kurtosys-internal.net | UDM__ | root@...
   ===================================================================== */
SELECT @@hostname, DATABASE(), CURRENT_USER();   -- host must contain 'rel', user root


/* =====================================================================
   STEP 5 - DELETE THE 3 SECRETS (must run BEFORE the tables are dropped)
   Only Secrets rows are deleted. Client 53 and the providers are NOT
   touched here.
   ===================================================================== */

-- 5a. Count before. Expect 3.
--     [SHELL one-liner] mysql -h "$DBHOST" -u root -p UDM__ -e "SELECT COUNT(*) AS before_delete FROM Secrets WHERE id IN (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL);"
SELECT COUNT(*) AS before_delete FROM Secrets
WHERE id IN (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL);

-- 5b. [WRITE] Delete the 3 secrets. Prerequisites: Step 3e passed (dumps
--     verified, DONE), Step 4 shows a REL host, 5a returned 3.
--     Run it ONLY in the same session where Step 4 printed a REL host.
--     Uncomment ONLY these lines when ready:
-- DELETE FROM Secrets
-- WHERE id IN ('a9f0e991-cfa3-44a9-a794-85a146bd7573',
--              '7d9582b0-5dc0-48ca-80f7-b3c5ebd82b42',
--              '25b6b4fc-1367-42e0-a949-47f902060ff2')
--   AND clientId = 53;
--     Note: the upgrade also deletes these secrets before dropping the
--     tables, so this manual delete exists to make the restore test possible.

-- 5c. Check. Expect matching_left 0 | total_now 2200 | providers_untouched 3
SELECT
  (SELECT COUNT(*) FROM Secrets WHERE id IN
      (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL)) AS matching_left,
  (SELECT COUNT(*) FROM Secrets)    AS total_now,
  (SELECT COUNT(*) FROM AIProvider) AS providers_untouched;


/* =====================================================================
   STEP 6 - TEST THE RESTORE (REL rows are disposable, so prove it here)
   ===================================================================== */

-- [SHELL] 6a. Restore the Secrets from the dump (as root)
--   cd /tmp/KSYS-12922-rel
--   mysql -h "$DBHOST" -u root -p UDM__ < Secrets_aiprovider_backup_$TS.sql
--   If it complains about ALTER/LOCK lines, filter them:
--   grep -v "ALTER TABLE\|LOCK TABLES\|UNLOCK TABLES" Secrets_aiprovider_backup_$TS.sql | mysql -h "$DBHOST" -u root -p UDM__

-- 6b. Re-run 5c. Expect matching_left 3 | total_now 2203  (restore worked)
-- 6c. Then run 5b again so REL ends clean, and 5c again:
--     expect matching_left 0 | total_now 2200
--     If the restore fails and the count is 0, STOP. Do not touch the dump file.


/* =====================================================================
   STEP 7 - STRIP "AIProviders" FROM Client.modules (15 clients)
   Double quotes are built with CHAR(34) so DBeaver cannot choke on them.
   Leaves "ChartAI" and the separate "Secrets" module alone.
   ===================================================================== */

-- 7a. PREVIEW. Expect 15 rows, after_n = before_n - 1 on EVERY row,
--     still_has_token = 0 on every row. Otherwise STOP and paste it.
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

-- 7b. DRY RUN (jumpbox, mysql client; rolls back so nothing changes).
--     DBeaver autocommits, so do the dry run in the mysql client:
--     [SHELL] mysql -h "$DBHOST" -u root -p UDM__     then at mysql> paste:
--
--       START TRANSACTION;
--       UPDATE Client SET modules = REPLACE(REPLACE(REPLACE(CAST(modules AS CHAR),
--           CONCAT(',', CHAR(34), 'AIProviders', CHAR(34)), ''),
--           CONCAT(CHAR(34), 'AIProviders', CHAR(34), ','), ''),
--           CONCAT('[', CHAR(34), 'AIProviders', CHAR(34), ']'), '[]')
--         WHERE CAST(modules AS CHAR) LIKE '%AIProviders%';
--       SELECT COUNT(*) AS should_be_0 FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%';
--       SELECT COUNT(*) AS chartai_same FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%';
--       ROLLBACK;
--       SELECT COUNT(*) AS back_to_original FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%';
--
--     Expect should_be_0 = 0 | chartai_same = 17 | back_to_original = 15.
--     If back_to_original is 0 the rollback did not work: restore from
--     Client_modules_backup_$TS.sql.

-- 7c. [WRITE] REAL UPDATE in ONE open transaction. Nothing is permanent until
--     you type COMMIT, so a bad result never needs the dump.
--     Prerequisites: 7a showed 15 rows, after_n = before_n - 1, still_has_token = 0
--     on EVERY row (if any row has still_has_token = 1, do NOT start), and 7b
--     proved ROLLBACK works on this server.
--     [SHELL] mysql -h "$DBHOST" -u root -p UDM__      (client prompts for the password;
--             never put it on the command line, it shows in the process list)
--     Then at mysql>, one statement at a time:
--
--       SELECT @@hostname, DATABASE();        -- must contain 'rel'; else type exit
--       START TRANSACTION;
--       UPDATE Client SET modules = REPLACE(REPLACE(REPLACE(CAST(modules AS CHAR),
--           CONCAT(',', CHAR(34), 'AIProviders', CHAR(34)), ''),
--           CONCAT(CHAR(34), 'AIProviders', CHAR(34), ','), ''),
--           CONCAT('[', CHAR(34), 'AIProviders', CHAR(34), ']'), '[]')
--         WHERE CAST(modules AS CHAR) LIKE '%AIProviders%';      -- expect 15 rows changed
--       SELECT COUNT(*) AS should_be_0 FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%';
--       SELECT COUNT(*) AS chartai_17   FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%';
--
--     should_be_0 = 0 AND chartai_17 = 17  ->  COMMIT;
--     anything else                        ->  ROLLBACK;   (then paste me the output)
--     Then type exit. Re-run 7d from a fresh session to confirm it was committed.

-- 7d. Check. Expect should_be_0 = 0 | chartai = 17 (same as baseline)
SELECT
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%') AS should_be_0,
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%')     AS chartai;


/* =====================================================================
   STEP 8 - DEPLOY THE UPGRADE (this, not you, drops the tables; do NOT DROP by hand)
   Deploy the ksysUDM upgrade from branch
   feature/KSYS-12922-drop-aiprovider-tables-and-module-seeds
   through the usual DB upgrade path. REVIEW the SQL first: it should
   drop AIProviderCall, then AIProvider, then remove the AIProviders
   module, 4 permissions, CREATE/UPDATE/DELETE activity types and
   TableId rows. (Seed rows are NOT in the dumps above; dump them first
   if you want a full rollback.)
   ===================================================================== */


/* =====================================================================
   STEP 9 - VERIFY ACCEPTANCE CRITERIA
   ===================================================================== */

-- 9a. Tables gone (expect NO rows)
SELECT TABLE_NAME FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('AIProvider','AIProviderCall');

-- 9b. No client still lists the module; ChartAI unchanged (0 and 17)
SELECT
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%') AS should_be_0,
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%')     AS chartai_17;

-- 9c. The 3 Secrets are gone (expect 0). Uses IDs, since AIProvider no longer exists.
SELECT COUNT(*) AS should_be_0 FROM Secrets
WHERE id IN ('a9f0e991-cfa3-44a9-a794-85a146bd7573',
             '7d9582b0-5dc0-48ca-80f7-b3c5ebd82b42',
             '25b6b4fc-1367-42e0-a949-47f902060ff2');

-- 9d. Seed rows removed by the upgrade. Each should be 0 after the upgrade.
--     NOTE: column names below come from the Cursor review of
--     udm_db/artifacts/upgrades/2026-09-15-drop-ai-provider-tables.sql and
--     are NOT verified by me. Check them against that file first; if a
--     query errors with "unknown column", fix it there. Historical
--     Activity rows are expected to remain (no foreign key).
SELECT COUNT(*) AS modules_left FROM Modules WHERE moduleId = 'AIProviders';
SELECT COUNT(*) AS permissions_left FROM Permissions
 WHERE permissionId IN ('VIEW_AI_PROVIDERS','UPSERT_AI_PROVIDER','DELETE_AI_PROVIDER','MAKE_AI_PROVIDER_CALL');
SELECT COUNT(*) AS role_permissions_left FROM RolePermission
 WHERE permissionId IN ('VIEW_AI_PROVIDERS','UPSERT_AI_PROVIDER','DELETE_AI_PROVIDER','MAKE_AI_PROVIDER_CALL');
SELECT COUNT(*) AS activity_types_left FROM ActivityType
 WHERE activityType IN ('AI_PROVIDER_CREATE','AI_PROVIDER_UPDATE','AI_PROVIDER_DELETE');
SELECT COUNT(*) AS activity_category_left FROM ActivityCategoryType
 WHERE activityType IN ('AI_PROVIDER_CREATE','AI_PROVIDER_UPDATE','AI_PROVIDER_DELETE');
SELECT COUNT(*) AS tableid_left FROM TableId
 WHERE tableName IN ('AIProvider','AIProviderCall');


/* =====================================================================
   STEP 10 - FULL ROLLBACK (only if something goes wrong; run as root)
   Reverse order. Restores data only, not the app code or udm_ai.
   LIMITS: only the 3 secrets restore is tested. The upgrade's seed-row
   deletes (Modules, Permissions, RolePermission, ActivityType,
   ActivityCategoryType, TableId) are NOT backed up here. Dump those rows
   first if a full rollback is required. Postgres is not covered.
   ===================================================================== */
-- [SHELL] cd /tmp/KSYS-12922-rel
-- [SHELL] mysql -h "$DBHOST" -u root -p UDM__ < AIProvider_tables_backup_$TS.sql   # DROP/CREATE + data
-- [SHELL] mysql -h "$DBHOST" -u root -p UDM__ < Client_modules_backup_$TS.sql      # REPLACE INTO (whole rows)
-- [SHELL] mysql -h "$DBHOST" -u root -p UDM__ < Secrets_aiprovider_backup_$TS.sql  # if row exists: delete first
-- Then re-run STEP 2b. Expect 3 | 85 | 3 | 15 | 17 | 2203.


/* =====================================================================
   STEP 11 - EVIDENCE AND CLEANUP
   Attach to the ticket: Step 1 hostname, Step 2 counts, checksums_$TS.txt,
   Step 5c, 7a, 7d and 9a-9c results. NOT the Secrets dump.
   After sign-off: delete the dump files (especially the Secrets one),
   and run  unset MYSQL_PWD  if you set it.
   ===================================================================== */
