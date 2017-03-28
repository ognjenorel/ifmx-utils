-- prepares a list of strings which can be used in a select statement for a table, taking into account pk, each fk and other attributes
drop procedure get_columns_for_id;
create procedure get_columns_for_id(p_tabname like systables.tabname) ;

  DEFINE p_list LVARCHAR(1000);
  DEFINE p_query VARCHAR(255);
  DEFINE p_colName LIKE syscolumns.colname;
  DEFINE p_coltype CHAR(20);
  DEFINE i INTEGER;
  DEFINE p_tabid LIKE systables.tabid;
  DEFINE p_idxname LIKE sysindexes.idxname;
  DEFINE p_constrtype LIKE sysconstraints.constrtype;
  DEFINE p_constrname LIKE sysconstraints.constrname;
  DEFINE p_constrid LIKE sysconstraints.constrid;
  DEFINE p_reftable LIKE systables.tabname;
  
  LET p_tabid = (SELECT tabid FROM systables WHERE tabtype = 'T' and tabname = p_tabname);

  create temp table if not exists all_key_columns_temp(colno SMALLINT) with no log;
  DELETE FROM all_key_columns_temp;
  
  create temp table if not exists get_columns_for_id_temp(colname CHAR(70), coltype CHAR(70), colno SMALLINT) with no log;
  
  FOREACH
    SELECT idxname, constrtype, constrid, constrname
      INTO p_idxname, p_constrtype, p_constrid, p_constrname
      FROM sysconstraints 
     WHERE tabid = p_tabid 
       AND constrtype IN ('P', 'R')

     DELETE FROM get_columns_for_id_temp;
  
     LET p_list = '';

     FOR i = 1 TO 16
        LET p_query = 'INSERT INTO get_columns_for_id_temp ' ||
                      ' SELECT colname, type, colno FROM sysindexes i, hsyscolumns v' ||
                      ' WHERE idxname = "' || p_idxName || '"' ||
                      ' AND colno = part' || i || ' AND part' || i || ' <> 0 ' ||
                      ' AND tabname = "' || trim(p_tabname) || '"';

       EXECUTE IMMEDIATE p_query;
    END FOR

    IF (SELECT COUNT(*) FROM get_columns_for_id_temp) > 0 THEN
      INSERT INTO all_key_columns_temp SELECT colno FROM get_columns_for_id_temp;
      FOREACH
        SELECT colname, coltype INTO p_colName, p_coltype FROM get_columns_for_id_temp

          IF p_coltype MATCHES "*CHAR*" THEN
             LET p_list = p_list || ' TRIM(' || TRIM(p_colname) || ') || "_" || ';
          ELSE 
             LET p_list = p_list || TRIM(p_colName) || ' || "_" || ';
          END IF
      END FOREACH
      LET p_list = SUBSTR(p_list, 1, LENGTH(p_list)-10); -- da maknemo zadnji dio koji je visak
      -- ako se radi o fk, vratit cu i ime referencirane tablice
      IF (p_constrtype = 'R') THEN
          LET p_reftable = (SELECT tabname 
                            FROM systables t, sysreferences r
                           WHERE t.tabid = r.ptabid
                             AND r.constrid = p_constrid);
      ELSE 
          LET p_reftable = NULL;
      END IF
      INSERT INTO columns_for_table_temp VALUES(p_list, p_list, p_constrtype, p_reftable, p_constrname);
    END IF

  END FOREACH  

  FOREACH
    SELECT colname, type
      INTO p_colname, p_coltype
      FROM hsyscolumns
     WHERE tabname = p_tabname
       AND colno NOT IN (SELECT colno FROM all_key_columns_temp)
	   AND type NOT IN ('TEXT', 'BYTE', 'BLOB', 'CLOB', 'SET', 'MULTISET', 'LIST')
    
       IF p_coltype MATCHES "*CHAR*" THEN
          INSERT INTO columns_for_table_temp VALUES(p_colname, " '""' || TRIM(" || p_colname || ") || '""' ", NULL, NULL, NULL);
       ELSE
          INSERT INTO columns_for_table_temp VALUES(p_colname, p_colname, NULL, NULL, NULL);
       END IF
  END FOREACH

END PROCEDURE;
