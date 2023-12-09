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
