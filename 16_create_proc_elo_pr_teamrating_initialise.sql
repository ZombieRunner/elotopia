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
