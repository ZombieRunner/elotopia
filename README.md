# elotopia
An implementation of the ELO algorithm in SQL Server.
The provided code creates all the objects you require to support the algorithm and it uses EPL football results in the demo.
This willproduce a probability matrix of how likely TeamA will win at home or Draw or Team B will win away.

## Getting Started

Download [all_in_one](/all_in_one.sql).
This script creates all the objects and jobs that you need.
- or you could run 1 object at a time (they are in numeric order) and finish of by running the [takeon_script](/takeon_script.sql).
- If you would like to bring on external data, you can create models and sources with the stored procedures provided and you can insert your takeon files
  via BULK INSERT into the table elo.tb_EventSource.
  
Note that you will need to have permissions to create databases, schemas, tables, functions and stored procedures to install this.

Supported versions: SQL Server 2008, SQL Server 2008 R2, SQL Server 2012, SQL Server 2014, SQL Server 2016, SQL Server 2017, SQL Server 2019

## Documentation
[ELO Rating System](https://en.wikipedia.org/wiki/Elo_rating_system).
