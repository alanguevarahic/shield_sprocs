GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetRecommendationsCount]') AND type IN (N'P', N'PC'))
BEGIN
    EXEC('CREATE PROCEDURE [dbo].[sp_GetRecommendationsCount]
        @UnitId INT = NULL,
        @CompanyLevelId INT = NULL,
        @AssetTypes NVARCHAR(MAX),
        @TaskName NVARCHAR(100) = NULL,
        @TargetDateFrom DATETIME = NULL,
        @TargetDateTo DATETIME = NULL,
        @CompletionDateFrom DATETIME = NULL,
        @CompletionDateTo DATETIME = NULL,
        @Scorecards NVARCHAR(MAX) = '''',
        @PriorityIds NVARCHAR(MAX) = '''',
        @AllTags BIT = 1,
        @TankIds NVARCHAR(MAX) = '''',
        @PipingIds NVARCHAR(MAX) = '''',
        @PipelineIds NVARCHAR(MAX) = '''',
        @PressureVesselIds NVARCHAR(MAX) = '''',
        @PsvIds NVARCHAR(MAX) = '''',
        @ActiveAssetsOnly BIT = 0,
        @ActiveUnitsOnly BIT = 0,
        @ShowNonPsmAssets BIT = 1,
        @Manager NVARCHAR(100) = ''''
    AS BEGIN SET NOCOUNT ON; END')
END
GO

ALTER PROCEDURE [dbo].[sp_GetRecommendationsCount]
    @UnitId INT = NULL,
    @CompanyLevelId INT = NULL,
    @AssetTypes NVARCHAR(MAX),
    @TaskName NVARCHAR(100) = NULL,
    @TargetDateFrom DATETIME = NULL,
    @TargetDateTo DATETIME = NULL,
    @CompletionDateFrom DATETIME = NULL,
    @CompletionDateTo DATETIME = NULL,
    @Scorecards NVARCHAR(MAX) = '',
    @PriorityIds NVARCHAR(MAX) = '',
    @AllTags BIT = 1,
    @TankIds NVARCHAR(MAX) = '',
    @PipingIds NVARCHAR(MAX) = '',
    @PipelineIds NVARCHAR(MAX) = '',
    @PressureVesselIds NVARCHAR(MAX) = '',
    @PsvIds NVARCHAR(MAX) = '',
    @ActiveAssetsOnly BIT = 0,
    @ActiveUnitsOnly BIT = 0,
    @ShowNonPsmAssets BIT = 1,
    @Manager NVARCHAR(100) = ''
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
    DECLARE @ScorecardsList TABLE (ScoreCard NVARCHAR(50));
    DECLARE @PriorityIdsList TABLE (Id INT);

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

    IF LEN(@Scorecards) > 0
        INSERT INTO @ScorecardsList (ScoreCard) SELECT TRIM(value) FROM STRING_SPLIT(@Scorecards, ',');
    IF LEN(@PriorityIds) > 0
        INSERT INTO @PriorityIdsList (Id) SELECT CAST(value AS INT) FROM STRING_SPLIT(@PriorityIds, ',');

    SELECT COUNT(*) AS TotalCount
    FROM Recommendation r
    INNER JOIN TaskMasterActivity tma ON r.activity_id = tma.id
    INNER JOIN TaskMasterTask tmt ON tma.task_id = tmt.id
    INNER JOIN AssetUnit au ON r.unit_id = au.id
    LEFT JOIN CompanyLevel cl1 ON au.parent_level_id = cl1.id
    LEFT JOIN CompanyLevel cl2 ON cl1.parent_level_id = cl2.id
    LEFT JOIN CompanyLevel cl3 ON cl2.parent_level_id = cl3.id
    WHERE 
        tmt.asset_type IN (SELECT AssetType FROM @AssetTypesList)
        AND (@TaskName IS NULL OR tmt.task_name = @TaskName)
        AND (@TargetDateFrom IS NULL OR r.target_date >= CAST(@TargetDateFrom AS DATE))
        AND (@TargetDateTo IS NULL OR r.target_date <= CAST(@TargetDateTo AS DATE))
        AND (@CompletionDateFrom IS NULL OR r.completion_date >= CAST(@CompletionDateFrom AS DATE))
        AND (@CompletionDateTo IS NULL OR r.completion_date <= CAST(@CompletionDateTo AS DATE))
        AND (NOT EXISTS (SELECT 1 FROM @ScorecardsList) OR EXISTS (SELECT 1 FROM RecommendationCondition rc WHERE rc.id = r.condition_id AND rc.score_card IN (SELECT ScoreCard FROM @ScorecardsList)))
        AND (NOT EXISTS (SELECT 1 FROM @PriorityIdsList) OR r.priority_id IN (SELECT Id FROM @PriorityIdsList))
        AND (@UnitId IS NULL OR r.unit_id = @UnitId)
        AND (
            @UnitId IS NOT NULL
            OR @CompanyLevelId IS NULL
            OR @CompanyLevelId IN (au.parent_level_id, cl1.id, cl2.id, cl3.id)
        )
        AND (@ActiveUnitsOnly = 0 OR au.active = 1)
        AND (@Manager = '' OR au.manager = @Manager)
        AND (@AllTags = 1 OR 
             (tmt.asset_type = 'tank' AND r.tag_id IN (SELECT Id FROM @TankIdsList)) OR
             (tmt.asset_type = 'piping' AND r.tag_id IN (SELECT Id FROM @PipingIdsList)) OR
             (tmt.asset_type = 'pipeline' AND r.tag_id IN (SELECT Id FROM @PipelineIdsList)) OR
             (tmt.asset_type = 'pressure-vessel' AND r.tag_id IN (SELECT Id FROM @PressureVesselIdsList)) OR
             (tmt.asset_type = 'psv' AND r.tag_id IN (SELECT Id FROM @PsvIdsList)))
        AND (@ActiveAssetsOnly = 0 OR 
             (tmt.asset_type = 'tank' AND EXISTS (SELECT 1 FROM AtmTank WHERE id = r.tag_id AND active = 1)) OR
             (tmt.asset_type = 'piping' AND EXISTS (SELECT 1 FROM Piping WHERE id = r.tag_id AND active = 1)) OR
             (tmt.asset_type = 'pipeline' AND EXISTS (SELECT 1 FROM Pipeline WHERE id = r.tag_id AND active = 1)) OR
             (tmt.asset_type = 'pressure-vessel' AND EXISTS (SELECT 1 FROM PressureVessel WHERE id = r.tag_id AND active = 1)) OR
             (tmt.asset_type = 'psv' AND EXISTS (SELECT 1 FROM Psv WHERE id = r.tag_id AND active = 1)))
        AND (@ShowNonPsmAssets = 1 OR 
             (tmt.asset_type = 'tank' AND EXISTS (SELECT 1 FROM AtmTank WHERE id = r.tag_id AND psm = 1)) OR
             (tmt.asset_type = 'piping' AND EXISTS (SELECT 1 FROM Piping WHERE id = r.tag_id AND psm = 1)) OR
             (tmt.asset_type = 'pipeline' AND EXISTS (SELECT 1 FROM Pipeline WHERE id = r.tag_id AND psm = 1)) OR
             (tmt.asset_type = 'pressure-vessel' AND EXISTS (SELECT 1 FROM PressureVessel WHERE id = r.tag_id AND psm = 1)) OR
             (tmt.asset_type = 'psv' AND EXISTS (SELECT 1 FROM Psv WHERE id = r.tag_id AND psm = 1)));
END;
GO
