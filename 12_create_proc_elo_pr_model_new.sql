CREATE PROCEDURE elo.pr_Model_New
(
	@ModelID					INT,
	@ModelName					NVARCHAR(50),
	@ModelDescription			NVARCHAR(1000)	NULL
)
AS
IF (SELECT ISNULL(SUM(ModelID), 0) FROM elo.tb_Model WHERE ModelID = @ModelID) > 0
BEGIN
	RAISERROR('ModelID already in use...sorry.', 16, 1);
	RETURN;
END
IF (SELECT ISNULL(COUNT(1), 0) FROM elo.tb_Model WHERE ModelName = @ModelName) > 0 
BEGIN
	RAISERROR('ModelName already in use...sorry.', 16, 1);
	RETURN;
END
INSERT INTO elo.tb_Model
(
	ModelID,
	ModelName,
	ModelDescription 
)
SELECT
	@ModelID,
	@ModelName,
	@ModelDescription;
GO
