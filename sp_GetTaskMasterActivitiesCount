IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetTaskMasterActivitiesCount]') AND type in (N'P', N'PC'))
BEGIN
    EXEC('CREATE PROCEDURE [dbo].[sp_GetTaskMasterActivitiesCount]
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
        @CompletedBy NVARCHAR(100) = ''''
    AS BEGIN SET NOCOUNT ON; END')
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_GetTaskMasterActivitiesCount]
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
    @CompletedBy NVARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;

    -- Parse asset types into temp table
    DECLARE @AssetTypesList TABLE (AssetType NVARCHAR(50));
    INSERT INTO @AssetTypesList (AssetType)
    SELECT TRIM(value) FROM STRING_SPLIT(@AssetTypes, ',');

    -- Parse tag IDs if allTags = 0
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

    -- Count query without unnecessary joins and eager loading
    SELECT COUNT(*) AS TotalCount
    FROM TaskMasterActivity tma
    INNER JOIN TaskMasterTask tmt ON tma.task_id = tmt.id
    INNER JOIN AssetUnit au ON tma.unit_id = au.id
    LEFT JOIN CompanyLevel cl1 ON au.parent_level_id = cl1.id
    LEFT JOIN CompanyLevel cl2 ON cl1.parent_level_id = cl2.id
    LEFT JOIN CompanyLevel cl3 ON cl2.parent_level_id = cl3.id
    WHERE 
        -- Asset type filter
        tmt.asset_type IN (SELECT AssetType FROM @AssetTypesList)
        -- Task name filter
        AND (@TaskName IS NULL OR tmt.task_name = @TaskName)
        -- Thickness task filter
        AND (@ThicknessTask = '' OR 
             (@ThicknessTask = 'yes' AND tmt.thickness_task = 1) OR 
             (@ThicknessTask = 'no' AND tmt.thickness_task = 0))
        -- Completed date filters
        AND (@CompletedDateFrom IS NULL OR tma.completed_date >= CAST(@CompletedDateFrom AS DATE))
        AND (@CompletedDateTo IS NULL OR tma.completed_date <= CAST(@CompletedDateTo AS DATE))
        -- Completed by filter
        AND (@CompletedBy = '' OR tma.completed_by LIKE '%' + @CompletedBy + '%')
        -- Unit filter
        AND (@UnitId IS NULL OR tma.unit_id = @UnitId)
        -- Company Level filter (supports hierarchy)
        AND (
            @UnitId IS NOT NULL
            OR @CompanyLevelId IS NULL
            OR @CompanyLevelId IN (au.parent_level_id, cl1.id, cl2.id, cl3.id)
        )
        -- Active units filter
        AND (@ActiveUnitsOnly = 0 OR au.active = 1)
        -- Manager filter
        AND (@Manager = '' OR au.manager = @Manager)
        -- Tag filtering (if allTags = 0)
        AND (@AllTags = 1 OR 
             (tmt.asset_type = 'tank' AND tma.tag_id IN (SELECT Id FROM @TankIdsList)) OR
             (tmt.asset_type = 'piping' AND tma.tag_id IN (SELECT Id FROM @PipingIdsList)) OR
             (tmt.asset_type = 'pipeline' AND tma.tag_id IN (SELECT Id FROM @PipelineIdsList)) OR
             (tmt.asset_type = 'pressure-vessel' AND tma.tag_id IN (SELECT Id FROM @PressureVesselIdsList)) OR
             (tmt.asset_type = 'psv' AND tma.tag_id IN (SELECT Id FROM @PsvIdsList)))
        -- Asset-specific filters
        AND (@ActiveAssetsOnly = 0 OR 
             (tmt.asset_type = 'tank' AND EXISTS (SELECT 1 FROM AtmTank WHERE id = tma.tag_id AND active = 1)) OR
             (tmt.asset_type = 'piping' AND EXISTS (SELECT 1 FROM Piping WHERE id = tma.tag_id AND active = 1)) OR
             (tmt.asset_type = 'pipeline' AND EXISTS (SELECT 1 FROM Pipeline WHERE id = tma.tag_id AND active = 1)) OR
             (tmt.asset_type = 'pressure-vessel' AND EXISTS (SELECT 1 FROM PressureVessel WHERE id = tma.tag_id AND active = 1)) OR
             (tmt.asset_type = 'psv' AND EXISTS (SELECT 1 FROM Psv WHERE id = tma.tag_id AND active = 1)))
        AND (@ShowNonPsmAssets = 1 OR 
             (tmt.asset_type = 'tank' AND EXISTS (SELECT 1 FROM AtmTank WHERE id = tma.tag_id AND psm = 1)) OR
             (tmt.asset_type = 'piping' AND EXISTS (SELECT 1 FROM Piping WHERE id = tma.tag_id AND psm = 1)) OR
             (tmt.asset_type = 'pipeline' AND EXISTS (SELECT 1 FROM Pipeline WHERE id = tma.tag_id AND psm = 1)) OR
             (tmt.asset_type = 'pressure-vessel' AND EXISTS (SELECT 1 FROM PressureVessel WHERE id = tma.tag_id AND psm = 1)) OR
             (tmt.asset_type = 'psv' AND EXISTS (SELECT 1 FROM Psv WHERE id = tma.tag_id AND psm = 1)));

END;
GO