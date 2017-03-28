-- recursive procedure for examining references of a table
-- input: table which is examined for being a part of cyclic reference; foreign key currently observed
drop procedure find_cycle_ref_for_table;
create procedure find_cycle_ref_for_table(ref_tabid like systables.tabid, current_constrid like sysconstraints.constrid)  ;

  define current_ptabid like sysreferences.ptabid;
  define next_constrid like sysconstraints.constrid;
  
  let current_ptabid = (select ptabid from all_fks where constrid = current_constrid);
  
  if (ref_tabid = current_ptabid) then
    -- last key in cyclic reference is found
    insert into cyclic_fks values (current_constrid);
    return;
  end if
  -- last key not found, but check for spining in circle
  if (current_constrid in (select constrid from cycle_fks_visited_tmp)) then
    return;
  else 
    insert into cycle_fks_visited_tmp values (current_constrid);  
  end if
  -- otherwise go deeper find keys for this referencing table
  foreach
     select constrid 
       into next_constrid
       from all_fks
      where tabid = current_ptabid
      
     execute procedure find_cycle_ref_for_table(ref_tabid, next_constrid);    
  end foreach

end procedure;
