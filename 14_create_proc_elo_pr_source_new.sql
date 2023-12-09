USE elotopia;
GO
CREATE PROCEDURE elo.pr_Source_New
(
	@ModelID					INT,
	@SourceID					SMALLINT,
	@SourceName					NVARCHAR(50),
	@SourceLocation				NVARCHAR(1000),
	@SourceType					NVARCHAR(20)
)
AS
IF (SELECT ISNULL(SUM(ModelID + SourceID), 0) FROM elo.tb_Source WHERE ModelID = @ModelID AND SourceID = @SourceID) > 0
BEGIN
	RAISERROR('ModelID-SourceID combination already in use...sorry.', 16, 1);
	RETURN;
END
IF (SELECT ISNULL(COUNT(1), 0) FROM elo.tb_Source WHERE ModelID = @ModelID AND SourceName = @SourceName) > 0  
BEGIN
	RAISERROR('SourceName already in use...sorry.', 16, 1);
	RETURN;
END
INSERT INTO elo.tb_Source 
(
	ModelID,
	SourceID,  
	SourceName, 
	SourceLocation, 
	SourceType
)
SELECT
	@ModelID,
	@SourceID,  
	@SourceName,  
	@SourceLocation,
	@SourceType;
GO
