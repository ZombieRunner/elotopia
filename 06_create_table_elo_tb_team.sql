IF OBJECT_ID('elo.tb_Team') IS NULL
BEGIN
	CREATE TABLE elo.tb_Team
	(
		ModelID							INT					NOT NULL,
		TeamID							BIGINT				NOT NULL,
		TeamName						NVARCHAR(200)		NOT NULL,
		CONSTRAINT						pk_Team				PRIMARY KEY
		(
			ModelID,
			TeamID
		),
		CONSTRAINT						fk_Team_Model		FOREIGN KEY
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
