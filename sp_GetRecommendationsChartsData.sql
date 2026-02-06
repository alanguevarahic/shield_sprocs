SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetRecommendationsChartsData]') AND type IN (N'P', N'PC'))
BEGIN
    EXEC('CREATE PROCEDURE [dbo].[sp_GetRecommendationsChartsData]
        @ShowActiveUnitsOnly BIT = 0,
        @ActiveAssets BIT = 1,
        @InactiveAssets BIT = 0,
        @PsmAssets BIT = 1,
        @NonPsmAssets BIT = 1,
        @MiRelevantAssets BIT = 1,
        @NonMiRelevantAssets BIT = 0,
        @OnlyOpenRecommendations BIT = 1,
        @UnitId INT = NULL,
        @CompanyLevelId INT = NULL
    AS BEGIN SET NOCOUNT ON; END')
END
GO

ALTER PROCEDURE [dbo].[sp_GetRecommendationsChartsData]
    @ShowActiveUnitsOnly BIT = 0,
    @ActiveAssets BIT = 1,
    @InactiveAssets BIT = 0,
    @PsmAssets BIT = 1,
    @NonPsmAssets BIT = 1,
    @MiRelevantAssets BIT = 1,
    @NonMiRelevantAssets BIT = 0,
    @OnlyOpenRecommendations BIT = 1,
    @UnitId INT = NULL,
    @CompanyLevelId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    DECLARE @DaysPerMonth FLOAT = 365.2435 / 12;

    -- Filtered asset IDs (single pass per asset type)
    ;WITH FilteredAtmTank AS (
        SELECT at.id
        FROM AtmTank at
        INNER JOIN AssetUnit u ON at.unit_id = u.id
        LEFT JOIN CompanyLevel cl1 ON u.parent_level_id = cl1.id
        LEFT JOIN CompanyLevel cl2 ON cl1.parent_level_id = cl2.id
        LEFT JOIN CompanyLevel cl3 ON cl2.parent_level_id = cl3.id
        WHERE (@ShowActiveUnitsOnly = 0 OR u.active = 1)
          AND ((@ActiveAssets = 1 AND at.active = 1) OR (@InactiveAssets = 1 AND at.active = 0))
          AND ((@PsmAssets = 1 AND at.psm = 1) OR (@NonPsmAssets = 1 AND at.psm = 0))
          AND ((@MiRelevantAssets = 1 AND at.mi_relevant = 1) OR (@NonMiRelevantAssets = 1 AND at.mi_relevant = 0))
          AND (@UnitId IS NULL OR at.unit_id = @UnitId)
          AND (@UnitId IS NOT NULL OR @CompanyLevelId IS NULL OR @CompanyLevelId IN (u.parent_level_id, cl1.id, cl2.id, cl3.id))
    ),
    FilteredPiping AS (
        SELECT p.id
        FROM Piping p
        INNER JOIN AssetUnit u ON p.unit_id = u.id
        LEFT JOIN CompanyLevel cl1 ON u.parent_level_id = cl1.id
        LEFT JOIN CompanyLevel cl2 ON cl1.parent_level_id = cl2.id
        LEFT JOIN CompanyLevel cl3 ON cl2.parent_level_id = cl3.id
        WHERE (@ShowActiveUnitsOnly = 0 OR u.active = 1)
          AND ((@ActiveAssets = 1 AND p.active = 1) OR (@InactiveAssets = 1 AND p.active = 0))
          AND ((@PsmAssets = 1 AND p.psm = 1) OR (@NonPsmAssets = 1 AND p.psm = 0))
          AND ((@MiRelevantAssets = 1 AND p.mi_relevant = 1) OR (@NonMiRelevantAssets = 1 AND p.mi_relevant = 0))
          AND (@UnitId IS NULL OR p.unit_id = @UnitId)
          AND (@UnitId IS NOT NULL OR @CompanyLevelId IS NULL OR @CompanyLevelId IN (u.parent_level_id, cl1.id, cl2.id, cl3.id))
    ),
    FilteredPipeline AS (
        SELECT pl.id
        FROM Pipeline pl
        INNER JOIN AssetUnit u ON pl.unit_id = u.id
        LEFT JOIN CompanyLevel cl1 ON u.parent_level_id = cl1.id
        LEFT JOIN CompanyLevel cl2 ON cl1.parent_level_id = cl2.id
        LEFT JOIN CompanyLevel cl3 ON cl2.parent_level_id = cl3.id
        WHERE (@ShowActiveUnitsOnly = 0 OR u.active = 1)
          AND ((@ActiveAssets = 1 AND pl.active = 1) OR (@InactiveAssets = 1 AND pl.active = 0))
          AND ((@PsmAssets = 1 AND pl.psm = 1) OR (@NonPsmAssets = 1 AND pl.psm = 0))
          AND ((@MiRelevantAssets = 1 AND pl.mi_relevant = 1) OR (@NonMiRelevantAssets = 1 AND pl.mi_relevant = 0))
          AND (@UnitId IS NULL OR pl.unit_id = @UnitId)
          AND (@UnitId IS NOT NULL OR @CompanyLevelId IS NULL OR @CompanyLevelId IN (u.parent_level_id, cl1.id, cl2.id, cl3.id))
    ),
    FilteredPressureVessels AS (
        SELECT pv.id
        FROM PressureVessel pv
        INNER JOIN AssetUnit u ON pv.unit_id = u.id
        LEFT JOIN CompanyLevel cl1 ON u.parent_level_id = cl1.id
        LEFT JOIN CompanyLevel cl2 ON cl1.parent_level_id = cl2.id
        LEFT JOIN CompanyLevel cl3 ON cl2.parent_level_id = cl3.id
        WHERE (@ShowActiveUnitsOnly = 0 OR u.active = 1)
          AND ((@ActiveAssets = 1 AND pv.active = 1) OR (@InactiveAssets = 1 AND pv.active = 0))
          AND ((@PsmAssets = 1 AND pv.psm = 1) OR (@NonPsmAssets = 1 AND pv.psm = 0))
          AND ((@MiRelevantAssets = 1 AND pv.mi_relevant = 1) OR (@NonMiRelevantAssets = 1 AND pv.mi_relevant = 0))
          AND (@UnitId IS NULL OR pv.unit_id = @UnitId)
          AND (@UnitId IS NOT NULL OR @CompanyLevelId IS NULL OR @CompanyLevelId IN (u.parent_level_id, cl1.id, cl2.id, cl3.id))
    ),
    FilteredPsv AS (
        SELECT psv.id
        FROM Psv psv
        INNER JOIN AssetUnit u ON psv.unit_id = u.id
        LEFT JOIN CompanyLevel cl1 ON u.parent_level_id = cl1.id
        LEFT JOIN CompanyLevel cl2 ON cl1.parent_level_id = cl2.id
        LEFT JOIN CompanyLevel cl3 ON cl2.parent_level_id = cl3.id
        WHERE (@ShowActiveUnitsOnly = 0 OR u.active = 1)
          AND ((@ActiveAssets = 1 AND psv.active = 1) OR (@InactiveAssets = 1 AND psv.active = 0))
          AND ((@PsmAssets = 1 AND psv.psm = 1) OR (@NonPsmAssets = 1 AND psv.psm = 0))
          AND ((@MiRelevantAssets = 1 AND psv.mi_relevant = 1) OR (@NonMiRelevantAssets = 1 AND psv.mi_relevant = 0))
          AND (@UnitId IS NULL OR psv.unit_id = @UnitId)
          AND (@UnitId IS NOT NULL OR @CompanyLevelId IS NULL OR @CompanyLevelId IN (u.parent_level_id, cl1.id, cl2.id, cl3.id))
    ),
    -- Single CTE for all filtered recommendations (asset filter via EXISTS)
    FilteredRecommendations AS (
        SELECT
            r.id,
            r.target_date,
            r.completion_date,
            rc.score_card,
            ISNULL(tmp.priority_name, 'Unassigned') AS priority_name,
            tma.completed_date AS activity_completed_date,
            DATEDIFF(day, tma.completed_date, @Today) AS days_since_completed
        FROM Recommendation r
        INNER JOIN TaskMasterActivity tma ON r.activity_id = tma.id
        INNER JOIN TaskMasterTask tmt ON tma.task_id = tmt.id
        INNER JOIN RecommendationCondition rc ON r.condition_id = rc.id
        LEFT JOIN TaskMasterPriority tmp ON r.priority_id = tmp.id
        INNER JOIN AssetUnit au ON r.unit_id = au.id
        LEFT JOIN CompanyLevel cl1 ON au.parent_level_id = cl1.id
        LEFT JOIN CompanyLevel cl2 ON cl1.parent_level_id = cl2.id
        LEFT JOIN CompanyLevel cl3 ON cl2.parent_level_id = cl3.id
        WHERE (@ShowActiveUnitsOnly = 0 OR au.active = 1)
          AND (@UnitId IS NULL OR r.unit_id = @UnitId)
          AND (@UnitId IS NOT NULL OR @CompanyLevelId IS NULL OR @CompanyLevelId IN (au.parent_level_id, cl1.id, cl2.id, cl3.id))
          AND (
              (tmt.asset_type = 'tank' AND EXISTS (SELECT 1 FROM FilteredAtmTank ft WHERE ft.id = r.tag_id))
              OR (tmt.asset_type = 'piping' AND EXISTS (SELECT 1 FROM FilteredPiping fp WHERE fp.id = r.tag_id))
              OR (tmt.asset_type = 'pipeline' AND EXISTS (SELECT 1 FROM FilteredPipeline fpl WHERE fpl.id = r.tag_id))
              OR (tmt.asset_type = 'pressure-vessel' AND EXISTS (SELECT 1 FROM FilteredPressureVessels fpv WHERE fpv.id = r.tag_id))
              OR (tmt.asset_type = 'psv' AND EXISTS (SELECT 1 FROM FilteredPsv fpsv WHERE fpsv.id = r.tag_id))
              OR tmt.asset_type NOT IN ('tank', 'piping', 'pipeline', 'pressure-vessel', 'psv')
          )
    )
    SELECT id, target_date, completion_date, score_card, priority_name, activity_completed_date, days_since_completed
    INTO #FilteredRecommendations
    FROM FilteredRecommendations;

    -- Result Set 1: byTargetDate (Overdue first, then by month in chronological order)
    SELECT [date], [count]
    FROM (
        SELECT 'Overdue' AS [date], COUNT(*) AS [count], 0 AS sort_order, CAST('1900-01-01' AS DATE) AS sort_date
        FROM #FilteredRecommendations
        WHERE completion_date IS NULL AND target_date < @Today
        UNION ALL
        SELECT FORMAT(MIN(target_date), 'MMM-yyyy') AS [date], COUNT(*) AS [count], 1 AS sort_order, DATEFROMPARTS(YEAR(MIN(target_date)), MONTH(MIN(target_date)), 1) AS sort_date
        FROM #FilteredRecommendations
        WHERE completion_date IS NULL AND target_date >= @Today
        GROUP BY YEAR(target_date), MONTH(target_date)
    ) AS byTargetDate
    ORDER BY sort_order, sort_date;

    -- Result Set 2: byScoreCard
    SELECT fr.score_card AS [date], COUNT(*) AS [count]
    FROM #FilteredRecommendations fr
    WHERE (@OnlyOpenRecommendations = 0 OR fr.completion_date IS NULL)
    GROUP BY fr.score_card
    ORDER BY fr.score_card;

    -- Result Set 3: byPriorityOpen (open recommendations only)
    SELECT fr.priority_name AS [date], COUNT(*) AS [count]
    FROM #FilteredRecommendations fr
    WHERE fr.completion_date IS NULL
    GROUP BY fr.priority_name
    ORDER BY fr.priority_name;

    -- Result Set 4: Percentages (single row)
    SELECT
        CASE WHEN total > 0 THEN ROUND(CAST(open_on_time * 100.0 / total AS FLOAT), 1) ELSE 0 END AS percentageOpen,
        CASE WHEN total > 0 THEN ROUND(CAST(open_overdue * 100.0 / total AS FLOAT), 1) ELSE 0 END AS percentageOpenOverdue,
        CASE WHEN total > 0 THEN ROUND(CAST(closed * 100.0 / total AS FLOAT), 1) ELSE 0 END AS percentageClosed
    FROM (
        SELECT
            COUNT(*) AS total,
            SUM(CASE WHEN completion_date IS NULL AND target_date >= @Today THEN 1 ELSE 0 END) AS open_on_time,
            SUM(CASE WHEN completion_date IS NULL AND target_date < @Today THEN 1 ELSE 0 END) AS open_overdue,
            SUM(CASE WHEN completion_date IS NOT NULL THEN 1 ELSE 0 END) AS closed
        FROM #FilteredRecommendations
    ) AS pct;

    -- Result Set 5: allPrioritiesData
    SELECT
        fr.priority_name AS priorityName,
        SUM(CASE WHEN fr.completion_date IS NOT NULL THEN 1 ELSE 0 END) AS closedCount,
        SUM(CASE WHEN fr.completion_date IS NULL AND fr.days_since_completed / @DaysPerMonth < 6 THEN 1 ELSE 0 END) AS lessThanSixMonthsCount,
        SUM(CASE WHEN fr.completion_date IS NULL AND fr.days_since_completed / @DaysPerMonth >= 6 AND fr.days_since_completed / @DaysPerMonth < 12 THEN 1 ELSE 0 END) AS betweenSixAndTwelveMonthsCount,
        SUM(CASE WHEN fr.completion_date IS NULL AND fr.days_since_completed / @DaysPerMonth >= 12 AND fr.days_since_completed / @DaysPerMonth < 24 THEN 1 ELSE 0 END) AS betweenTwelveAndTwentyFourMonthsCount,
        SUM(CASE WHEN fr.completion_date IS NULL AND fr.days_since_completed / @DaysPerMonth >= 24 THEN 1 ELSE 0 END) AS moreThanTwentyFourCount
    FROM #FilteredRecommendations fr
    GROUP BY fr.priority_name
    ORDER BY fr.priority_name;
END;
GO