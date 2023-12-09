IF (NOT EXISTS (SELECT * FROM sys.databases WHERE name = N'elotopia'))
BEGIN
    CREATE DATABASE elotopia;
END;
GO
