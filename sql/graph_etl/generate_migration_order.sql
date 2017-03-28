-- determine the order for load
create procedure generate_migration_order();
 
  create temp table if not exists nodes(tabid int, tabname char(70), order int) with no log;
  delete from nodes;
  
  -- tables which do not reference any other table are loaded first
  insert into nodes
  select tabid, tabname, 1 
    from systables t
   where tabtype = 'T'
     and tabid > 99
     and not exists (select 1 from sysconstraints where tabid = t.tabid and constrtype = 'R');

  create temp table if not exists generate_migration_order_temp (tabid int, tabname char(70)) with no log;
  delete from generate_migration_order_temp;


  -- now other tables are found which reference only the ones already loaded, and are not going to become edges. 
  -- this is repeated until anything is found, and tables are places in nodes table with correct order
  loop
    insert into generate_migration_order_temp 
    select tabid, tabname from systables t
     where tabtype = 'T'
       and tabid > 99
       and tabid not in (select tabid from nodes)
       and tabid not in (select tabid from edges)
       and not exists (select 1 from sysreferences r, sysconstraints c 
                        where r.constrid = c.constrid 
                          and c.tabid = t.tabid 
                          and r.ptabid not in (select tabid from nodes)
                          and r.constrid not in (select constrid from cyclic_fks));
   if (select count(*) from generate_migration_order_temp) = 0 then
     exit loop;
   end if  

   insert into nodes
   select *, (select max(order)+1 from nodes)
     from generate_migration_order_temp;

   delete from generate_migration_order_temp;
 end loop  
 drop table if exists generate_migration_order_temp;
end procedure;
