IF OBJECT_ID('elo.tb_TeamRating') IS NULL
BEGIN
	CREATE TABLE elo.tb_TeamRating
	(
		ModelID							INT					NOT NULL,
		TeamID							BIGINT				NOT NULL,
		RatingID						SMALLINT			NOT NULL,
		Elo								NUMERIC(19, 9)		NOT NULL		DEFAULT(800),
		CONSTRAINT						pk_TeamRating		PRIMARY KEY
		(
			ModelID,
			TeamID,
			RatingID
		),
		CONSTRAINT						fk_TeamRating_Team	FOREIGN KEY
		(
			ModelID,
			TeamID
		)
		REFERENCES						elo.tb_Team
		(
			ModelID,
			TeamID
		),
		CONSTRAINT						fk_TeamRating_Rating	
		FOREIGN KEY
		(
			ModelID,
			RatingID
		)
		REFERENCES						elo.tb_Rating
		(
			ModelID,
			RatingID
		)
	);
END
GO
