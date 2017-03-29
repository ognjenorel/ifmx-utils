# IFMX Graph ETL

The main goal of the Graph ETL (extract/trasnform/load) is to enable graph mining and analytics on relational data. 

The code in this directory is used to generate a series of SQL statements which will perform extract/transform part of the process and a series of Cypher statements which will perform the transform/load part of the process.

The ETL is performed without data loss and is data semantic-unaware, i.e. will work on every database. Using the Cypher graph language, graph can be loaded in a graph database which is cypher-enabled (such as [Neo4j](https://neo4j.com)).

Read more on the logic behind this in the article: [Property Oriented Relational-To-Graph Database Conversion](http://www.tandfonline.com/doi/pdf/10.7305/automatika.2017.02.1581).

More on Cypher graph language: https://www.opencypher.org.

## Quick usage

Create all the procedures and a view in your database. Determine where you'd like the files to be unloaded (note that running the procedures will not actually unload the data, rather prepare all the unload and load statements, using the working directory you provided as a parameter). Execute only these procedures:

    execute procedure create_conversion_statements('~\my_working_dir'); 
    execute procedure create_conversion_scripts('~\my_working_dir'); 

This will result in several files being created in ~\my_working_dir directory: unloads.sql which can be run at any time to unload the data, and a series of loadXX.cql files (where XX is ordered number) which can be run to load the data in the graph database.

## Supported Informix versions

The utility uses SQL syntax available in the Informix servers 11.70 and newer. 

