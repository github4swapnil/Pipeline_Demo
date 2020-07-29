--DROP PROCEDURE LANDMARK_HUMANA_TRR

CREATE OR ALTER PROCEDURE SP_Utility_DT_DR  

AS
/* Declare all required variables and updated list of columns for @list */
DECLARE @ScenarioCount int, @SOURCE_CNT int, @TARGET_CNT int, @FINAL_STATUS nvarchar(50) , @STATUS_DESCRIPTION nvarchar (500), @DQ_REMARKS nvarchar (500),
@id INT = 1, @i INT = 1, @s INT = 1, @COL_COUNT INT ,@COLUMN_NAME nvarchar(50) , @sqlText nvarchar(max) , @VAR nvarchar(50),
@PlanName nvarchar(max), @FileNM nvarchar(max),@SourceTable nvarchar(max) = NULL ,
 @TargetTable nvarchar(max) = NULL , @TestScenarioName nvarchar(max) , @TestScenarioDetails nvarchar(max) ,  
 @Dateformatvalue nvarchar(max), @SRCTableName nvarchar(max), @TRGTableName nvarchar(max),
@SourceSQL nvarchar(max) , @TargetSQL nvarchar(max)  , @SRCMinusTRGTableName nvarchar(max),
@TRGMinusSRCTableName nvarchar(max) , @row_num INT , @SOURCERECORD_CNT INT , @TARGETRECORD_CNT INT

/* Creating table variable to store test sceanrio list */
DECLARE @testscenario TABLE(
	row_num INT NOT NULL,
    PlanName VARCHAR(MAX) NOT NULL, 
	FileNM VARCHAR(MAX) NOT NULL,
	ExecuteTest VARCHAR(MAX) NOT NULL,
	TestScenarioName VARCHAR(MAX) NOT NULL,
	SourceTable VARCHAR(MAX) ,
	TargetTable VARCHAR(MAX),
	SourceSQL VARCHAR(MAX) NOT NULL,
	TargetSQL VARCHAR(MAX) NOT NULL
	)
		
DECLARE	@TempCount TABLE (
	CNT INT NOT NULL );


BEGIN
	SET NOCOUNT ON;

/* DROP Output Result table before start of testing */
TRUNCATE TABLE SP_Utility_DT_DR_OUTPUT;


/* ----------------------------- Start of reading Scenario File---------------------------------  */

/* Read Information from Test Scenario document */
INSERT INTO @TestScenario  
SELECT ROW_NUMBER() OVER ( ORDER BY PlanName, FileNM ,SourceTable,TargetTable,TestScenarioName) row_num, * FROM SP_Utility_DT_DR_TestScenario where ExecuteTest = 'Y';

SET @ScenarioCount = (SELECT COUNT (*) from @TestScenario );

/* Store Information for each row */
WHILE @s <= @ScenarioCount
BEGIN

/* Extract Test scenario information */
SET @row_num = (SELECT row_num from @testscenario where row_num = @s );
SET @PlanName = (SELECT PlanName from @testscenario where row_num = @s );
SET @FileNM = (SELECT FileNM from @testscenario where row_num = @s );
SET @TestScenarioName = (SELECT TestScenarioName from @testscenario where row_num = @s );
SET @SourceTable = (SELECT SourceTable from @testscenario where row_num = @s );
SET @TargetTable = (SELECT TargetTable from @testscenario where row_num = @s );
SET @SourceSQL = (SELECT SourceSQL from @testscenario where row_num = @s );
SET @TargetSQL = (SELECT TargetSQL from @testscenario where row_num = @s );


 /*  ----  Source Record Count SQL ----  */
DELETE from @TempCount

SET @sqlText = N'SELECT COUNT (*) FROM ('+@SourceSQL+') SRC'

INSERT INTO @TempCount
EXEC (@sqlText);

SET @SOURCERECORD_CNT=(SELECT * FROM @TempCount);

 /*  ----  Target Record Count SQL ----  */
DELETE from @TempCount

SET @sqlText = N'SELECT COUNT (*) FROM ('+@TargetSQL+') TRG'

INSERT INTO @TempCount
EXEC (@sqlText);

SET @TARGETRECORD_CNT=(SELECT * FROM @TempCount);

/*  ----  Source SQL Minus Target SQL ----  */

DELETE from @TempCount                         -- Clear the TempCount table 
SET @SRCMinusTRGTableName = NULL               -- Clear the temp variable

/* Drop output table if already existing */
SET @SRCMinusTRGTableName = @SourceTable + '_'+ @TargetTable + '_' + cast(@row_num AS NVARCHAR)
SET @sqlText = N' DROP TABLE IF EXISTS '+@SRCMinusTRGTableName+''

EXEC (@sqlText);  

/* SQL to store the result of EXCEPT statement */
SET @sqlText = N' 
SELECT * INTO '+ @SRCMinusTRGTableName + ' FROM
( 
'+@SourceSQL+' EXCEPT '+ @TargetSQL + '  
) SRCminTRG'

EXEC (@sqlText);

/* SQL to count the mismatched records */
SET @sqlText = N' SELECT count (*) FROM '+@SRCminusTRGTableName+''

DELETE from @TempCount  
INSERT INTO @TempCount
EXEC (@sqlText);

SET @SOURCE_CNT=(SELECT * FROM @TempCount);

/*  ----  Target SQL Minus Source SQL ----  */

DELETE from @TempCount                         -- Clear the TempCount table 
SET @TRGMinusSRCTableName = NULL               -- Clear the temp variable

/* Drop output table if already existing */
SET @TRGMinusSRCTableName = @TargetTable + '_'+ @SourceTable + '_' + cast(@row_num AS NVARCHAR)
SET @sqlText = N' DROP TABLE IF EXISTS '+@TRGMinusSRCTableName+''

EXEC (@sqlText);  

/* SQL to store the result of EXCEPT statement */
SET @sqlText = N' 
SELECT * INTO '+ @TRGMinusSRCTableName + ' FROM
( 
'+@TargetSQL+' EXCEPT '+ @SourceSQL + '  
) TRGminSRC'

EXEC (@sqlText);

/* SQL to count the mismatched records */
SET @sqlText = N' SELECT count (*) FROM '+@TRGMinusSRCTableName+''

DELETE from @TempCount  
INSERT INTO @TempCount
EXEC (@sqlText);

SET @TARGET_CNT=(SELECT * FROM @TempCount);

  /* Compare source and target counts and update the status accordingly */

  IF @SOURCE_CNT > 0 or @TARGET_CNT > 0
  SET @FINAL_STATUS = 'FAILED'
  ELSE 
  SET @FINAL_STATUS = 'PASSED'

  /* Status Description*/

  IF @FINAL_STATUS = 'FAILED' and @SOURCE_CNT > 0 and @TARGET_CNT = 0
  SET @STATUS_DESCRIPTION = 'Table '''+@SRCminusTRGTableName+''' will show mismatched records'
  ELSE IF 
  @FINAL_STATUS = 'FAILED' and @TARGET_CNT > 0 and @SOURCE_CNT = 0
  SET @STATUS_DESCRIPTION = 'Table '''+@TRGminusSRCTableName+''' will show mismatched records'
  ELSE IF 
  @FINAL_STATUS = 'FAILED' and @TARGET_CNT > 0 and @SOURCE_CNT > 0
  SET @STATUS_DESCRIPTION = 'Table '''+@SRCminusTRGTableName+''' and Table '''+@TRGminusSRCTableName+''' will show mismatched records'
  ELSE
  SET @STATUS_DESCRIPTION = 'Source and target table are complete match'

  /* Write results into output table */
 
INSERT INTO SP_Utility_DT_DR_OUTPUT (
	[HEALTHPLAN],
	[FILENAME],
	[TESTSCENARIO],
	[SOURCETABLENAME],
	[TARGETTABLENAME],
	[SRC_RECORD_CNT],
	[TRG_RECORD_CNT],
	[SOURCE_Minus_TARGET],
	[TARGET_Minus_SOURCE],
	[STATUS],
	[STATUS_DESC]
	)
  VALUES ( @PlanName , @FileNM, @TestScenarioName, @SourceTable , @TargetTable, @SOURCERECORD_CNT, @TARGETRECORD_CNT, @SOURCE_CNT , @TARGET_CNT, @FINAL_STATUS, @STATUS_DESCRIPTION )
 

/* -----------------------------  End of DT test case---------------------------------  */

SET @s = @s + 1;    -- incrementing the scenario count

END;                -- end of While Loop for 'TestScenario' list

/* ----------------------------- End of Code---------------------------------  */

SELECT * FROM SP_Utility_DT_DR_OUTPUT;

END
GO

EXECUTE SP_Utility_DT_DR;

