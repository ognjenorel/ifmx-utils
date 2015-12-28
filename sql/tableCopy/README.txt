IFMX Table copy

Contents:

1. Starting up
2. Compatibility
------


1. Starting up

There are two SPL functions provided in this directory, each in separate file: getIdxColumnsForTableCopy and tableCopy. First one is just a utility function used by the tableCopy. Take both and create them in the database where there are tables you wish to copy (you'll need at least resource permission). Execute the tableCopy function with the following arguments to see what will actually be executed on the server:

  execute function tablecopy('source_table_name', 'target_table_name', null, 'f');

Execute the following to perform actual structure creation and data copy:

  execute function tablecopy('source_table_name', 'target_table_name', 'desired_db_space', 't');



2. Compatibility

The utility uses SQL syntax available in the Informix servers 11.70 and newer. 

The 11.70 SQL elements are: CREATE TEMP TABLE IF NOT EXISTS and DROP TABLE IF EXISTS. Replace these with simpler syntax and ON EXCEPTION blocks to achieve 11.50 compatibility.

The 11.50 SQL elements are: EXECUTE IMMEDIATE statements. Remove these to get older version compatibility.

The 12.10 version supports SELECT * FROM source_table INTO target_table syntax. If executing solely on 12.10, you can change the first part of the tableCopy which creates table and populates it with this sole statement.

