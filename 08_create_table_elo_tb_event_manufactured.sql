IF OBJECT_ID('elo.tb_EventManufactured') IS NULL
BEGIN
	CREATE TABLE elo.tb_EventManufactured
	(
		ModelID							INT				NOT NULL,
		RatingID						SMALLINT		NOT NULL,
		EventID							BIGINT			NOT NULL,
		A								BIT				NOT NULL,
		TeamID							BIGINT			NOT NULL,
		D								TINYINT			NOT NULL,
		CONSTRAINT						pk_EventManufactured
		PRIMARY KEY
		(
			ModelID,
			RatingID,
			EventID,
			A 
		),
		CONSTRAINT						fk_Event_Rating	FOREIGN KEY
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
