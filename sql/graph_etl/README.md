The main goal of the Graph ETL (extract/trasnform/load) is to enable graph mining and analytics on relational data. 

The code in this directory is used to generate a series of SQL statements which will perform extract/transform part of the process and a series of Cypher statements which will perform the transform/load part of the process.

The ETL is performed without data loss and is data semantic-unaware, i.e. will work on every database. Using the Cypher graph language, graph can be loaded in a graph database which is cypher-enabled (such as [Neo4j](https://neo4j.com).

Read more on the logic behind this in the article: [Property Oriented Relational-To-Graph Database Conversion](http://www.tandfonline.com/doi/pdf/10.7305/automatika.2017.02.1581).

More on Cypher graph language: https://www.opencypher.org.

