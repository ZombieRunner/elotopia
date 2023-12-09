# elotopia
An implementation of the ELO algorithm in SQL Server.
The provided code creates all the objects you require to support the algorithm and it uses EPL football results in the demo.
This willproduce a probability matrix of how likely TeamA will win at home or Draw or Team B will win away.
## Getting Started

Download [all_in_one](/all_in_one.sql).
This script creates all the objects and jobs that you need.

You can also download the objects as separate scripts:
 - [DatabaseBackup](/DatabaseBackup.sql): SQL Server Backup
 - [DatabaseIntegrityCheck](/DatabaseIntegrityCheck.sql): SQL Server Integrity Check
 - [IndexOptimize](/IndexOptimize.sql): SQL Server Index and Statistics Maintenance
 - [CommandExecute](/CommandExecute.sql): Stored procedure to execute and log commands
 - [CommandLog](/CommandLog.sql): Table to log commands

Note that you will need to have permissions to create databases, schemas, tables, functions and stored procedures to install this.

Supported versions: SQL Server 2008, SQL Server 2008 R2, SQL Server 2012, SQL Server 2014, SQL Server 2016, SQL Server 2017, SQL Server 2019

## Documentation

