IF OBJECT_ID('elo.tb_Source') IS NULL
BEGIN
	CREATE TABLE elo.tb_Source
	(
		ModelID							INT				NOT NULL,
		SourceID						SMALLINT		NOT NULL,
		SourceName						NVARCHAR(50)	NOT NULL,
		SourceLocation					NVARCHAR(1000)	NULL,
		SourceType						VARCHAR(20)		NOT NULL,
		CONSTRAINT						pk_Source		PRIMARY KEY
		(
			ModelID,
			SourceID
		),
		CONSTRAINT						fk_Source_Model	FOREIGN KEY
		(
			ModelID
		)
		REFERENCES						elo.tb_Model
		(
			ModelID
		)
	);
END
GO
