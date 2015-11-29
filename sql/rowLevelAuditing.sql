CREATE VIEW vsyscolumns (tabname, colname, colno, type) AS
SELECT systables.tabname
     , syscolumns.colname
     , syscolumns.colno
     , DECODE (CASE WHEN coltype >= 256 THEN coltype - 256 ELSE coltype END
             , 0, 'CHAR(' || collength || ')'
             , 1, 'SMALLINT'
             , 2, 'INTEGER'
             , 3, 'FLOAT'
             , 4, 'SMALLFLOAT'
             , 5, 'DECIMAL(' || (collength/256)::SMALLINT || ',' || MOD(collength, 256) || ')'
             , 6, 'INTEGER' --normaly  'SERIAL'
             , 7, 'DATE'
             , 8, 'MONEY'
             , 10, 'DATETIME ' || DECODE((MOD(collength, 256) / 16)::INTEGER, 0, 'YEAR', 2, 'MONTH', 4, 'DAY', 6, 'HOUR', 8, 'MINUTE', 10, 'SECOND' 
                                           , 11, 'FRACTION(1)', 12, 'FRACTION(2)', 13, 'FRACTION(3)', 14, 'FRACTION(4)', 15, 'FRACTION(5)', NULL)
                    || ' TO ' ||  DECODE(MOD(MOD(collength, 256), 16), 0, 'YEAR', 2, 'MONTH', 4, 'DAY', 6, 'HOUR', 8, 'MINUTE', 10, 'SECOND' 
                                           , 11, 'FRACTION(1)', 12, 'FRACTION(2)', 13, 'FRACTION(3)', 14, 'FRACTION(4)', 15, 'FRACTION(5)', NULL)
             , 11, 'BYTE'
             , 12, 'TEXT'
             , 13, 'VARCHAR(' || CASE WHEN collength < 0 THEN MOD(collength + 65536, 256) ELSE MOD(collength, 256) END || ')'
             , 14, 'INTERVAL ' || DECODE((MOD(collength, 256) / 16)::INTEGER, 0, 'YEAR', 2, 'MONTH', 4, 'DAY', 6, 'HOUR', 8, 'MINUTE', 10, 'SECOND' 
                                           , 11, 'FRACTION(1)', 12, 'FRACTION(2)', 13, 'FRACTION(3)', 14, 'FRACTION(4)', 15, 'FRACTION(5)', NULL)
                    || ' TO ' ||  DECODE(MOD(MOD(collength, 256), 16), 0, 'YEAR', 2, 'MONTH', 4, 'DAY', 6, 'HOUR', 8, 'MINUTE', 10, 'SECOND' 
                                           , 11, 'FRACTION(1)', 12, 'FRACTION(2)', 13, 'FRACTION(3)', 14, 'FRACTION(4)', 15, 'FRACTION(5)', NULL)
             , 15, 'NCHAR(' || collength || ')'
             , 16, 'NVARCHAR(' || CASE WHEN collength < 0 THEN MOD(collength + 65536, 256) ELSE MOD(collength, 256) END || ')'
             , 17, 'INT8'
             , 18, 'INT8' -- normaly 'SERIAL8'
             , 40, 'LVARCHAR(' || collength || ')'
             , NULL) ::CHAR(128)
   FROM systables, syscolumns 
   WHERE systables.tabid = syscolumns.tabid
     AND systables.tabtype = 'T';


CREATE PROCEDURE createAuditTriggers(p_tabname LIKE systables.tabname);
-- trigname: _tabname(insert|update|delete) 

   DEFINE p_tabname LIKE systables.tabname;
   DEFINE p_cmd LVARCHAR(1000);
   DEFINE tmp CHAR(100);
   DEFINE operation CHAR(6);

   FOR operation IN ('insert', 'update', 'delete')
      IF NOT EXISTS (SELECT * FROM systriggers WHERE trigname IN ("_" || TRIM(p_tabname) || operation)) THEN

         LET p_cmd = 'CREATE TRIGGER _' || TRIM(p_tabname) || operation || ' ' || UPPER(operation) || ' ON ' || RTRIM(p_tabname) 
             || ' REFERENCING ' || DECODE(operation, 'delete', 'OLD', 'NEW') || ' AS t FOR EACH ROW ( INSERT INTO _' || RTRIM(p_tabname) || ' VALUES(';

         FOREACH 
            SELECT 't.' || TRIM(colname) 
              INTO tmp 
              FROM vsyscolumns
             WHERE tabname = p_tabname 
             ORDER BY colno

            LET p_cmd = RTRIM(p_cmd) || ' ' || TRIM(tmp) || ',';
         END FOREACH;
        LET p_cmd = RTRIM(p_cmd) || '"' || operation || '", USER, CURRENT))';

        BEGIN 
           ON EXCEPTION IN (743)
           END EXCEPTION WITH RESUME;
           EXECUTE IMMEDIATE p_cmd;
        END
      END IF		
   END FOR;

END PROCEDURE;
	 
CREATE PROCEDURE createAuditTables(p_tabname LIKE systables.tabname, p_dbs CHAR(30), p_extsize INT);

   DEFINE p_cmd CHAR(1000);
   DEFINE tmp CHAR(100);

   IF NOT EXISTS (SELECT 1 FROM systables WHERE tabname MATCHES "_" || p_tabname) THEN
      LET p_cmd = 'CREATE TABLE _' || RTRIM(p_tabname) || ' (';
      FOREACH 
         SELECT TRIM(colname) || ' ' || type
           INTO tmp FROM vsyscolumns
          WHERE tabname = p_tabname 
          ORDER BY colno

         LET p_cmd = RTRIM(p_cmd) || ' ' || TRIM(tmp) || ',';
      END FOREACH;
      LET p_cmd = RTRIM(p_cmd) || ' operation CHAR(6), login CHAR(32), timestamp DATETIME YEAR TO SECOND)' || ' IN ' || TRIM(p_dbs) || ' EXTENT SIZE ' || p_extsize || ' NEXT SIZE ' || p_extsize;
      BEGIN 
         ON EXCEPTION IN (310)
         END EXCEPTION WITH RESUME;
         EXECUTE IMMEDIATE p_cmd;
      END
   END IF
   EXECUTE PROCEDURE createAuditTriggers(p_tabname);
END PROCEDURE;


