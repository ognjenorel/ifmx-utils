-- input: working directory for all the export/import files
-- output: tables all_sql and all_cypher contain all the unload and load statements
create procedure create_conversion_statements(working_dir char(200));

   define p_tabname LIKE systables.tabname;
   define p_order INTEGER;

   -- two main temporary tables which contain all sql unload and cypher load statements
   create temp table if not exists all_sql (statement LVARCHAR(1000)) with no log;
   create temp table if not exists all_cypher (statement LVARCHAR(2000), order INTEGER) with no log;
   delete from all_sql;
   delete from all_cypher;
   
   -- first find all foreign key which form cyclic references; these are written in cyclic_fks temp table
   execute procedure find_all_cycle_ref();
   
   -- now find all the tables with 2 fks and no references to pk; those will form edges
   drop table if exists edges;
   select tabid, count(*) broj from sysconstraints c
    where constrtype = 'R'
      and not exists (select 1 from sysreferences where ptabid = tabid)
    group by 1
   having count(*) = 2
     into temp edges with no log;

   -- all other tables will become nodes; this procedure also defines their order of creation, so the forming of all the nodes and their fks can be done in one pass
   execute procedure generate_migration_order();
  
   -- now create the statements for unload and load
   -- first start with nodes, ordered, and then create all the cyclic references as well
   foreach 
     select tabname, order
	   into p_tabname, p_order
	   from nodes v
	  order by order
	  
         execute procedure generate_statements_for_table(p_tabname, working_dir, 'V', p_order);
   end foreach
  
   -- after that add the tables which will form edges
   let p_order = (select max(order) + 1 from nodes);
   foreach 
     select tabname
	   into p_tabname
	   from systables s, edges b
	  where s.tabid = b.tabid

	     execute procedure generate_statements_for_table(p_tabname, working_dir, 'E', p_order);
   end foreach
  
   --clean the temp tables
   drop table if exists edges;
   drop table if exists nodes;
   drop table if exists cyclic_fks;
   drop table if exists cycle_fks_visited_tmp;
   drop table if exists all_fks;

end procedure;
