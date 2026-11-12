
---Verify client

SELECT clientId, clientName, s3Folder
FROM UDM__.Client
WHERE clientId = 134;

===================================================================================================

clientId|clientName                 |s3Folder                            |
--------+---------------------------+------------------------------------+
     134|Pzena Investment Management|152d92fd-22b4-4498-b55d-48427add3757|

===================================================================================================

---Verify both records before deleting

SELECT documentId, clientId, storagePath, title, created
FROM Documents
WHERE clientId = 134 AND documentId IN (1119129, 1119130);

---Output

documentId|clientId|storagePath                                                      |title                                                                                             |created            |
----------+--------+-----------------------------------------------------------------+--------------------------------------------------------------------------------------------------+-------------------+
   1119130|     134|152d92fd-22b4-4498-b55d-48427add3757/documents/52ZG7ZP1SA1F-1.pdf|Pzena Emerging Markets Value Fund_US Mutual Fund_Morgan Stanley_Quarterly Factsheet_2026-09-30.pdf|2026-10-14 16:44:55|
   1119129|     134|152d92fd-22b4-4498-b55d-48427add3757/documents/52ZG7ZP1SA1F-1.pdf|Pzena Emerging Markets Value Fund_US Mutual Fund_Morgan Stanley_Quarterly Factsheet_2026-09-30.pdf|2026-10-14 16:44:55|

===================================================================================================

---Counts Query

Documents

SELECT COUNT(*) FROM Documents WHERE clientId = 134 AND documentId = 1119130;

DocumentBackup

SELECT COUNT(*) FROM DocumentBackup WHERE clientId = 134 AND documentId = 1119130;

DocumentBackupStub

SELECT COUNT(*) FROM DocumentBackupStub WHERE clientId = 134 AND documentId = 1119130;

===================================================================================================

---Counts Before Deletion

Documents

count(*)|
--------+
       1|

DocumentBackup

count(*)|
--------+
       0|

DocumentBackupStub

count(*)|
--------+
       0|

Note: DocumentBackup and DocumentBackupStub returned 0 records for documentId 1119130, therefore they have not been included in the delete script.

===================================================================================================

---Backup Taken

mkdir /tmp/KSYS-14933
cd /tmp/KSYS-14933

mysqldump -h0 -uroot -p'' --hex-blob --no-create-info --max_allowed_packet=512M UDM__ Documents \
  --where="clientId=134 AND documentId=1119130" \
  > Documents_backup_1119130.sql

---Verify dump
cat Documents_backup_1119130.sql

===================================================================================================

---Delete Script Executed

DELETE FROM Documents WHERE clientId = 134 AND documentId = 1119130;

===================================================================================================

---Counts After Deletion

Documents

count(*)|
--------+
       0|

DocumentBackup

count(*)|
--------+
       0|

DocumentBackupStub

count(*)|
--------+
       0|

===================================================================================================

---Verify only 1119129 remains

SELECT documentId, clientId, storagePath, title, created
FROM Documents
WHERE clientId = 134 AND documentId IN (1119129, 1119130);

===================================================================================================

---Bump the cache

SELECT clientId, lastModified, lastFlush
FROM WarpdriveCache
WHERE clientId = 134;

UPDATE WarpdriveCache
SET lastModified = NOW()
WHERE clientId = 134;

SELECT clientId, lastModified, lastFlush
FROM WarpdriveCache
WHERE clientId = 134;

===================================================================================================

---Rollback if needed

mysql -h0 -uroot -p'' UDM__ < /tmp/KSYS-14933/Documents_backup_1119130.sql

===================================================================================================
