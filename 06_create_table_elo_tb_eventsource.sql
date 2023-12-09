IF OBJECT_ID('elo.tb_EventSource') IS NULL
BEGIN
	CREATE TABLE elo.tb_EventSource
	(
		ModelID							INT				NOT NULL,
		RatingID						SMALLINT		NOT NULL,
		EventID							BIGINT			NOT NULL,
		SourceID						SMALLINT		NOT NULL,
		TeamNameA						NVARCHAR(200)	NOT NULL,
		TeamNameB						NVARCHAR(200)	NOT NULL,
		D								TINYINT			NOT NULL,
		CONSTRAINT						pk_EventSource	PRIMARY KEY
		(
			ModelID,
			RatingID,
			EventID,
			SourceID,
			TeamNameA
		),
		CONSTRAINT						fk_EventSource_Source 
		FOREIGN KEY
		(
			ModelID,
			SourceID
		)
		REFERENCES						elo.tb_Source
		(
			ModelID,
			SourceID
		)
	)
END;
GO
