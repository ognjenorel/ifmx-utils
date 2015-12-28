-- Copyright 2013 Ognjen Orel
--
-- This file is part of IFMX Table copy utility.
--
-- IFMX Table copy utility is free software: you can redistribute it and/or modify
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
-- along with IFMX Table copy utility. If not, see <http://www.gnu.org/licenses/>.


-------------------------------------------------------------------------------
-- The function to copy table to another table, along with all constraints and indexes
-- Arguments:
--   - source table
--   - name of destination table
--   - the dbspace to create new table in, if null than default is used
--   - should the function just return sql statements to be executed manualy (false), or really execute them (true)
-- Return values:
--   - sql statements to create and populate table and create constraints and indexes (if last argument was false) OR
--   - messages regarding the execution of those statements (if last argument was true)
CREATE FUNCTION tableCopy(
        p_tabName LIKE systables.tabname,
        p_newTabName LIKE systables.tabname,
        p_dbspace CHAR(32),
        p_doExecute BOOLEAN)

    RETURNING LVARCHAR(1024);

    DEFINE p_tabId LIKE systables.tabid;

    DEFINE p_lockLevel VARCHAR(30);
    DEFINE p_extentSize VARCHAR(30);
    DEFINE p_nextSize VARCHAR(30);

    DEFINE p_colName LIKE syscolumns.colname;
    DEFINE p_colType VARCHAR(128);
    DEFINE p_colLength SMALLINT;
    DEFINE p_colDigits SMALLINT;
    DEFINE p_colDecimals SMALLINT;
    DEFINE p_colUpperQ VARCHAR(15);
    DEFINE p_colLowerQ VARCHAR(15);
    DEFINE p_colNotNull VARCHAR(8);
    DEFINE p_colDefault LIKE sysdefaults.default;

    DEFINE p_executeStatement LVARCHAR(1024);

    DEFINE p_fkIdxName, p_fkRefPkIdxName LIKE sysindexes.idxname;
    DEFINE p_fkRefTabName LIKE systables.tabname;
    DEFINE p_fkRefTabId LIKE systables.tabid;

    DEFINE p_constrName LIKE sysconstraints.constrname;
    DEFINE p_constrId LIKE sysconstraints.constrid;
    DEFINE p_checkText LIKE syschecks.checktext;

    DEFINE p_idxName LIKE sysindexes.idxname;
    DEFINE p_idxType VARCHAR(6);
    DEFINE p_colList LVARCHAR(1024);
    DEFINE p_refColList LVARCHAR(1024);

    LET p_tabName = LOWER(TRIM(p_tabName));

    IF p_doExecute IS NULL THEN
        LET p_doExecute = 'f';
    END IF

    SELECT tabid INTO p_tabId FROM systables WHERE tabName = p_tabName AND tabtype = 'T';
    IF p_tabId IS NULL THEN
        RAISE EXCEPTION -746, 0, 'Only tables, not views or synonyms, can be copied.';
    END IF

    IF EXISTS (SELECT 1 FROM systables WHERE tabName = p_newTabName) THEN
        RAISE EXCEPTION -746, 0, 'New table name (' || p_newTabName || ') already exists in database';
    END IF

    LET p_executeStatement = 'CREATE TABLE ' || p_newTabName || ' (';

    -- column names, types
    FOREACH
        SELECT TRIM(colname),
        DECODE (CASE WHEN coltype >= 256 THEN coltype - 256 ELSE coltype END
             , 0, 'CHAR'             , 1, 'SMALLINT'             , 2, 'INTEGER'
             , 3, 'FLOAT'            , 4, 'SMALLFLOAT'           , 5, 'DECIMAL'
             , 6, 'SERIAL'           , 7, 'DATE'                 , 8, 'MONEY'
             , 10, 'DATETIME'        , 11, 'BYTE'                , 12, 'TEXT'
             , 13, 'VARCHAR'         , 14, 'INTERVAL'            , 15, 'NCHAR'
             , 16, 'NVARCHAR'        , 17, 'INT8'                , 18, 'SERIAL8'
             , 19, 'SET'             , 20, 'MULTISET'            , 21, 'LIST'
             , 22, 'ROW'             , 23, 'COLLECTION'          , 40, 'LVARCHAR'
             , 43, 'LVARCHAR'        , 45, 'BOOLEAN'             , 52, 'BIGINT'
             , 53, 'BIGSERIAL'
             , 41, (SELECT UPPER(name) FROM sysxtdtypes
                      WHERE sysxtdtypes.extended_id = syscolumns.extended_id)
             , NULL)::VARCHAR(128) type,

        CASE WHEN coltype IN (0, 15, 40, 256, 271, 296) THEN collength
               WHEN coltype IN (13, 16, 269, 272) AND collength < 0 THEN MOD(collength + 65536, 256)
               WHEN coltype IN (13, 16, 269, 272) AND collength >= 0 THEN MOD(collength, 256)
               ELSE NULL
        END::SMALLINT collength,

        CASE WHEN coltype IN (5, 261) THEN (collength/256)
             ELSE NULL
        END::SMALLINT digits,

        CASE WHEN coltype IN (5, 261) THEN MOD(collength, 256)
             ELSE NULL
        END::SMALLINT decimals,

        DECODE(CASE WHEN coltype IN (10, 266) THEN (MOD(collength, 256) / 16)::INTEGER
                   ELSE NULL
               END
            , 0, 'YEAR'          , 2, 'MONTH'         , 4, 'DAY'
            , 6, 'HOUR'          , 8, 'MINUTE'        , 10, 'SECOND'
            , 11, 'FRACTION(1)'  , 12, 'FRACTION(2)'  , 13, 'FRACTION(3)'
            , 14, 'FRACTION(4)'  , 15, 'FRACTION(5)'
            , NULL) upperq,

        DECODE(CASE WHEN coltype IN (10, 266) THEN MOD(MOD(collength, 256), 16)
                    ELSE NULL
               END
            , 0, 'YEAR'          , 2, 'MONTH'         , 4, 'DAY'
            , 6, 'HOUR'          , 8, 'MINUTE'        , 10, 'SECOND'
            , 11, 'FRACTION(1)'  , 12, 'FRACTION(2)'  , 13, 'FRACTION(3)'
            , 14, 'FRACTION(4)'  , 15, 'FRACTION(5)'
            , NULL) lowerq,

        CASE WHEN coltype >= 256 THEN 'NOT NULL' ELSE NULL END:: VARCHAR(8) notnull,

        (SELECT default FROM sysdefaults WHERE tabid = syscolumns.tabid AND colno = syscolumns.colno) defaultvalue

        INTO p_colName, p_colType, p_colLength, p_colDigits, p_colDecimals, p_colUpperQ, p_colLowerQ, p_colNotNull, p_colDefault
        FROM syscolumns
        WHERE tabid = p_tabId


        LET p_executeStatement = p_executeStatement || ' ' || p_colName || ' ' || p_colType;
        IF p_colLength IS NOT NULL THEN
            LET p_executeStatement = p_executeStatement || ' (' || p_colLength || ')';
        END IF
        IF p_colDigits IS NOT NULL AND p_colDecimals IS NOT NULL THEN
            LET p_executeStatement = p_executeStatement || ' (' || p_colDigits || ', ' || p_colDecimals || ')';
        END IF
        IF p_colUpperQ IS NOT NULL AND p_colLowerQ IS NOT NULL THEN
            LET p_executeStatement = p_executeStatement || ' ' || p_colUpperQ || ' TO ' || p_colLowerQ;
        END IF
        IF p_colNotNull IS NOT NULL THEN
            LET p_executeStatement = p_executeStatement || ' ' || p_colNotNull;
        END IF
        IF p_colDefault IS NOT NULL AND p_colType MATCHES '*CHAR' THEN
            LET p_executeStatement = p_executeStatement || " DEFAULT '" || TRIM(p_colDefault) || "'";
        END IF

        LET p_executeStatement = p_executeStatement || ',';
    END FOREACH

    -- remove the last comma
    LET p_executeStatement = SUBSTR(p_executeStatement, 1, LENGTH(p_executeStatement)-1);
    LET p_executeStatement = p_executeStatement || ')';

    IF p_dbspace IS NOT NULL THEN
       LET p_executeStatement = p_executeStatement || ' IN ' || p_dbspace;
    END IF

    -- set locklevel, extent sizes
    SELECT ' EXTENT SIZE ' || fextsize
         , ' NEXT SIZE ' || nextsize
         , DECODE(locklevel, 'R', ' LOCK MODE ROW', 'P', ' LOCK MODE PAGE', 'T', ' LOCK MODE TABLE', '')
    INTO p_extentSize, p_nextSize, p_lockLevel
    FROM systables WHERE tabid = p_tabId;

    LET p_executeStatement = p_executeStatement || ' ' || p_extentSize || p_nextSize || p_lockLevel;

    IF p_doExecute THEN
        EXECUTE IMMEDIATE p_executeStatement;
        RETURN 'Table created' WITH RESUME;
    ELSE
        RETURN p_executeStatement WITH RESUME;
    END IF

    CREATE TEMP TABLE IF NOT EXISTS tableCopyTempColumns (colname VARCHAR(32));

    -- define primary key
    LET p_idxName = (SELECT idxname FROM sysconstraints WHERE tabid = p_tabId AND constrtype = 'P');
    IF (p_idxName IS NOT NULL) THEN
        LET p_colList = getIdxColumnsForTableCopy(p_idxName, p_tabId);
        LET p_executeStatement = 'ALTER TABLE ' || p_newTabName || ' ADD CONSTRAINT PRIMARY KEY (' || p_colList || ') CONSTRAINT pk_' || p_newTabName;
        IF p_doExecute THEN
            EXECUTE IMMEDIATE p_executeStatement;
            RETURN 'Primary key added' WITH RESUME;
        ELSE
            RETURN p_executeStatement WITH RESUME;
        END IF
    END IF

    -- define foreign keys
    FOREACH
        SELECT fk.idxname, pk.idxname, systables.tabname, systables.tabid
        INTO p_fkIdxName, p_fkRefPkIdxName, p_fkRefTabName, p_fkRefTabId
        FROM sysconstraints fk, sysreferences, systables, sysconstraints pk
        WHERE fk.constrid = sysreferences.constrid
        AND sysreferences.ptabid = systables.tabid
        AND pk.constrid = sysreferences.primary
        AND fk.tabid = p_tabId

        LET p_colList = getIdxColumnsForTableCopy(p_fkIdxName, p_tabId);
        LET p_refColList = getIdxColumnsForTableCopy(p_fkRefPkIdxName, p_fkRefTabId);

        LET p_executeStatement = 'ALTER TABLE ' || p_newTabName || ' ADD CONSTRAINT FOREIGN KEY ('
            || p_colList || ') REFERENCES ' || p_fkRefTabName || '(' || p_refColList
            || ') CONSTRAINT fk_' || p_newTabName || '_' || p_fkRefTabName;

        IF p_doExecute THEN
            EXECUTE IMMEDIATE p_executeStatement;
            RETURN 'Foreign key added' WITH RESUME;
        ELSE
            RETURN p_executeStatement WITH RESUME;
        END IF
    END FOREACH

    -- now fill the table up
    LET p_executeStatement = 'INSERT INTO ' || p_newTabName || ' SELECT * FROM ' || p_tabName;
    IF p_doExecute THEN
        EXECUTE IMMEDIATE p_executeStatement;
        RETURN 'Table populated' WITH RESUME;
    ELSE
        RETURN p_executeStatement WITH RESUME;
    END IF

    -- add checks
    FOREACH
        SELECT constrname, constrid
        INTO p_constrName, p_constrId
        FROM sysconstraints WHERE tabid = p_tabId AND constrtype = 'C'

        LET p_executeStatement = 'ALTER TABLE ' || p_newTabName || ' ADD CONSTRAINT CHECK ';

        FOREACH
            SELECT checktext INTO p_checkText
            FROM syschecks
            WHERE constrid = p_constrId
            AND type = 'T'
            ORDER BY seqno

            LET p_executeStatement = p_executeStatement || TRIM(p_checkText);
        END FOREACH

        LET p_executeStatement = p_executeStatement || ' CONSTRAINT ' || TRIM(p_constrName) || '_' || p_newTabName;

        IF p_doExecute THEN
            EXECUTE IMMEDIATE p_executeStatement;
            RETURN 'Check constraint added' WITH RESUME;
        ELSE
            RETURN p_executeStatement WITH RESUME;
        END IF
    END FOREACH

    -- add unique constraints 
    FOREACH
        SELECT constrname, idxname
        INTO p_constrName, p_idxName
        FROM sysconstraints WHERE tabid = p_tabId AND constrtype = 'U'

        LET p_colList = getIdxColumnsForTableCopy(p_idxName, p_tabId);

        LET p_executeStatement = 'ALTER TABLE ' || p_newTabName || ' ADD CONSTRAINT UNIQUE (' || p_colList || ') CONSTRAINT ' || TRIM(p_constrName) || '_' || p_newTabName;
        IF p_doExecute THEN
            EXECUTE IMMEDIATE p_executeStatement;
            RETURN 'Unique constraint added' WITH RESUME;
        ELSE
            RETURN p_executeStatement WITH RESUME;
        END IF
    END FOREACH

    -- add other indexes
    FOREACH
        SELECT idxname, DECODE(idxtype, 'U', 'UNIQUE', '') INTO p_idxName, p_idxType
          FROM sysindexes WHERE tabid = p_tabId
           AND NOT EXISTS (SELECT 1 FROM sysconstraints WHERE tabid = p_tabId AND idxname = sysindexes.idxname)

        LET p_colList = getIdxColumnsForTableCopy(p_idxName, p_tabId);
        LET p_executeStatement = 'CREATE ' || p_idxType || ' INDEX ' || p_idxName || '_' || p_newTabName || ' ON ' || p_newTabName || ' (' || p_colList || ') ONLINE';
        IF p_doExecute THEN
            EXECUTE IMMEDIATE p_executeStatement;
            RETURN 'Index created' WITH RESUME;
        ELSE
            RETURN p_executeStatement WITH RESUME;
        END IF
    END FOREACH

    IF p_doExecute THEN
        RETURN '...done' WITH RESUME;
    END IF

    DROP TABLE IF EXISTS tableCopyTempColumns;
END FUNCTION;
