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
