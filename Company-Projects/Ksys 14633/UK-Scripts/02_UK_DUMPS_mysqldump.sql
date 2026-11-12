/* =====================================================================
 
/* =====================================================================
   STAGE 3 - BACKUP WITH MYSQLDUMP (read-only; UK jumpbox ew2p-jump-02)
   Take ALL dumps BEFORE any change. Never attach the Secrets dump to Jira;
   attach only the checksums file.
   ===================================================================== */

-- . Variables and folder. Type the real UK host from DBeaver.
--   DBHOST=PUT-THE-REAL-UK-HOST-HERE
--   echo "[$DBHOST]"; getent hosts "$DBHOST"; nc -zv "$DBHOST" 3306
--   mysql -h "$DBHOST" -u CSE -p UDM__ -e "SELECT @@hostname, DATABASE(), CURRENT_USER();"
--       (hostname must be the UK prod host ew2p-..., NOT a rel/dev host)

     umask 077
     mkdir -p /tmp/KSYS-12922-uk && chmod 700 /tmp/KSYS-12922-uk && cd /tmp/KSYS-12922-uk
     TS=$(date +%Y%m%d-%H%M%S); echo $TS

       --3b. Secrets: ONE quoted ID per provider from 2c (ONE LINE).
--        Example uses the last-seen UK ID; REPLACE with the IDs from 2c.
--   
      mysqldump -h "$DBHOST" -u CSE -p --column-statistics=0 --hex-blob --no-create-info --complete-insert --skip-lock-tables --skip-disable-keys --skip-add-locks --max_allowed_packet=512M UDM__ Secrets --where="id IN ('57a3e32b-50fa-4005-b05b-30164a9ba7c6')" > Secrets_aiprovider_backup_$TS.sql

-- 3c. Client rows that have the module (ONE LINE)
      mysqldump -h "$DBHOST" -u CSE -p --column-statistics=0 --hex-blob --no-create-info --complete-insert --replace --skip-lock-tables --skip-disable-keys --skip-add-locks --max_allowed_packet=512M UDM__ Client --where="CAST(modules AS CHAR) LIKE '%AIProviders%'" > Client_modules_backup_$TS.sql

     [SHELL] 3d. The two tables, structure + data (ONE LINE)
      mysqldump -h "$DBHOST" -u CSE -p --column-statistics=0 --hex-blob --complete-insert --skip-lock-tables --skip-disable-keys --skip-add-locks --max_allowed_packet=512M UDM__ AIProvider AIProviderCall > AIProvider_tables_backup_$TS.sql

---   3e. Verify, one command at a time. DO NOT CONTINUE unless all pass.
   ls -l                                                                              
    tail -n 2 Secrets_aiprovider_backup_$TS.sql                                        # "-- Dump completed"
      tail -n 2 Client_modules_backup_$TS.sql                                            # "-- Dump completed"
     tail -n 2 AIProvider_tables_backup_$TS.sql                                         # "-- Dump completed"
      grep -o "'[0-9a-f-]\{36\}'" Secrets_aiprovider_backup_$TS.sql | sort -u | wc -l   # = matching_secrets from 2b
     grep -o "([0-9]*,'" Client_modules_backup_$TS.sql | wc -l                          # = clients_with_module from 2b
     grep -c "INSERT INTO" AIProvider_tables_backup_$TS.sql                             # at least 2
    sha256sum *.sql > checksums_$TS.txt; cat checksums_$TS.txt
---A failed dump still leaves a file, so "Dump completed" is the real check.


