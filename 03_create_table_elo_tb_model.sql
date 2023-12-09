USE elotopia;
GO
IF OBJECT_ID('elo.tb_Model') IS NULL
BEGIN
	CREATE TABLE elo.tb_Model
	(
		ModelID							INT				NOT NULL,
		ModelName						NVARCHAR(50)	NOT NULL,
		ModelDescription				NVARCHAR(1000)	NULL,
		CONSTRAINT						pk_Model		PRIMARY KEY
		(
			ModelID
		)
	);
END
GO
