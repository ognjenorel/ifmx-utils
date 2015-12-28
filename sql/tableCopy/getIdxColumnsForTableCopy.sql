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


-- helper function to extract columns participating in indexes and constraints
CREATE FUNCTION getIdxColumnsForTableCopy(p_idxName LIKE sysindexes.idxname, p_tabId LIKE systables.tabid)
    RETURNING LVARCHAR(1024);

    DEFINE p_list LVARCHAR(1024);
    DEFINE p_query VARCHAR(255);
    DEFINE p_colName LIKE syscolumns.colname;
    DEFINE i SMALLINT;

    DELETE FROM tableCopyTempColumns;
    LET p_list = '';

    FOR i = 1 TO 16
        LET p_query = 'INSERT INTO tableCopyTempColumns ' ||
                    ' SELECT colname FROM sysindexes, syscolumns ' ||
                    ' WHERE idxname = "' || p_idxName || '"' ||
                    ' AND colno = part' || i || ' AND part' || i || ' <> 0 ' ||
                    ' AND syscolumns.tabid = ' || p_tabId;

        EXECUTE IMMEDIATE p_query;
    END FOR

    IF (SELECT COUNT(*) FROM tableCopyTempColumns) > 0 THEN
        FOREACH
            SELECT colname INTO p_colName FROM tableCopyTempColumns
            LET p_list = p_list || TRIM(p_colName) || ',';
        END FOREACH
        -- remove the last comma
        LET p_list = SUBSTR(p_list, 1, LENGTH(p_list)-1);
        RETURN p_list;
    END IF

    RETURN NULL;
END FUNCTION;
