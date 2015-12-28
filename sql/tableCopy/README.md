# IFMX Table copy

Use this utility to create copies of tables in the database, with automatic creation of the same primary and foreign keys, indexes and all other constraints that exist on the original table.

It contains two functions which should be created in the database with the table(s) to be copied. When the tableCopy function is execute it will:

* create a taget table with the new name and the same columns (names, types, not null constraints, default values for *char types) as the source
* copy the data from the source to target table
* create a primary key for the target table, on the same columns as the source, named pk_(target_table)
* create the foreign keys for the table, on the same columns, referencing the same primary tables as the source, named fk_(target_table)_(referencing_table)
* create the same check constraints, named (original_check_name)_(target_table)
* create the same unique constraints, named (original_unique_name)_(target_table)
* create the indexes on the same columns, named (original_index_name)_(target_table) 

## Quick usage

Execute the tableCopy function with the following arguments to see what will actually be executed on the server:

    execute function tablecopy('source_table_name', 'target_table_name', null, 'f'); 

Execute the following to perform actual structure creation and data copy:

    execute function tablecopy('source_table_name', 'target_table_name', 'desired_db_space', 't'); 

If no dbspace is given (i.e. the third argument is null), then the new table is created in the default database dbspace.

## Supported Informix versions

The utility uses SQL syntax available in the Informix servers 11.70 and newer. 

The 11.70 SQL elements are: CREATE TEMP TABLE IF NOT EXISTS and DROP TABLE IF EXISTS. Replace these with simpler syntax and ON EXCEPTION blocks to achieve 11.50 compatibility.

The 11.50 SQL elements are: EXECUTE IMMEDIATE statements. Remove these to get older version compatibility.

The 12.10 version supports SELECT * FROM source_table INTO target_table syntax. If executing solely on 12.10, you can change the first part of the tableCopy which creates table and populates it with this sole statement.

