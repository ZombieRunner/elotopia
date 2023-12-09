IF (NOT EXISTS (SELECT * FROM sys.databases WHERE name = N'elotopia'))
BEGIN
    CREATE DATABASE elotopia;
END;
USE elotopia;
GO
CREATE SCHEMA elo;
GO

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
USE elotopia;
GO
CREATE FUNCTION elo.fn_Probability
(
	@Rating1						NUMERIC(19, 9),
	@Rating2						NUMERIC(19, 9)
)
RETURNS								NUMERIC(19, 9)
AS
BEGIN
	DECLARE @1						NUMERIC(19, 9) = 1.0;
	DECLARE @10						NUMERIC(19, 9) = 10.0;
	DECLARE @400					NUMERIC(19, 9) = 400.0;
	RETURN @1 * @1 / (@1 + @1 * POWER(@10, @1 * (@Rating1 - @Rating2) / @400));
END;
GO

USE elotopia;
GO
CREATE FUNCTION elo.fn_Elo 
(
	@RatingA						NUMERIC(19, 9),
	@RatingB						NUMERIC(19, 9),
	@K								NUMERIC(19, 9),
	@D								TINYINT,			--{0 = Lose, 1 = Win, 2 = Tie} for A
	@Smooth							BIT,
	@Handicap						BIT
)
RETURNS @Elo
TABLE
(
	RatingA							NUMERIC(19, 9),
	RatingB							NUMERIC(19, 9)
)
AS 
BEGIN
	DECLARE @1						NUMERIC(19, 9) = 1;
	DECLARE @0						NUMERIC(19, 9) = 0;
	DECLARE @PA						NUMERIC(19, 9);
	DECLARE @PB						NUMERIC(19, 9);
	DECLARE @BOPRA					NUMERIC(19, 9);
	DECLARE @BOPRB					NUMERIC(19, 9);
	DECLARE	@HandicappedWin			BIT;
	SELECT	@BOPRA					= @RatingA;
	SELECT	@BOPRB					= @RatingB;
	SELECT	@HandicappedWin			= CASE WHEN @D = 0 THEN 1  ELSE 0 END; 
	SELECT	@PB						= elo.fn_Probability(@RatingA, @RatingB);
	SELECT	@PA						= elo.fn_Probability(@RatingB, @RatingA);
	IF		@D						= 1								
	BEGIN
		SELECT @RatingA				= @RatingA + @K * (@1 - @PA);
		SELECT @RatingB				= @RatingB + @K * (@0 - @PB);
	END
	ELSE
	IF	@D							= 0
	BEGIN
		SELECT @RatingA				= @RatingA + @K * (@0 - @PA);			
		SELECT @RatingB				= @RatingB + @K * (@1 - @PB);
	END
	IF	@D							= 2											--Process a tie as a win and a loss.
	BEGIN
		SELECT @RatingA				= @RatingA + @K * (@1 - @PA);
		SELECT @RatingB				= @RatingB + @K * (@0 - @PB);
		SELECT @RatingA				= @RatingA + @K * (@0 - @PA);			
		SELECT @RatingB				= @RatingB + @K * (@1 - @PB);
	END 
	IF @Handicap = 1
	BEGIN
		IF @HandicappedWin = 1
		BEGIN
			SELECT @RatingA			= @RatingA - (@BOPRA - @RatingA) * 2;		--Double the loss as it was 'Advantaged'
			SELECT @RatingB			= @RatingB + (@RatingB - @BOPRB) * 2;		--Double the gain as it was 'Disadvantaged'
		END 
		ELSE
		BEGIN
			SELECT @RatingA			= @BOPRA + (@RatingA - @BOPRA) / 2;			--Halve the gain as it was 'Advantaged'
			SELECT @RatingB			= @BOPRB - (@BOPRB - @RatingB) / 2;			--Halve the loss as it was 'Disadvantaged'
		END
	END
	IF @Smooth = 1
	BEGIN
		SELECT @RatingA = CAST(@RatingA + 0.4999999999 AS INTEGER);
		SELECT @RatingB = CAST(@RatingB + 0.4999999999 AS INTEGER);
	END 
	INSERT INTO @Elo
	(
		RatingA,
		RatingB 
	)
	SELECT
		@RatingA,
		@RatingB 
	RETURN;
END;
GO

CREATE PROCEDURE elo.pr_Model_New
(
	@ModelID					INT,
	@ModelName					NVARCHAR(50),
	@ModelDescription			NVARCHAR(1000)	NULL
)
AS
IF (SELECT ISNULL(SUM(ModelID), 0) FROM elo.tb_Model WHERE ModelID = @ModelID) > 0
BEGIN
	RAISERROR('ModelID already in use...sorry.', 16, 1);
	RETURN;
END
IF (SELECT ISNULL(COUNT(1), 0) FROM elo.tb_Model WHERE ModelName = @ModelName) > 0 
BEGIN
	RAISERROR('ModelName already in use...sorry.', 16, 1);
	RETURN;
END
INSERT INTO elo.tb_Model
(
	ModelID,
	ModelName,
	ModelDescription 
)
SELECT
	@ModelID,
	@ModelName,
	@ModelDescription;
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

USE elotopia;
GO
CREATE PROCEDURE elo.pr_Source_New
(
	@ModelID					INT,
	@SourceID					SMALLINT,
	@SourceName					NVARCHAR(50),
	@SourceLocation				NVARCHAR(1000),
	@SourceType					NVARCHAR(20)
)
AS
IF (SELECT ISNULL(SUM(ModelID + SourceID), 0) FROM elo.tb_Source WHERE ModelID = @ModelID AND SourceID = @SourceID) > 0
BEGIN
	RAISERROR('ModelID-SourceID combination already in use...sorry.', 16, 1);
	RETURN;
END
IF (SELECT ISNULL(COUNT(1), 0) FROM elo.tb_Source WHERE ModelID = @ModelID AND SourceName = @SourceName) > 0  
BEGIN
	RAISERROR('SourceName already in use...sorry.', 16, 1);
	RETURN;
END
INSERT INTO elo.tb_Source 
(
	ModelID,
	SourceID,  
	SourceName, 
	SourceLocation, 
	SourceType
)
SELECT
	@ModelID,
	@SourceID,  
	@SourceName,  
	@SourceLocation,
	@SourceType;
GO
USE elotopia;
GO 
CREATE PROCEDURE elo.pr_Team_Upsert
(
	@ModelID						INT,
	@RatingID						SMALLINT 
)
AS
CREATE TABLE #tb_Team
(
	ModelID							INT,
	TeamID							BIGINT IDENTITY(1, 1),
	TeamName						NVARCHAR(200)
);
INSERT INTO #tb_Team
(
	ModelID,
	TeamName 
)
SELECT
	ModelID,
	TeamNameA
FROM 
	elo.tb_EventSource
WHERE
	ModelID							= @ModelID					AND
	RatingID						= @RatingID 
UNION
SELECT
	ModelID,
	TeamNameB
FROM 
	elo.tb_EventSource
WHERE
	ModelID							= @ModelID					AND
	RatingID						= @RatingID ;
DELETE FROM elo.tb_Team WHERE ModelID = @ModelID;
UPDATE STATISTICS elo.tb_Team;
INSERT INTO elo.tb_Team
(
	ModelID,
	TeamID,
	TeamName 
)
SELECT
	ModelID,
	TeamID,
	TeamName 
FROM
	#tb_Team
ORDER BY
	TeamName;

GO
--*************************************
USE elotopia;
GO
CREATE PROCEDURE elo.pr_TeamRating_Initialize
(
	@ModelID							INT
)
AS
DELETE FROM elo.tb_TeamRatingEvent WHERE ModelID = @ModelID;
DELETE FROM elo.tb_TeamRating WHERE ModelID = @ModelID;
UPDATE STATISTICS elo.tb_TeamRating;
INSERT INTO elo.tb_TeamRating 
(
	ModelID,
	TeamID,
	RatingID,
	Elo 
)
SELECT
	t.ModelID,
	t.TeamID,
	r.RatingID,
	800.0
FROM 
	elo.tb_Team t
	INNER JOIN elo.tb_Rating r 
	ON	t.ModelID							= r.ModelID 
WHERE
	t.ModelID									= @ModelID
ORDER BY
	t.TeamID;
GO

USE elotopia;
GO
CREATE PROCEDURE elo.pr_EventManufactured_Manufacture
(
	@ModelID								INT,
	@SourceID								SMALLINT
)
AS
DELETE FROM elo.tb_EventManufactured WHERE ModelID = @ModelID;
UPDATE STATISTICS elo.tb_EventManufactured;
CREATE TABLE #tb_Event
(
	RatingID								SMALLINT,
	EventID									BIGINT IDENTITY(1, 1),
	TeamNameA								NVARCHAR(200),
	TeamNameB								NVARCHAR(200)
);
CREATE TABLE #tb_EventManufactured
(
	ModelID									INT,
	RatingID								SMALLINT,
	EventID									BIGINT,
	TeamID									BIGINT,
	D										TINYINT,
	A										BIT 
);
INSERT INTO #tb_EventManufactured
(
	ModelID,
	RatingID,
	EventID,
	TeamID,
	D,
	A 
)
SELECT
	t.ModelID,
	r.RatingID,
	s.EventID,
	t.TeamID,
	s.D,
	CASE WHEN t.TeamName = TeamNameA THEN 1 ELSE 0 END AS A
FROM
	elo.tb_Team t
	INNER JOIN elo.tb_EventSource s
	ON	t.ModelID						= s.ModelID					AND
		t.TeamName						IN (TeamNameA, TeamNameB)
	INNER JOIN elo.tb_Rating r
	ON	t.ModelID						= r.ModelID										
WHERE
	s.SourceID							= @SourceID;
INSERT INTO elo.tb_EventManufactured
(
	ModelID,
	RatingID,
	EventID,
	TeamID,
	D,
	A 
)
SELECT
	ModelID,
	RatingID,
	EventID,
	TeamID,
	D,
	A 
FROM 
	#tb_EventManufactured;
GO

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

CREATE PROCEDURE elo.pr_ProbabilityMatrix
(
	@ModelID								INT,
	@RatingID								SMALLINT
)
AS
SELECT
	a.TeamA,
	a.TeamB,
	a_Not_Lose * b_Not_Lose * a_not_win * b_not_win AS Tie_Probability,
	a_Not_Lose * (1.000000 - (a_Not_Lose * b_Not_Lose * a_not_win * b_not_win)) AS TeamA_Win_Probability,
	1.0000000 - ((a_Not_Lose * b_Not_Lose * a_not_win * b_not_win) + (a_Not_Lose * (1.00000000 - (a_Not_Lose * b_Not_Lose * a_not_win * b_not_win)))) AS Team_B_Win_Probability,
	(a_Not_Lose * (1.0000000 - (a_Not_Lose * b_Not_Lose * a_not_win * b_not_win)) + a_Not_Lose * b_Not_Lose * a_not_win * b_not_win) / 2.0000 AS A_or_Draw,
	(a_Not_Lose * (1.00000000 - (a_Not_Lose * b_Not_Lose * a_not_win * b_not_win)) + 1.000000000 - ((a_Not_Lose * b_Not_Lose * a_not_win * b_not_win) + (a_Not_Lose * (1.000000000 - (a_Not_Lose * b_Not_Lose * a_not_win * b_not_win))))) / 2.00000 AS A_OR_B,
	(a_Not_Lose * b_Not_Lose * a_not_win * b_not_win + 1.000000000 - ((a_Not_Lose * b_Not_Lose * a_not_win * b_not_win) + (a_Not_Lose * (1.000000000 - (a_Not_Lose * b_Not_Lose * a_not_win * b_not_win))))) / 2.000000 AS Draw_Or_B 
FROM 
(
SELECT
	ta.TeamName as TeamA,
	tb.TeamName as TeamB,
	elo.fn_Probability(b.Elo, a.Elo) AS a_Not_Lose,
	elo.fn_Probability(a.Elo, b.Elo) AS b_Not_Lose,
	elo.fn_Probability(a.Elo, b.Elo) AS a_not_win,
	elo.fn_Probability(b.Elo, a.Elo) AS b_not_win 
FROM 
	elo.tb_TeamRating a
	INNER JOIN elo.tb_TeamRating b
	ON a.TeamID <> b.TeamID  AND 
	   a.ModelID = b.ModelID AND
	   a.RatingID = b.RatingID 
	INNER JOIN elo.tb_Team ta 
	ON a.TeamID = ta.TeamID
	INNER JOIN elo.tb_Team tb 
	ON b.TeamID = tb.TeamID
WHERE
	b.ModelID = @ModelID and 
	b.RatingID = @RatingID
) AS a


GO


--***takeon script
EXEC elo.pr_Model_New
	@ModelID = 1,
	@ModelName = 'Professional Association Football',
	@ModelDescription = NULL;

GO

EXEC elo.pr_Rating_New
	@ModelID					= 1,
	@RatingID					= 1,
	@RatingName					= 'Win',
	@IgnoreTies					= 0,
	@RoundRobin					= 0,
	@Smooth						= 1,
	@Handicap					= 1,
	@K							= 64;
GO

EXEC elo.pr_Source_New 
	@ModelID					= 1,
	@SourceID					= 1,
	@SourceName					= 'Win Source',
	@SourceLocation				= @@SERVERNAME,
	@SourceType					= 'Internal';

INSERT INTO elo.tb_EventSource VALUES(1,1,1,1,'Brentford', 'Arsenal', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,2,1,'Burnley', 'Brighton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,3,1,'Chelsea', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,4,1,'Everton', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,5,1,'Leicester City', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,6,1,'Man United', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,7,1,'Norwich City', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,8,1,'Watford', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,9,1,'Newcastle', 'West Ham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,10,1,'Tottenham', 'Man City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,11,1,'Aston Villa', 'Newcastle', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,12,1,'Brighton', 'Watford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,13,1,'Crystal Palace', 'Brentford', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,14,1,'Leeds', 'Everton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,15,1,'Liverpool', 'Burnley', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,16,1,'Man City', 'Norwich City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,17,1,'Arsenal', 'Chelsea', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,18,1,'Southampton', 'Man United', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,19,1,'Wolves', 'Tottenham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,20,1,'West Ham', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,21,1,'Aston Villa', 'Brentford', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,22,1,'Brighton', 'Everton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,23,1,'Liverpool', 'Chelsea', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,24,1,'Man City', 'Arsenal', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,25,1,'Newcastle', 'Southampton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,26,1,'Norwich City', 'Leicester', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,27,1,'West Ham', 'Crystal Palace', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,28,1,'Burnley', 'Leeds', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,29,1,'Tottenham', 'Watford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,30,1,'Wolves', 'Man United', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,31,1,'Arsenal', 'Norwich City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,32,1,'Brentford', 'Brighton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,33,1,'Chelsea', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,34,1,'Crystal Palace', 'Tottenham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,35,1,'Leicester City', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,36,1,'Man United', 'Newcastle', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,37,1,'Southampton', 'West Ham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,38,1,'Watford', 'Wolves', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,39,1,'Leeds', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,40,1,'Everton', 'Burnley', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,41,1,'Newcastle', 'Leeds', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,42,1,'Aston Villa', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,43,1,'Burnley', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,44,1,'Liverpool', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,45,1,'Man City', 'Southampton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,46,1,'Norwich City', 'Watford', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,47,1,'Wolves', 'Brentford', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,48,1,'Brighton', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,49,1,'Tottenham', 'Chelsea', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,50,1,'West Ham', 'Man United', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,51,1,'Brentford', 'Liverpool', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,52,1,'Chelsea', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,53,1,'Everton', 'Norwich City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,54,1,'Leeds', 'West Ham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,55,1,'Leicester City', 'Burnley', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,56,1,'Man United', 'Aston Villa', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,57,1,'Watford', 'Newcastle', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,58,1,'Arsenal', 'Tottenham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,59,1,'Southampton', 'Wolves', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,60,1,'Crystal Palace', 'Brighton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,61,1,'Brighton', 'Arsenal', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,62,1,'Burnley', 'Norwich City', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,63,1,'Chelsea', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,64,1,'Leeds', 'Watford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,65,1,'Man United', 'Everton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,66,1,'Wolves', 'Newcastle', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,67,1,'Crystal Palace', 'Leicester', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,68,1,'Liverpool', 'Man City', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,69,1,'Tottenham', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,70,1,'West Ham', 'Brentford', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,71,1,'Aston Villa', 'Wolves', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,72,1,'Brentford', 'Chelsea', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,73,1,'Leicester City', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,74,1,'Man City', 'Burnley', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,75,1,'Norwich City', 'Brighton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,76,1,'Southampton', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,77,1,'Watford', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,78,1,'Everton', 'West Ham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,79,1,'Newcastle', 'Tottenham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,80,1,'Arsenal', 'Crystal Palace', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,81,1,'Arsenal', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,82,1,'Brighton', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,83,1,'Chelsea', 'Norwich City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,84,1,'Crystal Palace', 'Newcastle', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,85,1,'Everton', 'Watford', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,86,1,'Leeds', 'Wolves', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,87,1,'Southampton', 'Burnley', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,88,1,'Brentford', 'Leicester', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,89,1,'Man United', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,90,1,'West Ham', 'Tottenham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,91,1,'Burnley', 'Brentford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,92,1,'Leicester City', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,93,1,'Liverpool', 'Brighton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,94,1,'Man City', 'Crystal Palace', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,95,1,'Newcastle', 'Chelsea', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,96,1,'Tottenham', 'Man United', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,97,1,'Watford', 'Southampton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,98,1,'Aston Villa', 'West Ham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,99,1,'Norwich City', 'Leeds', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,100,1,'Wolves', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,101,1,'Southampton', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,102,1,'Brentford', 'Norwich City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,103,1,'Brighton', 'Newcastle', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,104,1,'Chelsea', 'Burnley', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,105,1,'Crystal Palace', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,106,1,'Man United', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,107,1,'Arsenal', 'Watford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,108,1,'Everton', 'Tottenham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,109,1,'Leeds', 'Leicester', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,110,1,'West Ham', 'Liverpool', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,111,1,'Aston Villa', 'Brighton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,112,1,'Burnley', 'Crystal Palace', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,113,1,'Leicester City', 'Chelsea', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,114,1,'Liverpool', 'Arsenal', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,115,1,'Newcastle', 'Brentford', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,116,1,'Norwich City', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,117,1,'Watford', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,118,1,'Wolves', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,119,1,'Man City', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,120,1,'Tottenham', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,121,1,'Arsenal', 'Newcastle', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,122,1,'Brighton', 'Leeds', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,123,1,'Crystal Palace', 'Aston Villa', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,124,1,'Liverpool', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,125,1,'Norwich City', 'Wolves', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,126,1,'Brentford', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,127,1,'Chelsea', 'Man United', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,128,1,'Leicester City', 'Watford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,129,1,'Man City', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,130,1,'Leeds', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,131,1,'Newcastle', 'Norwich City', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,132,1,'Aston Villa', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,133,1,'Everton', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,134,1,'Southampton', 'Leicester', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,135,1,'Watford', 'Chelsea', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,136,1,'West Ham', 'Brighton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,137,1,'Wolves', 'Burnley', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,138,1,'Man United', 'Arsenal', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,139,1,'Tottenham', 'Brentford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,140,1,'Newcastle', 'Burnley', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,141,1,'Southampton', 'Brighton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,142,1,'Watford', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,143,1,'West Ham', 'Chelsea', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,144,1,'Wolves', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,145,1,'Aston Villa', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,146,1,'Leeds', 'Brentford', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,147,1,'Man United', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,148,1,'Tottenham', 'Norwich City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,149,1,'Everton', 'Arsenal', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,150,1,'Brentford', 'Watford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,151,1,'Arsenal', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,152,1,'Chelsea', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,153,1,'Liverpool', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,154,1,'Man City', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,155,1,'Norwich City', 'Man United', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,156,1,'Burnley', 'West Ham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,157,1,'Crystal Palace', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,158,1,'Leicester City', 'Newcastle', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,159,1,'Man City', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,160,1,'Norwich City', 'Aston Villa', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,161,1,'Arsenal', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,162,1,'Brighton', 'Wolves', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,163,1,'Crystal Palace', 'Southampton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,164,1,'Chelsea', 'Everton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,165,1,'Liverpool', 'Newcastle', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,166,1,'Leeds', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,167,1,'Newcastle', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,168,1,'Tottenham', 'Liverpool', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,169,1,'Wolves', 'Chelsea', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,170,1,'Aston Villa', 'Chelsea', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,171,1,'Brighton', 'Brentford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,172,1,'Man City', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,173,1,'Norwich City', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,174,1,'Tottenham', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,175,1,'West Ham', 'Southampton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,176,1,'Newcastle', 'Man United', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,177,1,'Crystal Palace', 'Norwich City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,178,1,'Leicester City', 'Liverpool', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,179,1,'Southampton', 'Tottenham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,180,1,'Watford', 'West Ham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,181,1,'Brentford', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,182,1,'Chelsea', 'Brighton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,183,1,'Man United', 'Burnley', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,184,1,'Arsenal', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,185,1,'Crystal Palace', 'West Ham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,186,1,'Watford', 'Tottenham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,187,1,'Brentford', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,188,1,'Chelsea', 'Liverpool', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,189,1,'Everton', 'Brighton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,190,1,'Leeds', 'Burnley', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,191,1,'Man United', 'Wolves', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,192,1,'Southampton', 'Brentford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,193,1,'West Ham', 'Norwich City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,194,1,'Brighton', 'Crystal Palace', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,195,1,'Aston Villa', 'Man United', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,196,1,'Man City', 'Chelsea', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,197,1,'Newcastle', 'Watford', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,198,1,'Norwich City', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,199,1,'Wolves', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,200,1,'Liverpool', 'Brentford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,201,1,'West Ham', 'Leeds', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,202,1,'Brighton', 'Chelsea', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,203,1,'Brentford', 'Man United', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,204,1,'Leicester City', 'Tottenham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,205,1,'Watford', 'Norwich City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,206,1,'Brentford', 'Wolves', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,207,1,'Everton', 'Aston Villa', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,208,1,'Leeds', 'Newcastle', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,209,1,'Man United', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,210,1,'Southampton', 'Man City', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,211,1,'Arsenal', 'Burnley', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,212,1,'Chelsea', 'Tottenham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,213,1,'Crystal Palace', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,214,1,'Leicester City', 'Brighton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,215,1,'Burnley', 'Watford', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,216,1,'Burnley', 'Man United', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,217,1,'Newcastle', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,218,1,'West Ham', 'Watford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,219,1,'Aston Villa', 'Leeds', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,220,1,'Man City', 'Brentford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,221,1,'Norwich City', 'Crystal Palace', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,222,1,'Tottenham', 'Southampton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,223,1,'Liverpool', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,224,1,'Wolves', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,225,1,'Brentford', 'Crystal Palace', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,226,1,'Everton', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,227,1,'Man United', 'Southampton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,228,1,'Norwich City', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,229,1,'Watford', 'Brighton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,230,1,'Burnley', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,231,1,'Leicester City', 'West Ham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,232,1,'Newcastle', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,233,1,'Tottenham', 'Wolves', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,234,1,'Man United', 'Brighton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,235,1,'Arsenal', 'Brentford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,236,1,'Aston Villa', 'Watford', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,237,1,'Brighton', 'Burnley', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,238,1,'Crystal Palace', 'Chelsea', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,239,1,'Liverpool', 'Norwich City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,240,1,'Man City', 'Tottenham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,241,1,'Southampton', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,242,1,'West Ham', 'Newcastle', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,243,1,'Leeds', 'Man United', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,244,1,'Wolves', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,245,1,'Burnley', 'Tottenham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,246,1,'Liverpool', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,247,1,'Watford', 'Crystal Palace', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,248,1,'Arsenal', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,249,1,'Southampton', 'Norwich City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,250,1,'Brentford', 'Newcastle', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,251,1,'Brighton', 'Aston Villa', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,252,1,'Crystal Palace', 'Burnley', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,253,1,'Everton', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,254,1,'Leeds', 'Tottenham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,255,1,'Man United', 'Watford', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,256,1,'West Ham', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,257,1,'Burnley', 'Leicester', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,258,1,'Aston Villa', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,259,1,'Burnley', 'Chelsea', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,260,1,'Leicester City', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,261,1,'Liverpool', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,262,1,'Newcastle', 'Brighton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,263,1,'Norwich City', 'Brentford', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,264,1,'Wolves', 'Crystal Palace', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,265,1,'Man City', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,266,1,'Watford', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,267,1,'Tottenham', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,268,1,'Leeds', 'Aston Villa', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,269,1,'Norwich City', 'Chelsea', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,270,1,'Southampton', 'Newcastle', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,271,1,'Wolves', 'Watford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,272,1,'Brentford', 'Burnley', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,273,1,'Brighton', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,274,1,'Man United', 'Tottenham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,275,1,'Arsenal', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,276,1,'Chelsea', 'Newcastle', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,277,1,'Everton', 'Wolves', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,278,1,'Leeds', 'Norwich City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,279,1,'Southampton', 'Watford', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,280,1,'West Ham', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,281,1,'Crystal Palace', 'Man City', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,282,1,'Arsenal', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,283,1,'Brighton', 'Tottenham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,284,1,'Everton', 'Newcastle', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,285,1,'Wolves', 'Leeds', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,286,1,'Aston Villa', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,287,1,'Leicester City', 'Brentford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,288,1,'Tottenham', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,289,1,'Brighton', 'Norwich City', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,290,1,'Burnley', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,291,1,'Chelsea', 'Brentford', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,292,1,'Leeds', 'Southampton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,293,1,'Liverpool', 'Watford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,294,1,'Man United', 'Leicester', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,295,1,'Wolves', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,296,1,'Tottenham', 'Newcastle', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,297,1,'West Ham', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,298,1,'Crystal Palace', 'Arsenal', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,299,1,'Burnley', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,300,1,'Newcastle', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,301,1,'Arsenal', 'Brighton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,302,1,'Aston Villa', 'Tottenham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,303,1,'Everton', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,304,1,'Southampton', 'Chelsea', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,305,1,'Watford', 'Leeds', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,306,1,'Brentford', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,307,1,'Leicester City', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,308,1,'Man City', 'Liverpool', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,309,1,'Norwich City', 'Burnley', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,310,1,'Man United', 'Norwich City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,311,1,'Southampton', 'Arsenal', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,312,1,'Tottenham', 'Brighton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,313,1,'Watford', 'Brentford', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,314,1,'Newcastle', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,315,1,'West Ham', 'Burnley', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,316,1,'Liverpool', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,317,1,'Chelsea', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,318,1,'Everton', 'Leicester', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,319,1,'Man City', 'Brighton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,320,1,'Newcastle', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,321,1,'Burnley', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,322,1,'Arsenal', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,323,1,'Brentford', 'Tottenham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,324,1,'Leicester City', 'Aston Villa', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,325,1,'Man City', 'Watford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,326,1,'Norwich City', 'Newcastle', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,327,1,'Brighton', 'Southampton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,328,1,'Burnley', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,329,1,'Chelsea', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,330,1,'Liverpool', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,331,1,'Crystal Palace', 'Leeds', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,332,1,'Man United', 'Chelsea', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,333,1,'Aston Villa', 'Norwich City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,334,1,'Leeds', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,335,1,'Newcastle', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,336,1,'Southampton', 'Crystal Palace', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,337,1,'Watford', 'Burnley', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,338,1,'Wolves', 'Brighton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,339,1,'Everton', 'Chelsea', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,340,1,'Tottenham', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,341,1,'West Ham', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,342,1,'Man United', 'Brentford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,343,1,'Brentford', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,344,1,'Brighton', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,345,1,'Burnley', 'Aston Villa', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,346,1,'Chelsea', 'Wolves', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,347,1,'Crystal Palace', 'Watford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,348,1,'Liverpool', 'Tottenham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,349,1,'Arsenal', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,350,1,'Leicester City', 'Everton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,351,1,'Man City', 'Newcastle', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,352,1,'Norwich City', 'West Ham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,353,1,'Aston Villa', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,354,1,'Leeds', 'Chelsea', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,355,1,'Leicester City', 'Norwich City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,356,1,'Watford', 'Everton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,357,1,'Wolves', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,358,1,'Tottenham', 'Arsenal', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,359,1,'Aston Villa', 'Crystal Palace', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,360,1,'Everton', 'Brentford', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,361,1,'Leeds', 'Brighton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,362,1,'Tottenham', 'Burnley', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,363,1,'Watford', 'Leicester', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,364,1,'West Ham', 'Man City', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,365,1,'Wolves', 'Norwich City', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,366,1,'Newcastle', 'Arsenal', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,367,1,'Southampton', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,368,1,'Aston Villa', 'Burnley', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,369,1,'Chelsea', 'Leicester', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,370,1,'Everton', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,371,1,'Arsenal', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,372,1,'Brentford', 'Leeds', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,373,1,'Brighton', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,374,1,'Burnley', 'Newcastle', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,375,1,'Chelsea', 'Watford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,376,1,'Crystal Palace', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,377,1,'Leicester City', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,378,1,'Liverpool', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,379,1,'Man City', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,380,1,'Norwich City', 'Tottenham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,381,1,'Crystal Palace', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,382,1,'Fullham', 'Liverpool', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,383,1,'Bournemouth', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,384,1,'Leeds', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,385,1,'Newcastle', 'Nottingham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,386,1,'Tottenham', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,387,1,'Everton', 'Chelsea', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,388,1,'Leicester', 'Brentford', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,389,1,'Man United', 'Brighton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,390,1,'West Ham', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,391,1,'Aston Villa', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,392,1,'Arsenal', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,393,1,'Brighton', 'Newcastle', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,394,1,'Man City', 'Bournemouth', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,395,1,'Southampton', 'Leeds', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,396,1,'Wolves', 'Fullham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,397,1,'Brentford', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,398,1,'Nottingham', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,399,1,'Chelsea', 'Tottenham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,400,1,'Liverpool', 'Crystal Palace', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,401,1,'Tottenham', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,402,1,'Crystal Palace', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,403,1,'Everton', 'Nottingham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,404,1,'Fullham', 'Brentford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,405,1,'Leicester', 'Southampton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,406,1,'Bournemouth', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,407,1,'Leeds', 'Chelsea', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,408,1,'West Ham', 'Brighton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,409,1,'Newcastle', 'Man City', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,410,1,'Man United', 'Liverpool', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,411,1,'Southampton', 'Man United', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,412,1,'Brentford', 'Everton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,413,1,'Brighton', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,414,1,'Chelsea', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,415,1,'Liverpool', 'Bournemouth', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,416,1,'Man City', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,417,1,'Arsenal', 'Fullham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,418,1,'Aston Villa', 'West Ham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,419,1,'Wolves', 'Newcastle', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,420,1,'Nottingham', 'Tottenham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,421,1,'Crystal Palace', 'Brentford', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,422,1,'Fullham', 'Brighton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,423,1,'Southampton', 'Chelsea', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,424,1,'Leeds', 'Everton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,425,1,'Arsenal', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,426,1,'Bournemouth', 'Wolves', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,427,1,'Man City', 'Nottingham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,428,1,'West Ham', 'Tottenham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,429,1,'Liverpool', 'Newcastle', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,430,1,'Leicester', 'Man United', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,431,1,'Everton', 'Liverpool', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,432,1,'Brentford', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,433,1,'Chelsea', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,434,1,'Newcastle', 'Crystal Palace', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,435,1,'Nottingham', 'Bournemouth', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,436,1,'Tottenham', 'Fullham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,437,1,'Wolves', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,438,1,'Aston Villa', 'Man City', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,439,1,'Brighton', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,440,1,'Man United', 'Arsenal', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,441,1,'Aston Villa', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,442,1,'Nottingham', 'Fullham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,443,1,'Wolves', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,444,1,'Newcastle', 'Bournemouth', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,445,1,'Tottenham', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,446,1,'Brentford', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,447,1,'Everton', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,448,1,'Arsenal', 'Tottenham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,449,1,'Bournemouth', 'Brentford', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,450,1,'Crystal Palace', 'Chelsea', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,451,1,'Fullham', 'Newcastle', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,452,1,'Liverpool', 'Brighton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,453,1,'Southampton', 'Everton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,454,1,'West Ham', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,455,1,'Man City', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,456,1,'Leeds', 'Aston Villa', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,457,1,'Leicester', 'Nottingham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,458,1,'Bournemouth', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,459,1,'Chelsea', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,460,1,'Man City', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,461,1,'Newcastle', 'Brentford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,462,1,'Brighton', 'Tottenham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,463,1,'Crystal Palace', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,464,1,'West Ham', 'Fullham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,465,1,'Arsenal', 'Liverpool', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,466,1,'Everton', 'Man United', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,467,1,'Nottingham', 'Aston Villa', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,468,1,'Brentford', 'Brighton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,469,1,'Leicester', 'Crystal Palace', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,470,1,'Fullham', 'Bournemouth', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,471,1,'Wolves', 'Nottingham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,472,1,'Tottenham', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,473,1,'Aston Villa', 'Chelsea', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,474,1,'Leeds', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,475,1,'Man United', 'Newcastle', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,476,1,'Southampton', 'West Ham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,477,1,'Liverpool', 'Man City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,478,1,'Brighton', 'Nottingham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,479,1,'Crystal Palace', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,480,1,'Bournemouth', 'Southampton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,481,1,'Brentford', 'Chelsea', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,482,1,'Liverpool', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,483,1,'Newcastle', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,484,1,'Man United', 'Tottenham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,485,1,'Fullham', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,486,1,'Leicester', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,487,1,'Nottingham', 'Liverpool', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,488,1,'Everton', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,489,1,'Man City', 'Brighton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,490,1,'Chelsea', 'Man United', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,491,1,'Aston Villa', 'Brentford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,492,1,'Leeds', 'Fullham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,493,1,'Southampton', 'Arsenal', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,494,1,'Wolves', 'Leicester', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,495,1,'Tottenham', 'Newcastle', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,496,1,'West Ham', 'Bournemouth', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,497,1,'Leicester', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,498,1,'Bournemouth', 'Tottenham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,499,1,'Brentford', 'Wolves', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,500,1,'Brighton', 'Chelsea', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,501,1,'Crystal Palace', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,502,1,'Newcastle', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,503,1,'Fullham', 'Everton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,504,1,'Liverpool', 'Leeds', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,505,1,'Arsenal', 'Nottingham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,506,1,'Man United', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,507,1,'Leeds', 'Bournemouth', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,508,1,'Man City', 'Fullham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,509,1,'Nottingham', 'Brentford', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,510,1,'Wolves', 'Brighton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,511,1,'Everton', 'Leicester', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,512,1,'Chelsea', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,513,1,'Aston Villa', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,514,1,'Southampton', 'Newcastle', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,515,1,'West Ham', 'Crystal Palace', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,516,1,'Tottenham', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,517,1,'Man City', 'Brentford', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,518,1,'Bournemouth', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,519,1,'Liverpool', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,520,1,'Nottingham', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,521,1,'Tottenham', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,522,1,'West Ham', 'Leicester', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,523,1,'Newcastle', 'Chelsea', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,524,1,'Wolves', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,525,1,'Brighton', 'Aston Villa', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,526,1,'Fullham', 'Man United', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,527,1,'Brentford', 'Tottenham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,528,1,'Crystal Palace', 'Fullham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,529,1,'Everton', 'Wolves', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,530,1,'Leicester', 'Newcastle', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,531,1,'Southampton', 'Brighton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,532,1,'Aston Villa', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,533,1,'Arsenal', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,534,1,'Chelsea', 'Bournemouth', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,535,1,'Man United', 'Nottingham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,536,1,'Leeds', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,537,1,'West Ham', 'Brentford', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,538,1,'Liverpool', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,539,1,'Wolves', 'Man United', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,540,1,'Bournemouth', 'Crystal Palace', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,541,1,'Fullham', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,542,1,'Man City', 'Everton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,543,1,'Newcastle', 'Leeds', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,544,1,'Brighton', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,545,1,'Tottenham', 'Aston Villa', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,546,1,'Nottingham', 'Chelsea', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,547,1,'Brentford', 'Liverpool', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,548,1,'Arsenal', 'Newcastle', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,549,1,'Everton', 'Brighton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,550,1,'Leicester', 'Fullham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,551,1,'Man United', 'Bournemouth', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,552,1,'Southampton', 'Nottingham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,553,1,'Leeds', 'West Ham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,554,1,'Aston Villa', 'Wolves', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,555,1,'Crystal Palace', 'Tottenham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,556,1,'Chelsea', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,557,1,'Fullham', 'Chelsea', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,558,1,'Aston Villa', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,559,1,'Man United', 'Man City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,560,1,'Brighton', 'Liverpool', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,561,1,'Everton', 'Southampton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,562,1,'Nottingham', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,563,1,'Wolves', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,564,1,'Brentford', 'Bournemouth', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,565,1,'Chelsea', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,566,1,'Newcastle', 'Fullham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,567,1,'Tottenham', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,568,1,'Crystal Palace', 'Man United', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,569,1,'Man City', 'Tottenham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,570,1,'Liverpool', 'Chelsea', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,571,1,'Bournemouth', 'Nottingham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,572,1,'Leicester', 'Brighton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,573,1,'Southampton', 'Aston Villa', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,574,1,'West Ham', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,575,1,'Crystal Palace', 'Newcastle', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,576,1,'Leeds', 'Brentford', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,577,1,'Man City', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,578,1,'Arsenal', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,579,1,'Fullham', 'Tottenham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,580,1,'Chelsea', 'Fullham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,581,1,'Everton', 'Arsenal', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,582,1,'Aston Villa', 'Leicester', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,583,1,'Brentford', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,584,1,'Brighton', 'Bournemouth', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,585,1,'Man United', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,586,1,'Wolves', 'Liverpool', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,587,1,'Newcastle', 'West Ham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,588,1,'Nottingham', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,589,1,'Tottenham', 'Man City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,590,1,'Man United', 'Leeds', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,591,1,'West Ham', 'Chelsea', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,592,1,'Arsenal', 'Brentford', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,593,1,'Crystal Palace', 'Brighton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,594,1,'Fullham', 'Nottingham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,595,1,'Leicester', 'Tottenham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,596,1,'Southampton', 'Wolves', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,597,1,'Bournemouth', 'Newcastle', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,598,1,'Leeds', 'Man United', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,599,1,'Man City', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,600,1,'Liverpool', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,601,1,'Arsenal', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,602,1,'Aston Villa', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,603,1,'Brentford', 'Crystal Palace', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,604,1,'Brighton', 'Fullham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,605,1,'Chelsea', 'Southampton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,606,1,'Everton', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,607,1,'Nottingham', 'Man City', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,608,1,'Wolves', 'Bournemouth', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,609,1,'Newcastle', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,610,1,'Man United', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,611,1,'Tottenham', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,612,1,'Fullham', 'Wolves', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,613,1,'Everton', 'Aston Villa', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,614,1,'Leeds', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,615,1,'Leicester', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,616,1,'West Ham', 'Nottingham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,617,1,'Bournemouth', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,618,1,'Crystal Palace', 'Liverpool', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,619,1,'Tottenham', 'Chelsea', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,620,1,'Arsenal', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,621,1,'Liverpool', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,622,1,'Man City', 'Newcastle', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,623,1,'Arsenal', 'Bournemouth', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,624,1,'Aston Villa', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,625,1,'Brighton', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,626,1,'Chelsea', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,627,1,'Wolves', 'Tottenham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,628,1,'Southampton', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,629,1,'Nottingham', 'Everton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,630,1,'Liverpool', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,631,1,'Brentford', 'Fullham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,632,1,'Bournemouth', 'Liverpool', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,633,1,'Everton', 'Brentford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,634,1,'Leeds', 'Brighton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,635,1,'Leicester', 'Chelsea', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,636,1,'Tottenham', 'Nottingham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,637,1,'Crystal Palace', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,638,1,'Fullham', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,639,1,'Man United', 'Southampton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,640,1,'West Ham', 'Aston Villa', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,641,1,'Newcastle', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,642,1,'Brighton', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,643,1,'Southampton', 'Brentford', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,644,1,'Nottingham', 'Newcastle', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,645,1,'Aston Villa', 'Bournemouth', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,646,1,'Brentford', 'Leicester', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,647,1,'Southampton', 'Tottenham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,648,1,'Wolves', 'Leeds', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,649,1,'Chelsea', 'Everton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,650,1,'Arsenal', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,651,1,'Man City', 'Liverpool', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,652,1,'Arsenal', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,653,1,'Bournemouth', 'Fullham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,654,1,'Brighton', 'Brentford', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,655,1,'Crystal Palace', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,656,1,'Nottingham', 'Wolves', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,657,1,'Chelsea', 'Aston Villa', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,658,1,'West Ham', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,659,1,'Newcastle', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,660,1,'Everton', 'Tottenham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,661,1,'Bournemouth', 'Brighton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,662,1,'Leeds', 'Nottingham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,663,1,'Leicester', 'Aston Villa', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,664,1,'Chelsea', 'Liverpool', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,665,1,'Man United', 'Brentford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,666,1,'West Ham', 'Newcastle', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,667,1,'Man United', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,668,1,'Aston Villa', 'Nottingham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,669,1,'Brentford', 'Newcastle', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,670,1,'Fullham', 'West Ham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,671,1,'Leicester', 'Bournemouth', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,672,1,'Tottenham', 'Brighton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,673,1,'Wolves', 'Chelsea', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,674,1,'Southampton', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,675,1,'Leeds', 'Crystal Palace', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,676,1,'Liverpool', 'Arsenal', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,677,1,'Aston Villa', 'Newcastle', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,678,1,'Chelsea', 'Brighton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,679,1,'Everton', 'Fullham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,680,1,'Southampton', 'Crystal Palace', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,681,1,'Tottenham', 'Bournemouth', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,682,1,'Wolves', 'Brentford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,683,1,'Man City', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,684,1,'West Ham', 'Arsenal', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,685,1,'Nottingham', 'Man United', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,686,1,'Leeds', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,687,1,'Arsenal', 'Southampton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,688,1,'Fullham', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,689,1,'Brentford', 'Aston Villa', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,690,1,'Crystal Palace', 'Everton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,691,1,'Leicester', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,692,1,'Liverpool', 'Nottingham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,693,1,'Bournemouth', 'West Ham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,694,1,'Newcastle', 'Tottenham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,695,1,'Wolves', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,696,1,'Aston Villa', 'Fullham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,697,1,'Leeds', 'Leicester', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,698,1,'Nottingham', 'Brighton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,699,1,'Chelsea', 'Brentford', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,700,1,'West Ham', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,701,1,'Man City', 'Arsenal', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,702,1,'Everton', 'Newcastle', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,703,1,'Southampton', 'Bournemouth', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,704,1,'Tottenham', 'Man United', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,705,1,'Crystal Palace', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,706,1,'Brentford', 'Nottingham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,707,1,'Brighton', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,708,1,'Bournemouth', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,709,1,'Fullham', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,710,1,'Man United', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,711,1,'Newcastle', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,712,1,'Liverpool', 'Tottenham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,713,1,'Leicester', 'Everton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,714,1,'Arsenal', 'Chelsea', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,715,1,'Liverpool', 'Fullham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,716,1,'Man City', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,717,1,'Brighton', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,718,1,'Bournemouth', 'Chelsea', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,719,1,'Man City', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,720,1,'Tottenham', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,721,1,'Wolves', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,722,1,'Liverpool', 'Brentford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,723,1,'Newcastle', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,724,1,'West Ham', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,725,1,'Fullham', 'Leicester', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,726,1,'Brighton', 'Everton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,727,1,'Nottingham', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,728,1,'Leeds', 'Newcastle', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,729,1,'Aston Villa', 'Tottenham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,730,1,'Chelsea', 'Nottingham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,731,1,'Crystal Palace', 'Bournemouth', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,732,1,'Man United', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,733,1,'Southampton', 'Fullham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,734,1,'Brentford', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,735,1,'Everton', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,736,1,'Arsenal', 'Brighton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,737,1,'Leicester', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,738,1,'Newcastle', 'Brighton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,739,1,'Tottenham', 'Brentford', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,740,1,'Bournemouth', 'Man United', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,741,1,'Fullham', 'Crystal Palace', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,742,1,'Liverpool', 'Aston Villa', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,743,1,'Wolves', 'Everton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,744,1,'Nottingham', 'Arsenal', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,745,1,'West Ham', 'Leeds', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,746,1,'Brighton', 'Southampton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,747,1,'Man City', 'Chelsea', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,748,1,'Newcastle', 'Leicester', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,749,1,'Brighton', 'Man City', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,750,1,'Man United', 'Chelsea', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,751,1,'Arsenal', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,752,1,'Aston Villa', 'Brighton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,753,1,'Brentford', 'Man City', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,754,1,'Chelsea', 'Newcastle', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,755,1,'Crystal Palace', 'Nottingham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,756,1,'Everton', 'Bournemouth', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,757,1,'Leeds', 'Tottenham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,758,1,'Leicester', 'West Ham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,759,1,'Man United', 'Fullham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,760,1,'Southampton', 'Liverpool', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,761,1,'Burnley', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,762,1,'Arsenal', 'Nottingham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,763,1,'Bournemouth', 'West Ham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,764,1,'Brighton', 'Luton Town', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,765,1,'Everton', 'Fullham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,766,1,'Newcastle', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,767,1,'Sheffield United', 'Crystal Palace', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,768,1,'Brentford', 'Tottenham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,769,1,'Chelsea', 'Liverpool', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,770,1,'Man United', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,771,1,'Nottingham', 'Sheffield United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,772,1,'Fullham', 'Brentford', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,773,1,'Liverpool', 'Bournemouth', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,774,1,'Man City', 'Newcastle', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,775,1,'Tottenham', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,776,1,'Wolves', 'Brighton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,777,1,'Aston Villa', 'Everton', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,778,1,'West Ham', 'Chelsea', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,779,1,'Crystal Palace', 'Arsenal', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,780,1,'Chelsea', 'Luton Town', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,781,1,'Arsenal', 'Fullham', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,782,1,'Bournemouth', 'Tottenham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,783,1,'Brentford', 'Crystal Palace', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,784,1,'Brighton', 'West Ham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,785,1,'Everton', 'Wolves', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,786,1,'Man United', 'Nottingham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,787,1,'Burnley', 'Aston Villa', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,788,1,'Newcastle', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,789,1,'Sheffield United', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,790,1,'Luton Town', 'West Ham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,791,1,'Brentford', 'Bournemouth', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,792,1,'Brighton', 'Newcastle', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,793,1,'Burnley', 'Tottenham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,794,1,'Chelsea', 'Nottingham', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,795,1,'Man City', 'Fullham', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,796,1,'Sheffield United', 'Everton', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,797,1,'Arsenal', 'Man United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,798,1,'Crystal Palace', 'Wolves', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,799,1,'Liverpool', 'Aston Villa', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,800,1,'Wolves', 'Liverpool', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,801,1,'Fullham', 'Luton Town', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,802,1,'Tottenham', 'Sheffield United', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,803,1,'West Ham', 'Man City', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,804,1,'Man United', 'Brighton', 0);
INSERT INTO elo.tb_EventSource VALUES(1,1,805,1,'Aston Villa', 'Crystal Palace', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,806,1,'Newcastle', 'Brentford', 1);
INSERT INTO elo.tb_EventSource VALUES(1,1,807,1,'Bournemouth', 'Chelsea', 2);
INSERT INTO elo.tb_EventSource VALUES(1,1,808,1,'Everton', 'Arsenal', 0);
GO

EXEC elo.pr_Team_Upsert
	@ModelID						= 1,
	@RatingID						= 1;

EXEC elo.pr_TeamRating_Initialize @ModelID = 1;

EXEC elo.pr_EventManufactured_Manufacture
	@ModelID							= 1,
	@SourceID							= 1;
GO

exec elo.pr_Model_Train 1;

exec elo.pr_ProbabilityMatrix 1, 1;
--***************************************************************************
