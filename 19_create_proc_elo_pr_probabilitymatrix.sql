
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
