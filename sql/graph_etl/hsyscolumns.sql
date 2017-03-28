CREATE VIEW hsyscolumns (tabname, colname, colno, type) AS
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
             , 6, 'SERIAL'
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
             , 18, 'SERIAL8'
             , 40, 'LVARCHAR(' || collength || ')'
             , NULL) ::CHAR(128)
   FROM systables, syscolumns 
   WHERE systables.tabid = syscolumns.tabid
     AND systables.tabtype = 'T';
