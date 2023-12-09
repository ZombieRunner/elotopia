USE elotopia;
GO
CREATE PROCEDURE elo.pr_Rating_New
(
	@ModelID					INT,
	@RatingID					SMALLINT,
	@RatingName					NVARCHAR(150),
	@IgnoreTies					BIT,
	@RoundRobin					BIT,
	@Smooth						BIT,
	@Handicap					BIT,
	@K							NUMERIC(19, 9)
)
AS
IF (SELECT ISNULL(SUM(ModelID + RatingID), 0) FROM elo.tb_Rating WHERE ModelID = @ModelID AND RatingID = @RatingID) > 0
BEGIN
	RAISERROR('ModelID-RatingID combination already in use...sorry.', 16, 1);
	RETURN;
END
IF (SELECT ISNULL(COUNT(1), 0) FROM elo.tb_Rating WHERE ModelID = @ModelID AND RatingName = @RatingName) > 0 
BEGIN
	RAISERROR('RatingName already in use...sorry.', 16, 1);
	RETURN;
END
INSERT INTO elo.tb_Rating 
(
	ModelID,
	RatingID, 
	RatingName,
	IgnoreTies,
	RoundRobin,
	Smooth,
	Handicap,
	K 
)
SELECT
	@ModelID,
	@RatingID, 
	@RatingName, 
	@IgnoreTies,
	@RoundRobin,
	@Smooth,
	@Handicap,
	@K
GO
