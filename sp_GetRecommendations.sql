GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetRecommendations]') AND type IN (N'P', N'PC'))
BEGIN
    EXEC('CREATE PROCEDURE [dbo].[sp_GetRecommendations] AS BEGIN SET NOCOUNT ON; END')
END
GO

ALTER PROCEDURE [dbo].[sp_GetRecommendations]
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

    ;WITH FilteredRecommendations AS (
        SELECT 
            r.id,
            r.unit_id,
            r.tag,
            r.tag_id,
            r.activity_id,
            r.condition_id,
            r.priority_id,
            r.custom_description,
            r.target_date,
            r.completion_date,
            r.completed_by,
            r.recommendation_shutdown,
            r.recommendation_failure,
            r.failure_component_id,
            r.failure_type_id,
            r.lost_op_cost,
            r.lost_op_flow,
            r.SendToSAP AS send_to_sap,
            tma.completed_date AS activity_completed_date,
            tmt.task_name,
            tmt.asset_type,
            rc.condition AS condition_condition,
            rc.score_card AS condition_score_card,
            tmp.priority_name,
            ft.failure_type AS failure_type_name,
            fc.failure_component_name,
            au.unit_name,
            au.unit_code,
            au.active AS unit_active,
            au.manager AS unit_manager,
            au.parent_level_id AS unit_parent_level_id,
            CASE tmt.asset_type
                WHEN 'tank' THEN (SELECT active FROM AtmTank WHERE id = r.tag_id)
                WHEN 'piping' THEN (SELECT active FROM Piping WHERE id = r.tag_id)
                WHEN 'pipeline' THEN (SELECT active FROM Pipeline WHERE id = r.tag_id)
                WHEN 'pressure-vessel' THEN (SELECT active FROM PressureVessel WHERE id = r.tag_id)
                WHEN 'psv' THEN (SELECT active FROM Psv WHERE id = r.tag_id)
            END AS asset_active,
            CASE tmt.asset_type
                WHEN 'tank' THEN (SELECT psm FROM AtmTank WHERE id = r.tag_id)
                WHEN 'piping' THEN (SELECT psm FROM Piping WHERE id = r.tag_id)
                WHEN 'pipeline' THEN (SELECT psm FROM Pipeline WHERE id = r.tag_id)
                WHEN 'pressure-vessel' THEN (SELECT psm FROM PressureVessel WHERE id = r.tag_id)
                WHEN 'psv' THEN (SELECT psm FROM Psv WHERE id = r.tag_id)
            END AS asset_psm
        FROM Recommendation r
        INNER JOIN TaskMasterActivity tma ON r.activity_id = tma.id
        INNER JOIN TaskMasterTask tmt ON tma.task_id = tmt.id
        INNER JOIN RecommendationCondition rc ON r.condition_id = rc.id
        LEFT JOIN TaskMasterPriority tmp ON r.priority_id = tmp.id
        LEFT JOIN FailureType ft ON r.failure_type_id = ft.id
        LEFT JOIN FailureComponent fc ON r.failure_component_id = fc.id
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
            AND (NOT EXISTS (SELECT 1 FROM @ScorecardsList) OR rc.score_card IN (SELECT ScoreCard FROM @ScorecardsList))
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
    )
    SELECT 
        id, unit_id, tag, tag_id, activity_id, condition_id, priority_id,
        custom_description, target_date, completion_date, completed_by,
        recommendation_shutdown, recommendation_failure, failure_component_id, failure_type_id,
        lost_op_cost, lost_op_flow, send_to_sap,
        activity_completed_date, task_name, asset_type,
        condition_condition, condition_score_card, priority_name,
        failure_type_name, failure_component_name,
        unit_name, unit_code, unit_active, unit_manager, unit_parent_level_id
    FROM FilteredRecommendations
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
        CASE WHEN @SortBy = 'condition.condition' AND @IsDesc = 0 THEN condition_condition END ASC,
        CASE WHEN @SortBy = 'condition.condition' AND @IsDesc = 1 THEN condition_condition END DESC,
        CASE WHEN @SortBy = 'priority.priority_name' AND @IsDesc = 0 THEN priority_name END ASC,
        CASE WHEN @SortBy = 'priority.priority_name' AND @IsDesc = 1 THEN priority_name END DESC,
        CASE WHEN @SortBy = 'condition.score_card' AND @IsDesc = 0 THEN condition_score_card END ASC,
        CASE WHEN @SortBy = 'condition.score_card' AND @IsDesc = 1 THEN condition_score_card END DESC,
        CASE WHEN @SortBy = 'created_date' AND @IsDesc = 0 THEN activity_completed_date END ASC,
        CASE WHEN @SortBy = 'created_date' AND @IsDesc = 1 THEN activity_completed_date END DESC,
        CASE WHEN @SortBy = 'target_date' AND @IsDesc = 0 THEN target_date END ASC,
        CASE WHEN @SortBy = 'target_date' AND @IsDesc = 1 THEN target_date END DESC,
        CASE WHEN @SortBy = 'completion_date' AND @IsDesc = 0 THEN completion_date END ASC,
        CASE WHEN @SortBy = 'completion_date' AND @IsDesc = 1 THEN completion_date END DESC,
        unit_name ASC,
        tag ASC
    OFFSET ((@Page - 1) * @PageSize) ROWS
    FETCH NEXT CASE WHEN @CountOnly = 1 THEN 2147483647 ELSE @PageSize END ROWS ONLY;
END;
GO
