IF OBJECT_ID('elo.tb_Rating') IS NULL
BEGIN
	CREATE TABLE elo.tb_Rating
	(
		ModelID							INT				NOT NULL,
		RatingID						SMALLINT		NOT NULL,
		RatingName						NVARCHAR(150)	NOT NULL,
		IgnoreTies						BIT				NOT NULL		DEFAULT(0),
		RoundRobin						BIT				NOT NULL		DEFAULT(0),
		Smooth							BIT				NOT NULL		DEFAULT(1),
		Handicap						BIT				NOT NULL		DEFAULT(0),
		K								NUMERIC(19, 9)	NOT NULL		DEFAULT(16),
		CONSTRAINT						pk_Rating		PRIMARY KEY
		(
			ModelID,
			RatingID
		),
		CONSTRAINT						fk_Rating_Model	FOREIGN KEY
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
