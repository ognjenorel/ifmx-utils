-- cyclic references can be made in informix. 
-- Table A can reference table B which can reference table C which references A again. 
-- This procedure will isolate only the last foreign key which "closes" the cycle (in this example C->A), 
-- and add it to a separate list of foreign keys which will be created after all the nodes are in place. 
-- The simplest form of a cyclic reference is table referring to itself (often used to represent hierarchies).
create procedure find_all_cycle_ref();

  define ref_tabid like sysconstraints.tabid;
  define next_constrid like sysconstraints.constrid;

  -- this table is used by a recursive procedure
  drop table if exists all_fks;
  select c.constrid, c.tabid, r.ptabid from sysconstraints c, sysreferences r
   where c.constrid = r.constrid
    into temp all_fks with no log;

  -- this table contains those foreign keys which close the cycle
  create temp table if not exists cyclic_fks (constrid INT) with no log;
  delete from cyclic_fks;
  
  create temp table if not exists cycle_fks_visited_tmp (constrid INT) with no log;
  
  foreach 
    select tabid, constrid 
      into ref_tabid, next_constrid
      from all_fks
     where exists (select 1 from sysreferences r where r.ptabid = all_fks.tabid)
     
     delete from cycle_fks_visited_tmp;
     execute procedure find_cycle_ref_for_table(ref_tabid, next_constrid);
  end foreach
  
  drop table if exists all_fks;
  drop table if exists cycle_fks_visited_tmp;
  
end procedure;
