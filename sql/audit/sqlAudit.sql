-- Copyright 2021 Ognjen Orel, Petra Udovičić, Bjanka Bašić
--
-- This file is part of ifmx utilities.
--
-- ifmx utilities is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- IFMX Table copy utility is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with ifmx utilities. If not, see <http://www.gnu.org/licenses/>.




--- CONTENT:
-- 0. note on database users performing these tasks
-- 1. configuration tables
-- 2. main SQL audit table and the SQL audit procedure
-- 3. the procedure for handling SQL audit objects (drops and creates SQL audit triggers based on the current configuration)
-- 4. testing



-- PART 0. note on database users performing these tasks
-- A user performing all of the operations below should have a DBA permissions. 
-- The procedure logSql should be created as informix user, a execute permissions to other users should be given as informix user as well.

-- PART 1. Configuration

-- sql audit master switch: sqlAuditEnabled property - t/f
CREATE TABLE _sysProperty (
    key                    CHAR(64)
  , value                  CHAR(64)
  , PRIMARY KEY (key) CONSTRAINT pkSysProperty
);
INSERT INTO _sysProperty VALUES ("sqlAuditEnabled", "f");


-- sql audit table config: _sqlAuditTableConfig
CREATE TABLE _sqlAuditTableConfig (
   sysCatalogTabname       CHAR(64)   -- name of the table
 , enabled                 BOOLEAN    -- is audit enabled for this table or not
 , crudStatementsToAudit   CHAR(4)    -- any combination of letters S, I, U, D (select, insert, update, delete), representing operation(s) to be audited

 , PRIMARY KEY (sysCatalogTabname) CONSTRAINT pkSqlAuditTableConfig 
);

-- sql audit table user exclude list - users in this table are not being audited performing this operation(s)
CREATE TABLE _sqlAuditTableUserExcludeList (
   sysCatalogTabname       CHAR(64)   -- name of the table
 , loginName               CHAR(64)   -- user to be excluded
 , crudStatementsToExclude CHAR(4)    -- any combination of letters S, I, U, D (select, insert, update, delete), representing operation(s) to be excluded

 , PRIMARY KEY (sysCatalogTabname, loginName) CONSTRAINT pkSqlAuditTableUserExcludeList
);

-- sql audit table host exclude list - hosts (servers) in this table are not being audited performing this operation(s)
CREATE TABLE _sqlAuditTableHostExcludeList (
   sysCatalogTabname       CHAR(64)   -- name of the table
 , hostName                CHAR(64)   -- server to be excluded
 , crudStatementsToExclude CHAR(4)    -- any combination of letters S, I, U, D (select, insert, update, delete), representing operation(s) to be excluded

 , PRIMARY KEY (sysCatalogTabname, hostName) CONSTRAINT pkSqlAuditTableHostExcludeList
);



-- PART 2. main SQL audit table and the SQL audit procedure
-- table to store SQL audit
CREATE TABLE _sqlHistory (
   sessionId               INTEGER         -- session identifier
 , sysCatalogTabname       CHAR(64)        -- audited table 
 , operation               CHAR(1)         -- audited operation
 , opuser                  NVARCHAR(32)    -- audited user
 , hostname                CHAR(40)        -- server that initiated connection
 , tty                     CHAR(40)        -- terminal type
 , optimestamp             FLOAT           -- operation timestamp
 , sql                     LVARCHAR(1000)  -- SQL statement
 )
 EXTENT SIZE 2048 NEXT SIZE 4096;


-- audit procedure (!!! CREATE IT AS informix user !!!)
DROP PROCEDURE IF EXISTS logSql;
CREATE PROCEDURE logSql(p_tabName CHAR(64), p_operation CHAR(1));

    DEFINE p_sessId      INTEGER;
    DEFINE p_user        CHAR(64);
    DEFINE p_hostname    CHAR(40);
    DEFINE p_tty         CHAR(40);
    DEFINE p_txtimestamp FLOAT;
    DEFINE p_optimestamp FLOAT;
    DEFINE p_sql         CHAR(255);

    IF NOT EXISTS (SELECT 1 
                     FROM _sysProperty
                    WHERE key = "sqlAuditEnabled"
                      AND value = "t" ) THEN
       RETURN;
    END IF

    LET p_sessId = DBINFO('sessionid');
    LET p_user = USER; 

    IF EXISTS (SELECT 1 
                 FROM _sqlAuditTableUserExcludeList 
                WHERE sysCatalogTabname = p_tabName
                  AND loginName = p_user
                  AND INSTR(crudStatementsToExclude, p_operation) > 1) THEN
       RETURN;
    END IF

    SELECT sysmaster:syssessions.hostname,
           sysmaster:syssessions.tty
      INTO p_hostname, p_tty
      FROM sysmaster:syssessions
     WHERE sid = p_sessId;

    IF EXISTS (SELECT 1 
                FROM _sqlAuditTableHostExcludeList
               WHERE sysCatalogTabname = p_tabName
                 AND hostName = p_hostname
                 AND INSTR(crudStatementsToExclude, p_operation) > 1 ) THEN
       RETURN;
    END IF    

    SELECT sysmaster:syssqlstat.sqs_statement
      INTO p_sql
      FROM sysmaster:syssqlstat
     WHERE sysmaster:syssqlstat.sqs_sessionid = p_sessId;

    INSERT INTO _sqlHistory (sessionid, sysCatalogTabname, operation, opuser, hostname, tty, optimestamp, sql)
                    VALUES (p_sessId, p_tabName, p_operation, p_user, p_hostname, p_tty, CURRENT, p_sql);

END PROCEDURE;
GRANT EXECUTE ON logSql TO public;

-- other statements below should be performed as a DBA, not informix



-- PART 3. the procedure for handling SQL audit objects (drops and creates SQL audit triggers based on the current configuration)

DROP PROCEDURE IF EXISTS handleSqlAuditTriggers;
CREATE PROCEDURE handleSqlAuditTriggers();
   
   DEFINE p_trigName       CHAR(200);
   DEFINE p_tabName        CHAR(64);
   DEFINE p_operation      CHAR(64);
   DEFINE p_operationShort CHAR(1);
   DEFINE p_cmd            LVARCHAR(1000);


   -- one temp tablice is a list of triggers needed, the other is a list of all existing triggers

   CREATE TEMP TABLE IF NOT EXISTS _tmp_sqlaudit_triggers_needed (
      trigName       CHAR(200)
    , tabName        CHAR(64)
    , operation      CHAR(6)
    , operationShort CHAR(1) 
   );

   CREATE TEMP TABLE IF NOT EXISTS _tmp_sqlaudit_triggers_existing (
      trigName CHAR(200)
   );

   TRUNCATE TABLE _tmp_sqlaudit_triggers_needed;
   TRUNCATE TABLE _tmp_sqlaudit_triggers_existing;

   INSERT INTO _tmp_sqlaudit_triggers_needed 
   SELECT "_sqlaudit_" || TRIM(sysCatalogTabname) || "_delete", sysCatalogTabname, "DELETE", "D"
     FROM _sqlAuditTableConfig 
    WHERE enabled = 't' 
      AND crudStatementsToAudit MATCHES "*D*";

   INSERT INTO _tmp_sqlaudit_triggers_needed 
   SELECT "_sqlaudit_" || TRIM(sysCatalogTabname) || "_insert", sysCatalogTabname, "INSERT", "I"
     FROM _sqlAuditTableConfig 
    WHERE enabled = 't' 
      AND crudStatementsToAudit MATCHES "*I*";

   INSERT INTO _tmp_sqlaudit_triggers_needed 
   SELECT "_sqlaudit_" || TRIM(sysCatalogTabname) || "_select", sysCatalogTabname, "SELECT", "S" 
     FROM _sqlAuditTableConfig 
    WHERE enabled = 't' 
      AND crudStatementsToAudit MATCHES "*S*";

   INSERT INTO _tmp_sqlaudit_triggers_needed 
   SELECT "_sqlaudit_" || TRIM(sysCatalogTabname) || "_update", sysCatalogTabname, "UPDATE", "U"
     FROM _sqlAuditTableConfig 
    WHERE enabled = 't' 
      AND crudStatementsToAudit MATCHES "*U*";

   INSERT INTO _tmp_sqlaudit_triggers_existing
   SELECT trigName 
     FROM systriggers
    WHERE trigName MATCHES "_sqlaudit_*";


    -- what's there that shouldn't be:
   FOREACH 
      SELECT trigName 
        INTO p_trigName
        FROM  _tmp_sqlaudit_triggers_existing 
       WHERE trigName NOT IN (SELECT trigName FROM _tmp_sqlaudit_triggers_needed)  

      LET p_cmd = "DROP TRIGGER IF EXISTS " || TRIM(p_trigName);
      EXECUTE IMMEDIATE p_cmd;
   END FOREACH;

   -- what's not there and it should be:
   FOREACH
      SELECT trigName, tabName, operation, operationShort 
        INTO p_trigName, p_tabName, p_operation, p_operationShort
        FROM  _tmp_sqlaudit_triggers_needed 
       WHERE trigName NOT IN (SELECT trigName FROM _tmp_sqlaudit_triggers_existing)  

      LET p_cmd = 'CREATE TRIGGER IF NOT EXISTS ' || TRIM(p_trigName) || ' ' || TRIM(p_operation) || ' ON ' || TRIM(p_tabName) || ' BEFORE ( EXECUTE PROCEDURE logSql("' || TRIM(p_tabName) || '", "' || TRIM(p_operationShort) || '"))';
      EXECUTE IMMEDIATE p_cmd;
   END FOREACH; 

END PROCEDURE;

-- now we can create triggers on the config table, which will call the handleSqlAuditTriggers once the change on the config table is done, 
-- so all adjustments to audit objects are performed automaticaly
CREATE TRIGGER IF NOT EXISTS _sqlAuditTableConfigAfterInsert INSERT ON _sqlAuditTableConfig AFTER ( EXECUTE PROCEDURE handleSqlAuditTriggers() );
CREATE TRIGGER IF NOT EXISTS _sqlAuditTableConfigAfterUpdate UPDATE ON _sqlAuditTableConfig AFTER ( EXECUTE PROCEDURE handleSqlAuditTriggers() );
CREATE TRIGGER IF NOT EXISTS _sqlAuditTableConfigAfterDelete DELETE ON _sqlAuditTableConfig AFTER ( EXECUTE PROCEDURE handleSqlAuditTriggers() );



-- PART 4. testing
-- some trivial examples for testing

CREATE TABLE _sa_test(
    id   INT,
    name CHAR(12)
);

INSERT INTO _sqlAuditTableConfig VALUES ('_sa_test', 't', 'DISU'); 

EXECUTE PROCEDURE handleSqlAuditTriggers();

SELECT trigName 
    FROM systriggers
WHERE trigName MATCHES "_sqlaudit_*";

INSERT INTO _sysProperty VALUES ("sqlAuditEnabled", "t");

INSERT INTO _sa_test VALUES (1, 'jedan');
SELECT * FROM _sqlHistory;

SELECT * FROM _sa_test;
SELECT * FROM _sqlHistory;

UPDATE _sa_test SET name = "jedan ali vrijedan" WHERE id = 1;
SELECT * FROM _sqlHistory;

DELETE FROM _sa_test WHERE id = 1;
SELECT * FROM _sqlHistory;


UPDATE _sysProperty SET value = 'f' WHERE key = "sqlAuditEnabled";

INSERT INTO _sa_test VALUES (1, 'jedan');
SELECT * FROM _sqlHistory;

SELECT * FROM _sa_test;
SELECT * FROM _sqlHistory;

UPDATE _sa_test SET name = "jedan ali vrijedan" WHERE id = 1;
SELECT * FROM _sqlHistory;

DELETE FROM _sa_test WHERE id = 1;
SELECT * FROM _sqlHistory;

DELETE FROM _sqlAuditTableConfig WHERE sysCatalogTabname = '_sa_test';
EXECUTE PROCEDURE handleSqlAuditTriggers();

SELECT trigName 
    FROM systriggers
WHERE trigName MATCHES "_sqlaudit_*";
