-- Copyright 2018 Ognjen Orel
-- This file is part of ifmx utilities.
--
-- ifmx utilities is free software: you can redistribute it and/or modify
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
-- along with ifmx utilities. If not, see <http://www.gnu.org/licenses/>.

create function median_init (dummy int)
   returning list(int not null);
   
   return list{};
end function;

create function median_iter (result list(int not null), value int)
   returning list(int not null);
   insert into table (result) values (value::int);
   return result;
end function;

create function median_combine(partial1 list(int not null), partial2 list(int not null))
   returning list(int not null);

   insert into table (partial1) select * from table(partial2);   
   return partial1;
end function;

create function median_final(final list(int not null)) returning float;

   define cnt, middle, v1, v2 int;

   select count(*) into cnt from table(final);
   if mod (cnt, 2) = 0 then
     let middle = cnt / 2 - 1;
     foreach select skip middle first 1 * into v1 from table(final) order by 1
     end foreach
     let middle = middle + 1;
     foreach select skip middle first 1 * into v2 from table(final) order by 1
     end foreach
     return ((v1 + v2) / 2.0);
   else
     let middle = ceil(cnt / 2.0) - 1;
     foreach select skip middle first 1 * into v1 from table(final) order by 1
     return v1;
     end foreach
   end if

end function;


create aggregate median with
   (init = median_init,
    iter = median_iter,
    combine = median_combine,
    final = median_final);

--> -9401: Cannot re-define or drop builtin aggregate median.

select median(tabid) from systables;

--> -999: Not implemented yet.

create aggregate median2 with
   (init = median_init,
    iter = median_iter,
    combine = median_combine,
    final = median_final);


