IF OBJECT_ID('elo.tb_TeamRatingEvent') IS NULL
BEGIN
	CREATE TABLE elo.tb_TeamRatingEvent
	(
		ModelID							INT					NOT NULL,
		TeamID							BIGINT				NOT NULL,
		RatingID						SMALLINT			NOT NULL,
		EventID							BIGINT				NOT NULL,
		BOPElo							NUMERIC(19, 9)		NOT NULL		DEFAULT(800),
		Elo								NUMERIC(19, 9)		NOT NULL		DEFAULT(800),
		CONSTRAINT						pk_TeamRatingEvent	PRIMARY KEY
		(
			ModelID,
			TeamID,
			RatingID,
			EventID
		),
		CONSTRAINT						fk_TeamRatingEvent_TeamRating		FOREIGN KEY
		(
			ModelID,
			TeamID,
			RatingID
		)
		REFERENCES						elo.tb_TeamRating
		(
			ModelID,
			TeamID,
			RatingID
		)
	);
END
GO
