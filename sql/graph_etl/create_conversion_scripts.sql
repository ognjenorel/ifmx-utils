create procedure create_conversion_scripts(working_dir char(200));

  define statement varchar(255);
  
  let statement = 'unload to "' || TRIM(working_dir) || '\unloads.sql" delimiter "" select * from all_sql';
  execute immediate statement;
  
  foreach 
    select distinct order into i from all_cypher
    
    let statement = 'unload to "' || TRIM(working_dir) || '\load' || i || 
       '.cql" delimiter "" SELECT statement FROM all_cypher WHERE order = ' || i;
    execute immediate statement;
  end foreach
  
end procedure;
