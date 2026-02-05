SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetTaskMasterSchedules]') AND type IN (N'P', N'PC'))
BEGIN
    EXEC('CREATE PROCEDURE [dbo].[sp_GetTaskMasterSchedules]
        @UnitId INT = NULL,
        @CompanyLevelId INT = NULL,
        @AssetTypes NVARCHAR(MAX),
        @TaskName NVARCHAR(100) = NULL,
        @NextDateFrom DATETIME = NULL,
        @NextDateTo DATETIME = NULL,
        @LastDateFrom DATETIME = NULL,
        @LastDateTo DATETIME = NULL,
        @AllTags BIT = 1,
        @TankIds NVARCHAR(MAX) = '''',
        @PipingIds NVARCHAR(MAX) = '''',
        @PipelineIds NVARCHAR(MAX) = '''',
        @PressureVesselIds NVARCHAR(MAX) = '''',
        @PsvIds NVARCHAR(MAX) = '''',
        @ThicknessTask NVARCHAR(10) = '''',
        @RbiTask NVARCHAR(10) = '''',
        @ActiveAssetsOnly BIT = 0,
        @ActiveUnitsOnly BIT = 0,
        @ShowNonPsmAssets BIT = 1,
        @ActiveSchedulesOnly BIT = 0,
        @Manager NVARCHAR(100) = '''',
        @Page INT = 1,
        @PageSize INT = 50,
        @SortBy NVARCHAR(50) = ''unit_id'',
        @IsDesc BIT = 0,
        @CountOnly BIT = 0
    AS BEGIN SET NOCOUNT ON; END')
END
GO

ALTER PROCEDURE [dbo].[sp_GetTaskMasterSchedules]
    @UnitId INT = NULL,
    @CompanyLevelId INT = NULL,
    @AssetTypes NVARCHAR(MAX),
    @TaskName NVARCHAR(100) = NULL,
    @NextDateFrom DATETIME = NULL,
    @NextDateTo DATETIME = NULL,
    @LastDateFrom DATETIME = NULL,
    @LastDateTo DATETIME = NULL,
    @AllTags BIT = 1,
    @TankIds NVARCHAR(MAX) = '',
    @PipingIds NVARCHAR(MAX) = '',
    @PipelineIds NVARCHAR(MAX) = '',
    @PressureVesselIds NVARCHAR(MAX) = '',
    @PsvIds NVARCHAR(MAX) = '',
    @ThicknessTask NVARCHAR(10) = '',
    @RbiTask NVARCHAR(10) = '',
    @ActiveAssetsOnly BIT = 0,
    @ActiveUnitsOnly BIT = 0,
    @ShowNonPsmAssets BIT = 1,
    @ActiveSchedulesOnly BIT = 0,
    @Manager NVARCHAR(100) = '',
    @Page INT = 1,
    @PageSize INT = 50,
    @SortBy NVARCHAR(50) = 'unit_id',
    @IsDesc BIT = 0,
    @CountOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AssetTypesList TABLE (AssetType NVARCHAR(50));
    INSERT INTO @AssetTypesList (AssetType)
    SELECT TRIM(value) FROM STRING_SPLIT(@AssetTypes, ',');

    DECLARE @TankIdsList TABLE (Id INT);
    DECLARE @PipingIdsList TABLE (Id INT);
    DECLARE @PipelineIdsList TABLE (Id INT);
    DECLARE @PressureVesselIdsList TABLE (Id INT);
    DECLARE @PsvIdsList TABLE (Id INT);

    IF @AllTags = 0
    BEGIN
        IF LEN(@TankIds) > 0
            INSERT INTO @TankIdsList (Id) SELECT CAST(value AS INT) FROM STRING_SPLIT(@TankIds, ',');
        IF LEN(@PipingIds) > 0
            INSERT INTO @PipingIdsList (Id) SELECT CAST(value AS INT) FROM STRING_SPLIT(@PipingIds, ',');
        IF LEN(@PipelineIds) > 0
            INSERT INTO @PipelineIdsList (Id) SELECT CAST(value AS INT) FROM STRING_SPLIT(@PipelineIds, ',');
        IF LEN(@PressureVesselIds) > 0
            INSERT INTO @PressureVesselIdsList (Id) SELECT CAST(value AS INT) FROM STRING_SPLIT(@PressureVesselIds, ',');
        IF LEN(@PsvIds) > 0
            INSERT INTO @PsvIdsList (Id) SELECT CAST(value AS INT) FROM STRING_SPLIT(@PsvIds, ',');
    END

    ;WITH FilteredSchedules AS (
        SELECT 
            tms.id,
            tms.tag,
            tms.tag_id,
            tms.unit_id,
            tms.asset_type,
            tms.manual_task,
            tms.rule_id,
            tms.method_id,
            tms.task_id,
            tms.last_done_date,
            tms.next_done_date,
            tms.interval,
            tms.comments,
            tms.rbi_task,
            tms.active,
            tms.created_by,
            tms.created_date,
            tms.updated_by,
            tms.updated_date,
            tmt.task_name,
            tmt.thickness_task,
            tmm.method_name,
            tmm.id AS method_db_id,
            au.unit_name,
            au.unit_code,
            au.active AS unit_active,
            au.manager AS unit_manager,
            au.parent_level_id AS unit_parent_level_id,
            tmr.conditional_interval AS rule_conditional_interval,
            tmr.next_cml_due_date AS rule_next_cml_due_date,
            CASE tms.asset_type
                WHEN 'tank' THEN (SELECT active FROM AtmTank WHERE id = tms.tag_id)
                WHEN 'piping' THEN (SELECT active FROM Piping WHERE id = tms.tag_id)
                WHEN 'pipeline' THEN (SELECT active FROM Pipeline WHERE id = tms.tag_id)
                WHEN 'pressure-vessel' THEN (SELECT active FROM PressureVessel WHERE id = tms.tag_id)
                WHEN 'psv' THEN (SELECT active FROM Psv WHERE id = tms.tag_id)
            END AS asset_active,
            CASE tms.asset_type
                WHEN 'tank' THEN (SELECT psm FROM AtmTank WHERE id = tms.tag_id)
                WHEN 'piping' THEN (SELECT psm FROM Piping WHERE id = tms.tag_id)
                WHEN 'pipeline' THEN (SELECT psm FROM Pipeline WHERE id = tms.tag_id)
                WHEN 'pressure-vessel' THEN (SELECT psm FROM PressureVessel WHERE id = tms.tag_id)
                WHEN 'psv' THEN (SELECT psm FROM Psv WHERE id = tms.tag_id)
            END AS asset_psm
        FROM TaskMasterInspectionSchedule tms
        INNER JOIN TaskMasterTask tmt ON tms.task_id = tmt.id
        LEFT JOIN TaskMasterRule tmr ON tms.rule_id = tmr.id
        LEFT JOIN TaskMasterMethod tmm ON tms.method_id = tmm.id
        INNER JOIN AssetUnit au ON tms.unit_id = au.id
        LEFT JOIN CompanyLevel cl1 ON au.parent_level_id = cl1.id
        LEFT JOIN CompanyLevel cl2 ON cl1.parent_level_id = cl2.id
        LEFT JOIN CompanyLevel cl3 ON cl2.parent_level_id = cl3.id
        WHERE 
            tms.asset_type IN (SELECT AssetType FROM @AssetTypesList)
            AND (@TaskName IS NULL OR tmt.task_name = @TaskName)
            AND (@ThicknessTask = '' OR 
                 (@ThicknessTask = 'yes' AND tmt.thickness_task = 1) OR 
                 (@ThicknessTask = 'no' AND tmt.thickness_task = 0))
            AND (@RbiTask = '' OR 
                 (@RbiTask = 'yes' AND tms.rbi_task = 1) OR 
                 (@RbiTask = 'no' AND tms.rbi_task = 0))
            AND (@NextDateFrom IS NULL OR tms.next_done_date >= CAST(@NextDateFrom AS DATE))
            AND (@NextDateTo IS NULL OR tms.next_done_date <= CAST(@NextDateTo AS DATE))
            AND (@LastDateFrom IS NULL OR tms.last_done_date >= CAST(@LastDateFrom AS DATE))
            AND (@LastDateTo IS NULL OR tms.last_done_date <= CAST(@LastDateTo AS DATE))
            AND (@UnitId IS NULL OR tms.unit_id = @UnitId)
            AND (
                @UnitId IS NOT NULL
                OR @CompanyLevelId IS NULL
                OR @CompanyLevelId IN (au.parent_level_id, cl1.id, cl2.id, cl3.id)
            )
            AND (@ActiveUnitsOnly = 0 OR au.active = 1)
            AND (@Manager = '' OR au.manager = @Manager)
            AND (@ActiveSchedulesOnly = 0 OR tms.active = 1)
            AND (@AllTags = 1 OR 
                 (tms.asset_type = 'tank' AND tms.tag_id IN (SELECT Id FROM @TankIdsList)) OR
                 (tms.asset_type = 'piping' AND tms.tag_id IN (SELECT Id FROM @PipingIdsList)) OR
                 (tms.asset_type = 'pipeline' AND tms.tag_id IN (SELECT Id FROM @PipelineIdsList)) OR
                 (tms.asset_type = 'pressure-vessel' AND tms.tag_id IN (SELECT Id FROM @PressureVesselIdsList)) OR
                 (tms.asset_type = 'psv' AND tms.tag_id IN (SELECT Id FROM @PsvIdsList)))
    )
    SELECT 
        id, tag, tag_id, unit_id, asset_type, manual_task, rule_id, method_id, task_id,
        last_done_date, next_done_date, interval, comments, rbi_task, active,
        created_by, created_date, updated_by, updated_date,
        task_name, thickness_task, method_name, method_db_id,
        unit_name, unit_code, unit_active, unit_manager, unit_parent_level_id,
        rule_conditional_interval, rule_next_cml_due_date
    FROM FilteredSchedules
    WHERE 
        (@ActiveAssetsOnly = 0 OR asset_active = 1)
        AND (@ShowNonPsmAssets = 1 OR asset_psm = 1)
    ORDER BY
        CASE WHEN @SortBy = 'unit_id' AND @IsDesc = 0 THEN unit_name END ASC,
        CASE WHEN @SortBy = 'unit_id' AND @IsDesc = 0 THEN tag END ASC,
        CASE WHEN @SortBy = 'unit_id' AND @IsDesc = 1 THEN unit_name END DESC,
        CASE WHEN @SortBy = 'unit_id' AND @IsDesc = 1 THEN tag END ASC,
        CASE WHEN @SortBy = 'tag' AND @IsDesc = 0 THEN tag END ASC,
        CASE WHEN @SortBy = 'tag' AND @IsDesc = 1 THEN tag END DESC,
        CASE WHEN @SortBy = 'task.task_name' AND @IsDesc = 0 THEN task_name END ASC,
        CASE WHEN @SortBy = 'task.task_name' AND @IsDesc = 1 THEN task_name END DESC,
        CASE WHEN @SortBy = 'method.method_name' AND @IsDesc = 0 THEN ISNULL(method_name, '') END ASC,
        CASE WHEN @SortBy = 'method.method_name' AND @IsDesc = 1 THEN ISNULL(method_name, '') END DESC,
        CASE WHEN @SortBy = 'interval' AND @IsDesc = 0 THEN interval END ASC,
        CASE WHEN @SortBy = 'interval' AND @IsDesc = 1 THEN interval END DESC,
        CASE WHEN @SortBy = 'rbi_task' AND @IsDesc = 0 THEN rbi_task END ASC,
        CASE WHEN @SortBy = 'rbi_task' AND @IsDesc = 1 THEN rbi_task END DESC,
        CASE WHEN @SortBy = 'last_done_date' AND @IsDesc = 0 THEN last_done_date END ASC,
        CASE WHEN @SortBy = 'last_done_date' AND @IsDesc = 1 THEN last_done_date END DESC,
        CASE WHEN @SortBy = 'next_done_date' AND @IsDesc = 0 THEN next_done_date END ASC,
        CASE WHEN @SortBy = 'next_done_date' AND @IsDesc = 1 THEN next_done_date END DESC,
        CASE WHEN @SortBy = 'logic' AND @IsDesc = 0 THEN 
            CASE WHEN rule_conditional_interval = 1 THEN 0 WHEN manual_task = 1 THEN 1 WHEN rule_next_cml_due_date = 1 THEN 2 ELSE 3 END END ASC,
        CASE WHEN @SortBy = 'logic' AND @IsDesc = 0 THEN unit_name END ASC,
        CASE WHEN @SortBy = 'logic' AND @IsDesc = 0 THEN tag END ASC,
        CASE WHEN @SortBy = 'logic' AND @IsDesc = 1 THEN 
            CASE WHEN rule_next_cml_due_date = 1 THEN 0 WHEN manual_task = 1 THEN 1 WHEN rule_conditional_interval = 1 THEN 2 ELSE 3 END END ASC,
        CASE WHEN @SortBy = 'logic' AND @IsDesc = 1 THEN unit_name END ASC,
        CASE WHEN @SortBy = 'logic' AND @IsDesc = 1 THEN tag END ASC,
        unit_name ASC,
        tag ASC
    OFFSET ((@Page - 1) * @PageSize) ROWS
    FETCH NEXT CASE WHEN @CountOnly = 1 THEN 2147483647 ELSE @PageSize END ROWS ONLY;
END;
GO
