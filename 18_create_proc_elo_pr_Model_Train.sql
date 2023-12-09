CREATE PROCEDURE elo.pr_Model_Train
/*
	TODO: Make this run an entire process from creation to finish if possible
*/
(
	@ModelID						AS INTEGER
)
AS
DECLARE	@RatingID		SMALLINT,
		@EventID		BIGINT,
		@TeamAID		BIGINT,
		@TeamBID		BIGINT, 
		@BOPEloA		NUMERIC(19, 9),
		@BOPEloB		NUMERIC(19, 9),
		@EloA			NUMERIC(19, 9),
		@EloB			NUMERIC(19, 9),
		@K				NUMERIC(19, 9),
		@Smooth			BIT,
		@Handicap		BIT,
		@D				BIT;

DELETE FROM elo.tb_TeamRatingEvent WHERE ModelID = @ModelID;
EXEC elo.pr_TeamRating_Initialize @ModelID;
UPDATE STATISTICS elo.tb_TeamRatingEvent;
CREATE TABLE #Events
(
	RatingID			SMALLINT,
	EventID				BIGINT,
	TeamAID				BIGINT,
	TeamBID				BIGINT,
	D					TINYINT,
	CONSTRAINT pk_HASH_Events
	PRIMARY KEY
	(
		RatingID,
		EventID,
		TeamAID 
	)
);
INSERT INTO #Events
(
	RatingID,
	EventID,
	TeamAID,
	TeamBID,
	D 
)
SELECT
	a.RatingID,
	a.EventID,
	a.TeamID,
	b.TeamID,
	a.D
FROM 
	(SELECT * FROM elo.tb_EventManufactured WHERE ModelID = @ModelID AND A = 1) AS a
	INNER JOIN (SELECT * FROM elo.tb_EventManufactured WHERE ModelID = @ModelID AND A = 0) AS b
	ON	a.RatingID				= b.RatingID			AND
		a.EventID				= b.EventID 
WHERE 
	a.ModelID = @ModelID;
WHILE (SELECT COUNT(1) FROM #Events) > 0
BEGIN
	SELECT TOP 1
		@RatingID		= RatingID,
		@EventID		= EventID,
		@TeamAID		= TeamAID,
		@TeamBID		= TeamBID, 
		@D				= D 
	FROM
		#Events;
	SELECT 
		@Smooth			= r.Smooth,
		@Handicap		= r.Handicap, 
		@K				= r.K,
		@BOPEloA		= tra.Elo,
		@BOPEloB		= trb.Elo 
	FROM
		elo.tb_Rating r
		INNER JOIN elo.tb_TeamRating tra 
		ON	tra.ModelID = @ModelID					AND
			tra.TeamID	= @TeamAID
		INNER JOIN elo.tb_TeamRating trb  
		ON	trb.ModelID = @ModelID					AND
			trb.TeamID	= @TeamBID
	WHERE
		r.RatingID = @RatingID;
	SELECT 
		@EloA		= RatingA,
		@EloB		= RatingB 
	FROM elo.fn_Elo(@BOPEloA, @BOPEloB, @K, @D, @Smooth, @Handicap);
	UPDATE 
	elo.tb_TeamRating 
	SET Elo = @EloA
	WHERE ModelID = @ModelID AND TeamID = @TeamAID AND RatingID = @RatingID;
	UPDATE 
	elo.tb_TeamRating 
	SET Elo = @EloB
	WHERE ModelID = @ModelID AND TeamID = @TeamBID AND RatingID = @RatingID;
	INSERT INTO elo.tb_TeamRatingEvent
	(
		ModelID,
		TeamID,
		RatingID,
		EventID,
		BOPElo,
		Elo 
	)
	SELECT 
		@ModelID,
		@TeamAID,
		@RatingID,
		@EventID, 
		@BOPEloA,
		@EloA 
	UNION ALL 
	SELECT 
		@ModelID,
		@TeamBID,
		@RatingID,
		@EventID, 
		@BOPEloB,
		@EloB; 
	DELETE FROM #Events WHERE RatingID = @RatingID AND EventID = @EventID AND TeamAID = @TeamAID;
	if @D = 2 begin
	print('Tie!!!!!!!!') end;
	UPDATE STATISTICS #Events; 
END

GO
