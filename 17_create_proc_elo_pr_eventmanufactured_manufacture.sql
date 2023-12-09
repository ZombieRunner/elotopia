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
