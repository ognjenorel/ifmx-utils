-- generates unload sql statements and load cypher statements for a table
create procedure generate_statements_for_table(p_tabname like systables.tabname, working_dir char(200), p_element_type char(1), p_order INTEGER); 

  -- find PK attributes and create an id for the node/edge
  -- find FK attributes and create an id for referencing
  -- find other attribudes and create properties
  -- if creating an edge, we know there are gonna be 2 fks
  
  -- we want to get unload statement like this
  --  unload
  -- select bla1 || trim(bla2) || bla3 as id, att1, att2, att3, att4 || trim(att5) as fk1_id, att6 || att7 as fk2_id

   DEFINE p_attrib CHAR(200);
   DEFINE p_attrib_sql CHAR(200);
   DEFINE p_constrtype CHAR(1);
   DEFINE p_reftable CHAR(70);
   DEFINE p_constrname LIKE sysconstraints.constrname;
   DEFINE p_query LVARCHAR(2000);
   DEFINE p_cypher LVARCHAR(2000);
   DEFINE i INTEGER;

   -- we keep attributes of a table here, to know what to do with them
   create temp table if not exists columns_for_table_temp
      (attrib char(200), attrib_sql char(200), constrtype char(1), reftable char(70), constrname CHAR(100)) with no log;
   DELETE FROM columns_for_table_temp;
   EXECUTE PROCEDURE get_columns_for_id(p_tabname);

   -- start composing unload and load statements
   LET p_query = 'UNLOAD TO "' || TRIM(working_dir) || '/' || TRIM(p_tabname) || '.csv" DELIMITER "," SELECT';
   LET p_cypher = "USING PERIODIC COMMIT 1000 LOAD CSV FROM 'file:" || TRIM(working_dir) || "/" || TRIM(p_tabname) || ".csv' AS line";
   
   LET p_attrib, p_attrib_sql = (SELECT attrib, attrib_sql FROM columns_for_table_temp WHERE constrtype = 'P');

   LET p_query = TRIM(p_query) || ' ' || TRIM(p_attrib_sql);
   IF p_element_type = 'V' THEN
      LET p_cypher = TRIM(p_cypher) || ' CREATE (newVertex:' || TRIM(p_tabname) || ' { id: line[0] ';
   ELSE 
      LET p_cypher = '-[:' || TRIM(p_tabname) || ' { id: line[0] ';
   END IF

   LET i = 1;
   FOREACH 
      SELECT attrib, attrib_sql
        INTO p_attrib, p_attrib_sql
        FROM columns_for_table_temp 
      WHERE constrtype IS NULL

       LET p_query = TRIM(p_query) || ', ' || TRIM(p_attrib_sql);
       LET p_cypher = TRIM(p_cypher) || ', ' || TRIM(p_attrib) || ': line[' || i || ']';
       LET i = i + 1;
   END FOREACH
   IF p_element_type = 'V' THEN
      LET p_cypher = TRIM(p_cypher) || '})';
   ELSE
      LET p_cypher = TRIM(p_cypher) || '}]->';
   END IF
   
   FOREACH 
     SELECT attrib, reftable, constrname 
       INTO p_attrib, p_reftable, p_constrname
       FROM columns_for_table_temp 
      WHERE constrtype = 'R'
      
      LET p_query = TRIM(p_query) || ', ' || TRIM(p_attrib);
	  IF p_element_type = 'V' THEN
         -- if this is a cycle-closing foreign key, create another load statement which will run at the end
         IF p_constrname IN (SELECT constrname FROM sysconstraints WHERE constrid IN (SELECT constrid FROM cyclic_fks)) THEN
            INSERT INTO all_cypher VALUES (
               "USING PERIODIC COMMIT 1000 LOAD CSV FROM 'file:" || TRIM(working_dir) || "/" || TRIM(p_tabname) || ".csv' AS line " ||
               "MATCH (a:" || TRIM(p_tabname) || ") WHERE a.id = line[0] " || 
               "MATCH (b:" || TRIM(p_refTable) || ") WHERE b.id = line[" || i || "] " ||
               "CREATE (a)-[:" || TRIM(p_constrname) || ']->(b);'
            , 10000);
         ELSE
           -- connect to a referenced table like this:
           --MATCH (a:refTable) WHERE a.id=id_fk_reftable 
           -- CREATE (this)-[fk_p_tabname_refTable]->(a)
           LET p_cypher = TRIM(p_cypher) || ' WITH newVertex, line MATCH (a:' || TRIM(p_refTable) || ') WHERE a.id = line['   || i || '] CREATE (newVertex)-[:' || TRIM(p_constrname) || ']->(a)';
   	     END IF
      ELSE
         -- when creating a node, we need two nodes to connect to, like this:
	     -- MATCH (a1:refTable) WHERE a1.id = id_fk_refTable
		 -- MATCH (a2:refTable) WHERE a2.id = id_fk_refTable
         -- first we add inner node, then the outer
		 IF p_cypher NOT MATCHES 'MATCH*' THEN -- this is inner node
            LET p_cypher = 'MATCH (a' || i || ':' || TRIM(p_refTable) || ') WHERE a' || i || '.id = line[' || i || '] CREATE (a' || i || ')' || TRIM(p_cypher);
	     ELSE -- this is the outer node
            LET p_cypher = 'MATCH (a' || i || ':' || TRIM(p_refTable) || ') WHERE a' || i || '.id = line[' || i || '] ' || TRIM(p_cypher) || '(a' || i || ')';
             
            -- now we can add the front part of the statement
            LET p_cypher = "USING PERIODIC COMMIT 1000 LOAD CSV FROM 'file:" || TRIM(working_dir) || "/" || TRIM(p_tabname) || ".csv' AS line " || TRIM(p_cypher);
		 END IF
	  END IF
      LET i = i + 1;
   END FOREACH
   
   LET p_query = TRIM(p_query) || ' FROM ' || TRIM(p_tabname);
   LET p_cypher = TRIM(p_cypher); 

   INSERT INTO all_sql VALUES (p_query);
   INSERT INTO all_cypher VALUES (p_cypher, p_order);
   INSERT INTO all_cypher VALUES ('CREATE INDEX ON :' || TRIM(p_tabname) || '(id)', p_order);

end procedure;
