USE [QACOP]
GO
/****** Object:  StoredProcedure [dbo].[SP_Utility_Ingestion_Compare]    Script Date: 3/30/2020 7:25:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--DROP PROCEDURE SP_Utility_Ingestion_Compare
ALTER PROCEDURE [dbo].[SP_Utility_Ingestion_Compare]
AS
/* Declare all required variables and updated list of columns for @list */
DECLARE @ScenarioCount INT
	,@SOURCE_CNT INT
	,@TARGET_CNT INT
	,@SOURCERECORD_CNT INT
	,@TARGETRECORD_CNT INT
	,@FINAL_STATUS NVARCHAR(50)
	,@STATUS_DESCRIPTION NVARCHAR(500)
	,@id INT = 1
	,@i INT = 1
	,@s INT = 1
	,@COL_COUNT INT
	,@COLUMN_NAME NVARCHAR(50)
	,@sqlText NVARCHAR(max)
	,@VAR NVARCHAR(50)
	,@PlanName NVARCHAR(max)
	,@FileNM NVARCHAR(max)
	,@SourceColumns NVARCHAR(max) = NULL
	,@SourceTable NVARCHAR(max) = NULL
	,@TargetTable NVARCHAR(max) = NULL
	,@TargetColumns NVARCHAR(max) = NULL
	,@TestScenarioDetails NVARCHAR(max)
	,@ColumnNameListSource VARCHAR(MAX)
	,@ColumnNameListTarget VARCHAR(MAX)
	,@SRCminusTRGTableName VARCHAR(MAX)
	,@TRGminusSRCTableName VARCHAR(MAX)
/* Creating table variable to store the column Names */
DECLARE @column_table TABLE (value VARCHAR(MAX) NOT NULL)
/* Creating table variable to store test sceanrio list */
DECLARE @testscenario TABLE (
	row_num INT NOT NULL
	,PlanName VARCHAR(MAX) NOT NULL
	,FileNM VARCHAR(MAX) NOT NULL
	,SourceTable VARCHAR(MAX) NOT NULL
	,TargetTable VARCHAR(MAX) NOT NULL
	,ExecuteScenario VARCHAR(MAX) NOT NULL
	)
DECLARE @TempCount TABLE (CNT INT NOT NULL);
DECLARE @Tempdata TABLE (Results VARCHAR(MAX));

BEGIN
	SET NOCOUNT ON;

	/* DROP Output Result table before start of testing */
	--TRUNCATE TABLE SP_Utility_Ingestion_Compare_OUTPUT;

	/* ----------------------------- Start of reading Scenario File---------------------------------  */
	/* Read Information from Test Scenario document */
	INSERT INTO @TestScenario
	SELECT ROW_NUMBER() OVER (
			ORDER BY PlanName
				,FileNM
				,SourceTable
				,TargetTable
				,ExecuteScenario
			) row_num
		,*
	FROM SP_Utility_Ingestion_Compare_TestScenario
	WHERE ExecuteScenario = 'Y';

	SET @ScenarioCount = (
			SELECT COUNT(*)
			FROM @TestScenario
			);


	/* Store Information for each row */
	WHILE @s <= @ScenarioCount
	BEGIN
		/* Extract Test scenario information */
		SET @PlanName = (
				SELECT PlanName
				FROM @testscenario
				WHERE row_num = @s
				);
		SET @FileNM = (
				SELECT FileNM
				FROM @testscenario
				WHERE row_num = @s
				);
		SET @SourceTable = (
				SELECT SourceTable
				FROM @testscenario
				WHERE row_num = @s
				);
		SET @TargetTable = (
				SELECT TargetTable
				FROM @testscenario
				WHERE row_num = @s
				);

		/* -----------------------------Start of One to One mapping comparisong between Source and Target Table---------------------------------  */
		DELETE
		FROM @column_table

		/* Store list of columns from source table in Temporary table variable  */
		INSERT INTO @column_table
		SELECT COLUMN_NAME
		FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_NAME = @SourceTable

		/* reset the columnlist variables */
		SET @ColumnNameListSource = NULL
		SET @ColumnNameListTarget = NULL

		/* Create list of columns for source table  */
		SELECT @ColumnNameListSource = COALESCE(@ColumnNameListSource + ', ', '') + COLUMN_NAME + ' as ' + COLUMN_NAME +'' --COALESCE(@ColumnNameListSource + ', ', '') + 'nullif (' + COLUMN_NAME + ', '''' ) as ' + COLUMN_NAME + ' '
		FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_NAME = @SourceTable

		/* Create list of columns for target table (using source as @sourcetable only as target table has extra columns which are NOT needed) */
		SELECT @ColumnNameListTarget = COALESCE(@ColumnNameListTarget + ', ', '') + COLUMN_NAME + ' as ' + COLUMN_NAME +'' --COALESCE(@ColumnNameListTarget + ', ', '') + 'nullif (' + COLUMN_NAME + ', ''null'' ) ' + 'as ' + COLUMN_NAME + ''
		FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_NAME = @SourceTable

		/*  ----  Source Record Count SQL ----  */
		DELETE
		FROM @TempCount

		SET @sqlText = N'SELECT COUNT (*) FROM ' + @SourceTable + ''

		INSERT INTO @TempCount
		EXEC (@sqlText);

		SET @SOURCERECORD_CNT = (
				SELECT *
				FROM @TempCount
				);

		/*  ----  Target Record Count SQL ----  */
		DELETE
		FROM @TempCount

		SET @sqlText = N'SELECT COUNT (*) FROM ' + @TargetTable + ''

		INSERT INTO @TempCount
		EXEC (@sqlText);

		SET @TARGETRECORD_CNT = (
				SELECT *
				FROM @TempCount
				);

		/*  ----  Source SQL Minus Target SQL ----  */
		DELETE
		FROM @TempCount -- Clear the TempCount table 

		SET @SRCminusTRGTableName = NULL -- Clear the temp variable
		/* Drop output table if already existing */
		SET @SRCminusTRGTableName = @SourceTable + '_EXCEPT_' + @TargetTable
		SET @sqlText = N' DROP TABLE IF EXISTS ' + @SRCminusTRGTableName + ''

		EXEC (@sqlText);

		--SELECT @SRCminusTRGTableName
		--SELECT @ColumnNameListSource
		--SELECT @ColumnNameListTarget

		/* SQL to store the result of EXCEPT statement */
		SET @sqlText = N' 
SELECT * INTO ' + @SRCminusTRGTableName + ' FROM
(
SELECT ' + @ColumnNameListSource + ' FROM ' + @SourceTable + ' 
EXCEPT
SELECT ' + @ColumnNameListTarget + ' FROM ' + @TargetTable + '  
) SRCminTRG'


		EXEC (@sqlText);

		/* SQL to count the mismatched records */
		SET @sqlText = N' SELECT count (*) FROM ' + @SRCminusTRGTableName + ''

		DELETE
		FROM @TempCount

		INSERT INTO @TempCount
		EXEC (@sqlText);

		SET @SOURCE_CNT = (
				SELECT *
				FROM @TempCount
				);

		/*  ----  Target SQL Minus Source SQL ----  */
		DELETE
		FROM @TempCount -- Clear the TempCount table 

		SET @TRGminusSRCTableName = NULL -- Clear the temp variable
		/* Drop output table if already existing */
		SET @TRGminusSRCTableName = @TargetTable + '_EXCEPT_' + @SourceTable
		SET @sqlText = N' DROP TABLE IF EXISTS ' + @TRGminusSRCTableName + ''

		EXEC (@sqlText);

		/* SQL to store the result of EXCEPT statement */
		SET @sqlText = N' 
SELECT * INTO ' + @TRGminusSRCTableName + ' FROM
(
SELECT ' + @ColumnNameListTarget + ' FROM ' + @TargetTable + ' 
EXCEPT
SELECT ' + @ColumnNameListSource + ' FROM ' + @SourceTable + '  
) TRGminSRC'

		EXEC (@sqlText);

		/* SQL to count the mismatched records */
		SET @sqlText = N' SELECT count (*) FROM ' + @TRGminusSRCTableName + ''

		DELETE
		FROM @TempCount

		INSERT INTO @TempCount
		EXEC (@sqlText);

		SET @TARGET_CNT = (
				SELECT *
				FROM @TempCount
				);

		DELETE
		FROM @TempCount

		/* Compare source and target counts and update the status accordingly */
		IF @SOURCE_CNT > 0
			OR @TARGET_CNT > 0
			SET @FINAL_STATUS = 'FAILED'
		ELSE
			SET @FINAL_STATUS = 'PASSED'

		/* Status Description*/
		IF @FINAL_STATUS = 'FAILED'
			AND @SOURCE_CNT > 0
			AND @TARGET_CNT = 0
			SET @STATUS_DESCRIPTION = 'Table ''' + @SRCminusTRGTableName + ''' will show mismatched records'
		ELSE IF @FINAL_STATUS = 'FAILED'
			AND @TARGET_CNT > 0
			AND @SOURCE_CNT = 0
			SET @STATUS_DESCRIPTION = 'Table ''' + @TRGminusSRCTableName + ''' will show mismatched records'
		ELSE IF @FINAL_STATUS = 'FAILED'
			AND @TARGET_CNT > 0
			AND @SOURCE_CNT > 0
			SET @STATUS_DESCRIPTION = 'Table ''' + @SRCminusTRGTableName + ''' and Table ''' + @TRGminusSRCTableName + ''' will show mismatched records'
		ELSE
			SET @STATUS_DESCRIPTION = 'Source and target table are complete match'

		/* Write results into output table */
		INSERT INTO SP_Utility_Ingestion_Compare_OUTPUT (
			HEALTHPLAN
			,FILENAME
			,SOURCETABLENAME
			,TARGETTABLENAME
			,SRC_RECORD_CNT
			,TRG_RECORD_CNT
			,SOURCE_Minus_TARGET
			,TARGET_Minus_SOURCE
			,STATUS
			,STATUS_DESC
			)
		VALUES (
			@PlanName
			,@FileNM
			,@SourceTable
			,@TargetTable
			,@SOURCERECORD_CNT
			,@TARGETRECORD_CNT
			,@SOURCE_CNT
			,@TARGET_CNT
			,@FINAL_STATUS
			,@STATUS_DESCRIPTION
			)

		/* ----------------------------- End of One to One mapping comparison between Source and Target Table---------------------------------  */
		SET @s = @s + 1;-- incrementing the scenario count
	END;-- end of While Loop for 'TestScenario' list

	/* ----------------------------- End of Code---------------------------------  */
	SELECT *
	FROM SP_Utility_Ingestion_Compare_OUTPUT;
END

