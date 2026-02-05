SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetTaskMasterSchedulesCount]') AND type IN (N'P', N'PC'))
BEGIN
    EXEC('CREATE PROCEDURE [dbo].[sp_GetTaskMasterSchedulesCount]
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
        @Manager NVARCHAR(100) = ''''
    AS BEGIN SET NOCOUNT ON; END')
END
GO

ALTER PROCEDURE [dbo].[sp_GetTaskMasterSchedulesCount]
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
    @Manager NVARCHAR(100) = ''
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

    SELECT COUNT(*) AS TotalCount
    FROM TaskMasterInspectionSchedule tms
    INNER JOIN TaskMasterTask tmt ON tms.task_id = tmt.id
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
        AND (@ActiveAssetsOnly = 0 OR 
             (tms.asset_type = 'tank' AND EXISTS (SELECT 1 FROM AtmTank WHERE id = tms.tag_id AND active = 1)) OR
             (tms.asset_type = 'piping' AND EXISTS (SELECT 1 FROM Piping WHERE id = tms.tag_id AND active = 1)) OR
             (tms.asset_type = 'pipeline' AND EXISTS (SELECT 1 FROM Pipeline WHERE id = tms.tag_id AND active = 1)) OR
             (tms.asset_type = 'pressure-vessel' AND EXISTS (SELECT 1 FROM PressureVessel WHERE id = tms.tag_id AND active = 1)) OR
             (tms.asset_type = 'psv' AND EXISTS (SELECT 1 FROM Psv WHERE id = tms.tag_id AND active = 1)))
        AND (@ShowNonPsmAssets = 1 OR 
             (tms.asset_type = 'tank' AND EXISTS (SELECT 1 FROM AtmTank WHERE id = tms.tag_id AND psm = 1)) OR
             (tms.asset_type = 'piping' AND EXISTS (SELECT 1 FROM Piping WHERE id = tms.tag_id AND psm = 1)) OR
             (tms.asset_type = 'pipeline' AND EXISTS (SELECT 1 FROM Pipeline WHERE id = tms.tag_id AND psm = 1)) OR
             (tms.asset_type = 'pressure-vessel' AND EXISTS (SELECT 1 FROM PressureVessel WHERE id = tms.tag_id AND psm = 1)) OR
             (tms.asset_type = 'psv' AND EXISTS (SELECT 1 FROM Psv WHERE id = tms.tag_id AND psm = 1)));
END;
GO
