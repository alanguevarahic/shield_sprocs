SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetTaskMasterActivitiesTemp]') AND type IN (N'P', N'PC'))
BEGIN
    EXEC('CREATE PROCEDURE [dbo].[sp_GetTaskMasterActivitiesTemp]
        @UnitId INT = NULL,
        @CompanyLevelId INT = NULL,
        @AssetTypes NVARCHAR(MAX),
        @TaskName NVARCHAR(100) = NULL,
        @CompletedDateFrom DATETIME = NULL,
        @CompletedDateTo DATETIME = NULL,
        @AllTags BIT = 1,
        @TankIds NVARCHAR(MAX) = '''',
        @PipingIds NVARCHAR(MAX) = '''',
        @PipelineIds NVARCHAR(MAX) = '''',
        @PressureVesselIds NVARCHAR(MAX) = '''',
        @PsvIds NVARCHAR(MAX) = '''',
        @ThicknessTask NVARCHAR(10) = '''',
        @ActiveAssetsOnly BIT = 0,
        @ActiveUnitsOnly BIT = 0,
        @ShowNonPsmAssets BIT = 1,
        @Manager NVARCHAR(100) = '''',
        @CompletedBy NVARCHAR(100) = '''',
        @Page INT = 1,
        @PageSize INT = 50,
        @SortBy NVARCHAR(50) = ''unit_id'',
        @IsDesc BIT = 0,
        @CountOnly BIT = 0
    AS BEGIN SET NOCOUNT ON; END')
END
GO

ALTER PROCEDURE [dbo].[sp_GetTaskMasterActivitiesTemp]
    @UnitId INT = NULL,
    @CompanyLevelId INT = NULL,
    @AssetTypes NVARCHAR(MAX),
    @TaskName NVARCHAR(100) = NULL,
    @CompletedDateFrom DATETIME = NULL,
    @CompletedDateTo DATETIME = NULL,
    @AllTags BIT = 1,
    @TankIds NVARCHAR(MAX) = '',
    @PipingIds NVARCHAR(MAX) = '',
    @PipelineIds NVARCHAR(MAX) = '',
    @PressureVesselIds NVARCHAR(MAX) = '',
    @PsvIds NVARCHAR(MAX) = '',
    @ThicknessTask NVARCHAR(10) = '',
    @ActiveAssetsOnly BIT = 0,
    @ActiveUnitsOnly BIT = 0,
    @ShowNonPsmAssets BIT = 1,
    @Manager NVARCHAR(100) = '',
    @CompletedBy NVARCHAR(100) = '',
    @Page INT = 1,
    @PageSize INT = 50,
    @SortBy NVARCHAR(50) = 'unit_id',
    @IsDesc BIT = 0,
    @CountOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @Page < 1 SET @Page = 1;

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

    ;WITH FilteredActivities AS (
        SELECT 
            tma.id,
            tma.unit_id,
            tma.tag,
            ISNULL(tma.tag_id, 0) AS tag_id,
            tma.task_id,
            tma.method_id,
            tma.completed_date,
            tma.completed_by,
            tma.approved_date,
            tma.approved_by,
            tma.updated_date,
            tma.updated_by,
            tma.advanced_tank,
            tmt.task_name,
            tmt.asset_type,
            tmt.thickness_task,
            tmm.method_name,
            tmm.id AS method_db_id,
            au.unit_name,
            au.unit_code,
            au.active AS unit_active,
            au.manager AS unit_manager,
            au.parent_level_id AS unit_parent_level_id,
            CASE tmt.asset_type
                WHEN 'tank' THEN (SELECT TOP 1 active FROM AtmTank WHERE (id = tma.tag_id OR tag = tma.tag) AND unit_id = tma.unit_id)
                WHEN 'piping' THEN (SELECT TOP 1 active FROM Piping WHERE (id = tma.tag_id OR tag = tma.tag) AND unit_id = tma.unit_id)
                WHEN 'pipeline' THEN (SELECT TOP 1 active FROM Pipeline WHERE (id = tma.tag_id OR tag = tma.tag) AND unit_id = tma.unit_id)
                WHEN 'pressure-vessel' THEN (SELECT TOP 1 active FROM PressureVessel WHERE (id = tma.tag_id OR tag = tma.tag) AND unit_id = tma.unit_id)
                WHEN 'psv' THEN (SELECT TOP 1 active FROM Psv WHERE (id = tma.tag_id OR tag = tma.tag) AND unit_id = tma.unit_id)
            END AS asset_active,
            CASE tmt.asset_type
                WHEN 'tank' THEN (SELECT TOP 1 psm FROM AtmTank WHERE (id = tma.tag_id OR tag = tma.tag) AND unit_id = tma.unit_id)
                WHEN 'piping' THEN (SELECT TOP 1 psm FROM Piping WHERE (id = tma.tag_id OR tag = tma.tag) AND unit_id = tma.unit_id)
                WHEN 'pipeline' THEN (SELECT TOP 1 psm FROM Pipeline WHERE (id = tma.tag_id OR tag = tma.tag) AND unit_id = tma.unit_id)
                WHEN 'pressure-vessel' THEN (SELECT TOP 1 psm FROM PressureVessel WHERE (id = tma.tag_id OR tag = tma.tag) AND unit_id = tma.unit_id)
                WHEN 'psv' THEN (SELECT TOP 1 psm FROM Psv WHERE (id = tma.tag_id OR tag = tma.tag) AND unit_id = tma.unit_id)
            END AS asset_psm
        FROM TaskMasterActivityTemp tma
        INNER JOIN TaskMasterTask tmt ON tma.task_id = tmt.id
        LEFT JOIN TaskMasterMethod tmm ON tma.method_id = tmm.id
        INNER JOIN AssetUnit au ON tma.unit_id = au.id
        LEFT JOIN CompanyLevel cl1 ON au.parent_level_id = cl1.id
        LEFT JOIN CompanyLevel cl2 ON cl1.parent_level_id = cl2.id
        LEFT JOIN CompanyLevel cl3 ON cl2.parent_level_id = cl3.id
        WHERE 
            tmt.asset_type IN (SELECT AssetType FROM @AssetTypesList)
            AND (@TaskName IS NULL OR tmt.task_name = @TaskName)
            AND (@ThicknessTask = '' OR 
                 (@ThicknessTask = 'yes' AND tmt.thickness_task = 1) OR 
                 (@ThicknessTask = 'no' AND tmt.thickness_task = 0))
            AND (@CompletedDateFrom IS NULL OR tma.completed_date >= CAST(@CompletedDateFrom AS DATE))
            AND (@CompletedDateTo IS NULL OR tma.completed_date <= CAST(@CompletedDateTo AS DATE))
            AND (@CompletedBy = '' OR tma.completed_by LIKE '%' + @CompletedBy + '%')
            AND (@UnitId IS NULL OR tma.unit_id = @UnitId)
            AND (
                @UnitId IS NOT NULL
                OR @CompanyLevelId IS NULL
                OR @CompanyLevelId IN (au.parent_level_id, cl1.id, cl2.id, cl3.id)
            )
            AND (@ActiveUnitsOnly = 0 OR au.active = 1)
            AND (@Manager = '' OR au.manager = @Manager)
            AND (@AllTags = 1 OR 
                 (tmt.asset_type = 'tank' AND (tma.tag_id IN (SELECT Id FROM @TankIdsList) OR (tma.tag_id IS NULL AND tma.tag IN (SELECT tag FROM AtmTank WHERE id IN (SELECT Id FROM @TankIdsList))))) OR
                 (tmt.asset_type = 'piping' AND (tma.tag_id IN (SELECT Id FROM @PipingIdsList) OR (tma.tag_id IS NULL AND tma.tag IN (SELECT tag FROM Piping WHERE id IN (SELECT Id FROM @PipingIdsList))))) OR
                 (tmt.asset_type = 'pipeline' AND (tma.tag_id IN (SELECT Id FROM @PipelineIdsList) OR (tma.tag_id IS NULL AND tma.tag IN (SELECT tag FROM Pipeline WHERE id IN (SELECT Id FROM @PipelineIdsList))))) OR
                 (tmt.asset_type = 'pressure-vessel' AND (tma.tag_id IN (SELECT Id FROM @PressureVesselIdsList) OR (tma.tag_id IS NULL AND tma.tag IN (SELECT tag FROM PressureVessel WHERE id IN (SELECT Id FROM @PressureVesselIdsList))))) OR
                 (tmt.asset_type = 'psv' AND (tma.tag_id IN (SELECT Id FROM @PsvIdsList) OR (tma.tag_id IS NULL AND tma.tag IN (SELECT tag FROM Psv WHERE id IN (SELECT Id FROM @PsvIdsList))))))
    )
    SELECT 
        id,
        unit_id,
        tag,
        tag_id,
        task_id,
        method_id,
        completed_date,
        completed_by,
        approved_date,
        approved_by,
        updated_date,
        updated_by,
        advanced_tank,
        task_name,
        asset_type,
        thickness_task,
        method_name,
        method_db_id,
        unit_name,
        unit_code,
        unit_active,
        unit_manager,
        unit_parent_level_id
    FROM FilteredActivities
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
        CASE WHEN @SortBy = 'approved_date' AND @IsDesc = 0 THEN approved_date END ASC,
        CASE WHEN @SortBy = 'approved_date' AND @IsDesc = 1 THEN approved_date END DESC,
        CASE WHEN @SortBy = 'approved_by' AND @IsDesc = 0 THEN approved_by END ASC,
        CASE WHEN @SortBy = 'approved_by' AND @IsDesc = 1 THEN approved_by END DESC,
        CASE WHEN @SortBy = 'completed_date' AND @IsDesc = 0 THEN completed_date END ASC,
        CASE WHEN @SortBy = 'completed_date' AND @IsDesc = 1 THEN completed_date END DESC,
        CASE WHEN @SortBy = 'completed_by' AND @IsDesc = 0 THEN completed_by END ASC,
        CASE WHEN @SortBy = 'completed_by' AND @IsDesc = 1 THEN completed_by END DESC,
        unit_name ASC,
        tag ASC
    OFFSET ((@Page - 1) * @PageSize) ROWS
    FETCH NEXT CASE WHEN @CountOnly = 1 THEN 2147483647 ELSE @PageSize END ROWS ONLY;
END;
GO
