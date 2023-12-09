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
