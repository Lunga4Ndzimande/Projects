#!/usr/bin/env bash
# =====================================================================
# TECH-4399 / KSYS-12922  -  Drop AIProvider schema, purge Secrets,
# strip AIProviders from Client.modules
# ENVIRONMENT : REL  (UDM__ on SingleStore)
# REL numbers : providers 3 | calls 85 | matching secrets 3
#                 clients with module 15 | ChartAI baseline 17
#                 total Secrets 2203 (expect 2200 after)
#
# HOW TO USE THIS SCRIPT
# - Run ONE step at a time. Do not run "all" unless you mean it.
# - Run on the REL jumpbox. Never paste this into mysql> or DBeaver.
# - Accounts: CSE = read-only (inventory, dumps).
#             root = writes (delete, update). Type passwords only at
#             the prompt, never in the command or in chat.
# - Stop and paste the output if ANY number differs from "expect".
# - Writes (5b, 7c) never run unless you pass --write AND confirm.
#
# Usage:
#   export DBHOST=PUT-THE-REAL-REL-HOST-HERE
#   chmod 700 ksys-12922-rel.sh
#   ./ksys-12922-rel.sh <step> [--write]
#
# Steps: 0 1 2 2a 2b 2c 2d 2e 2f 3 3a 3b 3c 3d 3e
#        4 5 5a 5b 5c 6 6a 6b 6c 7 7a 7b 7c 7d 8 9 9a 9b 9c 10 11
# =====================================================================
set -euo pipefail

# --- expected REL baselines (do not change unless ticket numbers change) ---
EXPECT_PROVIDERS=3
EXPECT_CALLS=85
EXPECT_MATCHING_SECRETS=3
EXPECT_CLIENTS_WITH_MODULE=15
EXPECT_CHARTAI=17
EXPECT_TOTAL_SECRETS=2203
EXPECT_TOTAL_SECRETS_AFTER=2200

SECRET_IDS="'a9f0e991-cfa3-44a9-a794-85a146bd7573','7d9582b0-5dc0-48ca-80f7-b3c5ebd82b42','25b6b4fc-1367-42e0-a949-47f902060ff2'"
SECRET_CLIENT_ID=53
DUMP_DIR=/tmp/KSYS-12922-rel
DBNAME=UDM__

WRITE=0
STEP=""

usage() {
  sed -n '1,35p' "$0" | sed 's/^# \?//'
  exit 1
}

for arg in "$@"; do
  case "$arg" in
    --write) WRITE=1 ;;
    -h|--help|help) usage ;;
    *)
      if [[ -z "$STEP" ]]; then STEP="$arg"; else
        echo "Unexpected argument: $arg" >&2
        usage
      fi
      ;;
  esac
done

[[ -n "$STEP" ]] || usage

need_dbhost() {
  if [[ -z "${DBHOST:-}" ]]; then
    echo "Set DBHOST to the real REL host from DBeaver, then re-run." >&2
    echo "  export DBHOST=PUT-THE-REAL-REL-HOST-HERE" >&2
    exit 1
  fi
}

assert_rel_host() {
  local hn="$1"
  case "$hn" in
    *rel*|*REL*) ;;
    *)
      echo "STOP: hostname does not contain 'rel': $hn" >&2
      exit 1
      ;;
  esac
}

expect_eq() {
  local label="$1" got="$2" want="$3"
  if [[ "$got" != "$want" ]]; then
    echo "STOP: $label is '$got' (expect $want). Paste this output; do not continue." >&2
    exit 1
  fi
  echo "OK: $label=$got (expect $want)"
}

# Password is never on the argv of mysql. Extra file is mode 600 and removed on exit.
CNF=""
cleanup() {
  if [[ -n "$CNF" && -f "$CNF" ]]; then
    rm -f "$CNF"
  fi
}
trap cleanup EXIT

prompt_mysql() {
  local user="$1"
  need_dbhost
  CNF=$(mktemp)
  chmod 600 "$CNF"
  local pw
  read -r -s -p "${user} password: " pw
  echo
  {
    echo "[client]"
    echo "host=${DBHOST}"
    echo "user=${user}"
    echo "password=${pw}"
    echo "database=${DBNAME}"
  } > "$CNF"
}

mysql_q() {
  mysql --defaults-extra-file="$CNF" --batch --raw --skip-column-names -e "$1"
}

mysql_t() {
  mysql --defaults-extra-file="$CNF" -e "$1"
}

dump_opts=(
  --defaults-extra-file="$CNF"
  --column-statistics=0
  --hex-blob
  --skip-lock-tables
  --skip-disable-keys
  --skip-add-locks
  --max_allowed_packet=512M
)

require_write() {
  if [[ "$WRITE" -ne 1 ]]; then
    echo "This step CHANGES data. Re-run with --write after dumps and checks passed." >&2
    echo "Example: $0 $STEP --write" >&2
    exit 1
  fi
}

need_ts() {
  if [[ -z "${TS:-}" ]]; then
    echo "TS is not set. Keep the same shell after step 3a, or:" >&2
    echo "  export TS=YYYYMMDD-HHMMSS" >&2
    echo "  export DBHOST=...   # still required" >&2
    exit 1
  fi
}

# =====================================================================
# STEP 0 - PREREQUISITES (no SQL)
# =====================================================================
step0() {
  cat <<'EOF'
STEP 0 - PREREQUISITES (no SQL)
- KSYS-12922 is Done
- TECH-4399's parent TECH-4398 shows udm_ai uninstalled in REL
- Someone agrees REL rows can be deleted (ticket says not retained)
EOF
  read -r -p "Type YES if all three are true: " a
  [[ "$a" == "YES" ]] || { echo "Aborted."; exit 1; }
  echo "OK: prerequisites confirmed"
}

# =====================================================================
# STEP 1 - CONFIRM ENVIRONMENT (read-only, CSE)
# =====================================================================
step1() {
  prompt_mysql CSE
  echo "STEP 1 - CONFIRM ENVIRONMENT (read-only)"
  mysql_t "SELECT @@hostname, DATABASE(), CURRENT_USER();"
  local hn db
  hn=$(mysql_q "SELECT @@hostname")
  db=$(mysql_q "SELECT DATABASE()")
  assert_rel_host "$hn"
  if [[ "$db" != "$DBNAME" ]]; then
    echo "STOP: DATABASE() is '$db' (expect $DBNAME). Connection must use $DBNAME." >&2
    exit 1
  fi
  echo "OK: host=$hn database=$db"
}

# =====================================================================
# STEP 2 - INVENTORY (read-only). Attach results to the ticket.
# =====================================================================
step2a() {
  prompt_mysql CSE
  echo "STEP 2a - Do the tables exist? (2 rows expected on REL)"
  mysql_t "SELECT TABLE_NAME FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('AIProvider','AIProviderCall');"
  local n
  n=$(mysql_q "SELECT COUNT(*) FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('AIProvider','AIProviderCall')")
  expect_eq "tables" "$n" "2"
}

step2b() {
  prompt_mysql CSE
  echo "STEP 2b - Counts + ChartAI baseline. Expect $EXPECT_PROVIDERS | $EXPECT_CALLS | $EXPECT_MATCHING_SECRETS | $EXPECT_CLIENTS_WITH_MODULE | $EXPECT_CHARTAI | $EXPECT_TOTAL_SECRETS"
  mysql_t "SELECT
  (SELECT COUNT(*) FROM AIProvider)     AS providers,
  (SELECT COUNT(*) FROM AIProviderCall) AS calls,
  (SELECT COUNT(*) FROM Secrets WHERE id IN
      (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL)) AS matching_secrets,
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%') AS clients_with_module,
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%')     AS chartai_baseline,
  (SELECT COUNT(*) FROM Secrets) AS total_secrets;"
  local providers calls matching clients chartai total
  providers=$(mysql_q "SELECT COUNT(*) FROM AIProvider")
  calls=$(mysql_q "SELECT COUNT(*) FROM AIProviderCall")
  matching=$(mysql_q "SELECT COUNT(*) FROM Secrets WHERE id IN (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL)")
  clients=$(mysql_q "SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%'")
  chartai=$(mysql_q "SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%'")
  total=$(mysql_q "SELECT COUNT(*) FROM Secrets")
  expect_eq "providers" "$providers" "$EXPECT_PROVIDERS"
  expect_eq "calls" "$calls" "$EXPECT_CALLS"
  expect_eq "matching_secrets" "$matching" "$EXPECT_MATCHING_SECRETS"
  expect_eq "clients_with_module" "$clients" "$EXPECT_CLIENTS_WITH_MODULE"
  expect_eq "chartai_baseline" "$chartai" "$EXPECT_CHARTAI"
  expect_eq "total_secrets" "$total" "$EXPECT_TOTAL_SECRETS"
}

step2c() {
  prompt_mysql CSE
  echo "STEP 2c - Providers and their credentials (no secret values shown)"
  mysql_t "SELECT p.aiProviderId, p.clientId, p.name, p.credentialId, s.id AS secret_id
FROM AIProvider p LEFT JOIN Secrets s ON s.id = p.credentialId;"
}

step2d() {
  prompt_mysql CSE
  echo "STEP 2d - Owning client (expect client 53, Kurtovest Demo)"
  mysql_t "SELECT DISTINCT c.clientId, c.clientName, c.s3Folder
FROM AIProvider p JOIN Client c ON c.clientId = p.clientId
ORDER BY c.clientId;"
}

step2e() {
  prompt_mysql CSE
  echo "STEP 2e - Any client with the token more than once? (expect NO rows)"
  mysql_t "SELECT clientId,
  (LENGTH(CAST(modules AS CHAR)) - LENGTH(REPLACE(CAST(modules AS CHAR), 'AIProviders', '')))
    / LENGTH('AIProviders') AS occ
FROM Client
WHERE CAST(modules AS CHAR) LIKE '%AIProviders%'
HAVING occ > 1;"
  local n
  n=$(mysql_q "SELECT COUNT(*) FROM (
SELECT clientId,
  (LENGTH(CAST(modules AS CHAR)) - LENGTH(REPLACE(CAST(modules AS CHAR), 'AIProviders', '')))
    / LENGTH('AIProviders') AS occ
FROM Client
WHERE CAST(modules AS CHAR) LIKE '%AIProviders%'
HAVING occ > 1
) t")
  expect_eq "duplicate_token_rows" "$n" "0"
}

step2f() {
  prompt_mysql CSE
  echo "STEP 2f - Token position (expect 15 rows, pos > 0 on every row)"
  mysql_t "SELECT clientId, JSON_LENGTH(modules) AS n,
       LOCATE('AIProviders', CAST(modules AS CHAR)) AS pos
FROM Client
WHERE CAST(modules AS CHAR) LIKE '%AIProviders%'
ORDER BY clientId;"
  local n zeros
  n=$(mysql_q "SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%'")
  zeros=$(mysql_q "SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%' AND LOCATE('AIProviders', CAST(modules AS CHAR)) = 0")
  expect_eq "clients_with_module" "$n" "$EXPECT_CLIENTS_WITH_MODULE"
  expect_eq "pos_zero_rows" "$zeros" "0"
}

step2() {
  step2a
  cleanup; CNF=""
  step2b
  cleanup; CNF=""
  step2c
  cleanup; CNF=""
  step2d
  cleanup; CNF=""
  step2e
  cleanup; CNF=""
  step2f
}

# =====================================================================
# STEP 3 - BACKUP WITH MYSQLDUMP (read-only, CSE, REL jumpbox)
# =====================================================================
step3a() {
  need_dbhost
  echo "STEP 3a - Variables and folder"
  getent hosts "$DBHOST" || true
  nc -zv "$DBHOST" 3306
  umask 077
  mkdir -p "$DUMP_DIR"
  chmod 700 "$DUMP_DIR"
  cd "$DUMP_DIR"
  TS=$(date +%Y%m%d-%H%M%S)
  echo "$TS"
  echo
  echo "Keep this shell open. Export these before later steps:"
  echo "  export DBHOST=$DBHOST"
  echo "  export TS=$TS"
  echo "  cd $DUMP_DIR"
}

step3b() {
  need_dbhost
  need_ts
  prompt_mysql CSE
  cd "$DUMP_DIR"
  echo "STEP 3b - Secrets: the 3 REL credentials"
  mysqldump "${dump_opts[@]}" --no-create-info --complete-insert "$DBNAME" Secrets \
    --where="id IN (${SECRET_IDS})" \
    > "Secrets_aiprovider_backup_${TS}.sql"
  echo "Wrote $DUMP_DIR/Secrets_aiprovider_backup_${TS}.sql"
}

step3c() {
  need_dbhost
  need_ts
  prompt_mysql CSE
  cd "$DUMP_DIR"
  echo "STEP 3c - Client rows that have the module (15 rows)"
  mysqldump "${dump_opts[@]}" --no-create-info --complete-insert --replace "$DBNAME" Client \
    --where="CAST(modules AS CHAR) LIKE '%AIProviders%'" \
    > "Client_modules_backup_${TS}.sql"
  echo "Wrote $DUMP_DIR/Client_modules_backup_${TS}.sql"
}

step3d() {
  need_dbhost
  need_ts
  prompt_mysql CSE
  cd "$DUMP_DIR"
  echo "STEP 3d - The two tables (structure + data)"
  mysqldump "${dump_opts[@]}" --complete-insert "$DBNAME" AIProvider AIProviderCall \
    > "AIProvider_tables_backup_${TS}.sql"
  echo "Wrote $DUMP_DIR/AIProvider_tables_backup_${TS}.sql"
}

step3e() {
  need_ts
  cd "$DUMP_DIR"
  echo "STEP 3e - Verify. DO NOT CONTINUE unless every check passes."
  ls -l
  local secrets_n clients_n inserts
  secrets_n=$(grep -o "'[0-9a-f-]\{36\}'" "Secrets_aiprovider_backup_${TS}.sql" | sort -u | wc -l | tr -d ' ')
  clients_n=$(grep -o "([0-9]*,'" "Client_modules_backup_${TS}.sql" | wc -l | tr -d ' ')
  inserts=$(grep -c "INSERT INTO" "AIProvider_tables_backup_${TS}.sql" || true)
  echo "unique secret uuids=$secrets_n (expect 3)"
  echo "client insert tuples=$clients_n (expect 15)"
  echo "INSERT INTO count=$inserts (expect at least 2)"
  expect_eq "secret_uuids_in_dump" "$secrets_n" "3"
  expect_eq "client_rows_in_dump" "$clients_n" "15"
  if [[ "$inserts" -lt 2 ]]; then
    echo "STOP: INSERT INTO count is $inserts (expect at least 2)" >&2
    exit 1
  fi
  echo "---- last 2 lines of each dump ----"
  tail -n 2 *_"${TS}".sql
  if ! grep -q -- "-- Dump completed" "Secrets_aiprovider_backup_${TS}.sql" \
     || ! grep -q -- "-- Dump completed" "Client_modules_backup_${TS}.sql" \
     || ! grep -q -- "-- Dump completed" "AIProvider_tables_backup_${TS}.sql"; then
    echo "STOP: a dump file does not end with -- Dump completed" >&2
    exit 1
  fi
  sha256sum ./*_"${TS}".sql > "checksums_${TS}.txt"
  cat "checksums_${TS}.txt"
  echo "OK: dumps verified. Attach checksums_${TS}.txt to the ticket. Do NOT attach the Secrets dump."
}

step3() {
  step3a
  echo
  echo "TS=$TS is now set in this process only."
  echo "Re-export TS in your shell if you will run later steps in a new process:"
  echo "  export TS=$TS"
  export TS
  step3b
  cleanup; CNF=""
  step3c
  cleanup; CNF=""
  step3d
  cleanup; CNF=""
  step3e
}

# =====================================================================
# STEP 4 - SWITCH TO A WRITE ACCOUNT (root) AND RE-CHECK ENVIRONMENT
# =====================================================================
step4() {
  prompt_mysql root
  echo "STEP 4 - CONFIRM ENVIRONMENT as root"
  mysql_t "SELECT @@hostname, DATABASE(), CURRENT_USER();"
  local hn db user
  hn=$(mysql_q "SELECT @@hostname")
  db=$(mysql_q "SELECT DATABASE()")
  user=$(mysql_q "SELECT CURRENT_USER()")
  assert_rel_host "$hn"
  [[ "$db" == "$DBNAME" ]] || { echo "STOP: DATABASE() is $db" >&2; exit 1; }
  case "$user" in
    root@*|root) ;;
    *) echo "STOP: CURRENT_USER() is '$user' (expect root)" >&2; exit 1 ;;
  esac
  echo "OK: host=$hn user=$user"
}

# =====================================================================
# STEP 5 - DELETE THE 3 SECRETS (must run BEFORE the tables are dropped)
# =====================================================================
step5a() {
  prompt_mysql root
  echo "STEP 5a - Count before. Expect 3."
  mysql_t "SELECT COUNT(*) AS before_delete FROM Secrets
WHERE id IN (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL);"
  local n
  n=$(mysql_q "SELECT COUNT(*) FROM Secrets WHERE id IN (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL)")
  expect_eq "before_delete" "$n" "3"
}

step5b() {
  require_write
  prompt_mysql root
  local hn
  hn=$(mysql_q "SELECT @@hostname")
  assert_rel_host "$hn"
  echo "STEP 5b - [WRITE] Delete the 3 secrets."
  echo "Prerequisites: Step 3e passed, Step 4 shows a REL host, 5a returned 3."
  read -r -p "Type REL to run the DELETE: " a
  [[ "$a" == "REL" ]] || { echo "Aborted."; exit 1; }
  mysql_t "DELETE FROM Secrets
WHERE id IN (${SECRET_IDS})
  AND clientId = ${SECRET_CLIENT_ID};"
  echo "DELETE executed."
}

step5c() {
  prompt_mysql root
  echo "STEP 5c - Check."
  mysql_t "SELECT
  (SELECT COUNT(*) FROM Secrets WHERE id IN
      (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL)) AS matching_left,
  (SELECT COUNT(*) FROM Secrets)    AS total_now,
  (SELECT COUNT(*) FROM AIProvider) AS providers_untouched;"
}

step5c_expect() {
  local want_matching="$1" want_total="$2"
  local matching total providers
  matching=$(mysql_q "SELECT COUNT(*) FROM Secrets WHERE id IN (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL)")
  total=$(mysql_q "SELECT COUNT(*) FROM Secrets")
  providers=$(mysql_q "SELECT COUNT(*) FROM AIProvider")
  expect_eq "matching_left" "$matching" "$want_matching"
  expect_eq "total_now" "$total" "$want_total"
  expect_eq "providers_untouched" "$providers" "$EXPECT_PROVIDERS"
}

step5() {
  step5a
  cleanup; CNF=""
  if [[ "$WRITE" -eq 1 ]]; then
    step5b
    cleanup; CNF=""
  else
    echo "Skipping 5b (no --write). CSE/root SELECT only so far."
  fi
  step5c
  if [[ "$WRITE" -eq 1 ]]; then
    step5c_expect 0 "$EXPECT_TOTAL_SECRETS_AFTER"
  fi
}

# =====================================================================
# STEP 6 - TEST THE RESTORE
# =====================================================================
step6a() {
  require_write
  need_dbhost
  need_ts
  cd "$DUMP_DIR"
  prompt_mysql root
  echo "STEP 6a - Restore the Secrets from the dump (as root)"
  if ! mysql --defaults-extra-file="$CNF" "$DBNAME" < "Secrets_aiprovider_backup_${TS}.sql"; then
    echo "Restore complained; retrying without ALTER/LOCK lines"
    grep -v "ALTER TABLE\|LOCK TABLES\|UNLOCK TABLES" "Secrets_aiprovider_backup_${TS}.sql" \
      | mysql --defaults-extra-file="$CNF" "$DBNAME"
  fi
}

step6b() {
  prompt_mysql root
  echo "STEP 6b - Re-run 5c. Expect matching_left 3 | total_now 2203"
  mysql_t "SELECT
  (SELECT COUNT(*) FROM Secrets WHERE id IN
      (SELECT credentialId FROM AIProvider WHERE credentialId IS NOT NULL)) AS matching_left,
  (SELECT COUNT(*) FROM Secrets)    AS total_now,
  (SELECT COUNT(*) FROM AIProvider) AS providers_untouched;"
  step5c_expect 3 "$EXPECT_TOTAL_SECRETS"
}

step6c() {
  require_write
  echo "STEP 6c - Run 5b again so REL ends clean, then 5c."
  echo "Expect matching_left 0 | total_now 2200"
  step5b
  cleanup; CNF=""
  step5c
  step5c_expect 0 "$EXPECT_TOTAL_SECRETS_AFTER"
}

step6() {
  if [[ "$WRITE" -ne 1 ]]; then
    echo "Step 6 restores then re-deletes. Re-run: $0 6 --write" >&2
    exit 1
  fi
  step6a
  cleanup; CNF=""
  step6b
  cleanup; CNF=""
  step6c
}

# =====================================================================
# STEP 7 - STRIP "AIProviders" FROM Client.modules (15 clients)
# =====================================================================
STRIP_SQL="UPDATE Client SET modules = REPLACE(REPLACE(REPLACE(CAST(modules AS CHAR),
      CONCAT(',', CHAR(34), 'AIProviders', CHAR(34)), ''),
      CONCAT(CHAR(34), 'AIProviders', CHAR(34), ','), ''),
      CONCAT('[', CHAR(34), 'AIProviders', CHAR(34), ']'), '[]')
    WHERE CAST(modules AS CHAR) LIKE '%AIProviders%';"

step7a() {
  prompt_mysql CSE
  echo "STEP 7a - PREVIEW. Expect 15 rows, after_n = before_n - 1 on EVERY row, still_has_token = 0."
  mysql_t "SELECT clientId,
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
ORDER BY clientId;"
  local bad
  bad=$(mysql_q "SELECT COUNT(*) FROM (
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
) t WHERE after_n <> before_n - 1 OR still_has_token <> 0")
  local n
  n=$(mysql_q "SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%'")
  expect_eq "preview_rows" "$n" "$EXPECT_CLIENTS_WITH_MODULE"
  expect_eq "preview_bad_rows" "$bad" "0"
}

step7b() {
  prompt_mysql root
  echo "STEP 7b - DRY RUN (transaction + ROLLBACK). Expect should_be_0=0 | chartai_same=17 | back_to_original=15"
  mysql --defaults-extra-file="$CNF" --table "$DBNAME" <<SQL
START TRANSACTION;
${STRIP_SQL}
SELECT COUNT(*) AS should_be_0 FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%';
SELECT COUNT(*) AS chartai_same FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%';
ROLLBACK;
SELECT COUNT(*) AS back_to_original FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%';
SQL
  local back
  back=$(mysql_q "SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%'")
  expect_eq "back_to_original" "$back" "$EXPECT_CLIENTS_WITH_MODULE"
  if [[ "$back" == "0" ]]; then
    echo "STOP: rollback did not work. Restore from Client_modules_backup_\$TS.sql" >&2
    exit 1
  fi
}

step7c() {
  require_write
  need_dbhost
  prompt_mysql root
  echo "STEP 7c - [WRITE] REAL UPDATE, GUARDED"
  local hn pre_ai pre_ch post_ai post_ch
  hn=$(mysql_q "SELECT @@hostname")
  echo "Host: $hn"
  assert_rel_host "$hn"
  pre_ai=$(mysql_q "SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%'")
  pre_ch=$(mysql_q "SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%'")
  echo "AIProviders=$pre_ai (expect 15)  ChartAI=$pre_ch (expect 17)"
  expect_eq "AIProviders" "$pre_ai" "15"
  expect_eq "ChartAI" "$pre_ch" "17"
  read -r -p "Type REL to run the UPDATE: " a
  [[ "$a" == "REL" ]] || { echo "Aborted."; exit 1; }
  mysql_t "$STRIP_SQL"
  post_ai=$(mysql_q "SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%'")
  post_ch=$(mysql_q "SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%'")
  if [[ "$post_ai" == "0" && "$post_ch" == "$pre_ch" ]]; then
    echo "PASS ($post_ai / $post_ch)"
  else
    echo "FAIL ($post_ai / $post_ch) - restore: mysql --defaults-extra-file=... $DBNAME < Client_modules_backup_<TS>.sql" >&2
    exit 1
  fi
}

step7d() {
  prompt_mysql CSE
  echo "STEP 7d - Check. Expect should_be_0 = 0 | chartai = 17"
  mysql_t "SELECT
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%') AS should_be_0,
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%')     AS chartai;"
  local a c
  a=$(mysql_q "SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%'")
  c=$(mysql_q "SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%'")
  expect_eq "should_be_0" "$a" "0"
  expect_eq "chartai" "$c" "$EXPECT_CHARTAI"
}

step7() {
  step7a
  cleanup; CNF=""
  step7b
  cleanup; CNF=""
  if [[ "$WRITE" -eq 1 ]]; then
    step7c
    cleanup; CNF=""
    step7d
  else
    echo "Skipping 7c (no --write). Dry-run only."
  fi
}

# =====================================================================
# STEP 8 - DEPLOY THE UPGRADE (manual)
# =====================================================================
step8() {
  cat <<'EOF'
STEP 8 - DEPLOY THE UPGRADE
Deploy the ksysUDM upgrade from branch
feature/KSYS-12922-drop-aiprovider-tables-and-module-seeds
through the usual DB upgrade path. REVIEW the SQL first: it should
drop AIProviderCall, then AIProvider, then remove the AIProviders
module, 4 permissions, CREATE/UPDATE/DELETE activity types and
TableId rows. (Seed rows are NOT in the dumps above; dump them first
if you want a full rollback.)
EOF
}

# =====================================================================
# STEP 9 - VERIFY ACCEPTANCE CRITERIA
# =====================================================================
step9a() {
  prompt_mysql CSE
  echo "STEP 9a - Tables gone (expect NO rows)"
  mysql_t "SELECT TABLE_NAME FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('AIProvider','AIProviderCall');"
  local n
  n=$(mysql_q "SELECT COUNT(*) FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('AIProvider','AIProviderCall')")
  expect_eq "tables_left" "$n" "0"
}

step9b() {
  prompt_mysql CSE
  echo "STEP 9b - No client still lists the module; ChartAI unchanged (0 and 17)"
  mysql_t "SELECT
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%') AS should_be_0,
  (SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%')     AS chartai_17;"
  local a c
  a=$(mysql_q "SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%AIProviders%'")
  c=$(mysql_q "SELECT COUNT(*) FROM Client WHERE CAST(modules AS CHAR) LIKE '%ChartAI%'")
  expect_eq "should_be_0" "$a" "0"
  expect_eq "chartai_17" "$c" "17"
}

step9c() {
  prompt_mysql CSE
  echo "STEP 9c - The 3 Secrets are gone (expect 0)"
  mysql_t "SELECT COUNT(*) AS should_be_0 FROM Secrets
WHERE id IN (${SECRET_IDS});"
  local n
  n=$(mysql_q "SELECT COUNT(*) FROM Secrets WHERE id IN (${SECRET_IDS})")
  expect_eq "secrets_left" "$n" "0"
}

step9() {
  step9a
  cleanup; CNF=""
  step9b
  cleanup; CNF=""
  step9c
  echo
  echo "STEP 9d - Module, permissions, activity types, TableId rows:"
  echo "See udm_db/artifacts/upgrades/2026-09-15-drop-ai-provider-tables.sql"
  echo "TODO: add the exact verification SELECTs from that file's DELETE conditions."
  echo "Historical Activity rows are expected to remain."
}

# =====================================================================
# STEP 10 - FULL ROLLBACK (only if something goes wrong; run as root)
# =====================================================================
step10() {
  require_write
  need_dbhost
  need_ts
  cd "$DUMP_DIR"
  prompt_mysql root
  echo "STEP 10 - FULL ROLLBACK (data only, not app code or udm_ai)"
  echo "LIMITS: only the 3 secrets restore is tested. Seed-row deletes are NOT backed up here."
  read -r -p "Type ROLLBACK to restore dumps: " a
  [[ "$a" == "ROLLBACK" ]] || { echo "Aborted."; exit 1; }
  mysql --defaults-extra-file="$CNF" "$DBNAME" < "AIProvider_tables_backup_${TS}.sql"
  mysql --defaults-extra-file="$CNF" "$DBNAME" < "Client_modules_backup_${TS}.sql"
  mysql --defaults-extra-file="$CNF" "$DBNAME" < "Secrets_aiprovider_backup_${TS}.sql" || {
    echo "Secrets restore: if row exists, DELETE first then retry the dump."
    exit 1
  }
  echo "Re-run: $0 2b   Expect 3 | 85 | 3 | 15 | 17 | 2203"
}

# =====================================================================
# STEP 11 - EVIDENCE AND CLEANUP
# =====================================================================
step11() {
  cat <<EOF
STEP 11 - EVIDENCE AND CLEANUP
Attach to the ticket: Step 1 hostname, Step 2 counts, checksums_\$TS.txt,
Step 5c, 7a, 7d and 9a-9c results. NOT the Secrets dump.
After sign-off: delete the dump files (especially the Secrets one).
  rm -rf ${DUMP_DIR}
EOF
}

case "$STEP" in
  0) step0 ;;
  1) step1 ;;
  2) step2 ;;
  2a) step2a ;;
  2b) step2b ;;
  2c) step2c ;;
  2d) step2d ;;
  2e) step2e ;;
  2f) step2f ;;
  3) step3 ;;
  3a) step3a ;;
  3b) step3b ;;
  3c) step3c ;;
  3d) step3d ;;
  3e) step3e ;;
  4) step4 ;;
  5) step5 ;;
  5a) step5a ;;
  5b) step5b ;;
  5c) step5c ;;
  6) step6 ;;
  6a) step6a ;;
  6b) step6b ;;
  6c) step6c ;;
  7) step7 ;;
  7a) step7a ;;
  7b) step7b ;;
  7c) step7c ;;
  7d) step7d ;;
  8) step8 ;;
  9) step9 ;;
  9a) step9a ;;
  9b) step9b ;;
  9c) step9c ;;
  10) step10 ;;
  11) step11 ;;
  *)
    echo "Unknown step: $STEP" >&2
    usage
    ;;
esac
