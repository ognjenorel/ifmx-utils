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

create function boxplot2_final(final list(int not null)) returning blob;

   define p_value int;
   define b blob;
   define rnd int;
   define in_file char(128);
   define out_file char(128);

   let rnd = sp_random();
   let in_file = "/working_server_dir/in_" || rnd || ".txt";
   let out_file = "/working_server_dir/out_" || rnd || ".png";

   begin
     on exception end exception with resume;
     system "rm " || in_file;
   end
  
   foreach
      select * into p_value from table(final) order by 1

      system "echo " || p_value || " >> " || in_file;
   end foreach
 
   system "cd /working_server_dir; java8 -cp . BoxPlot2 " || trim(in_file) || " "|| trim(out_file);
   let b = filetoblob("/working_server_dir/out_" || rnd || ".png", 'server');
   return b;
end function;

drop aggregate boxplot2 ;
create aggregate boxplot2 with
   (init = histogram_init,
    iter = histogram_iter,
    combine = histogram_combine,
    final = boxplot2_final);
