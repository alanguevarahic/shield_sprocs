SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetInspectionsChartsData]') AND type IN (N'P', N'PC'))
BEGIN
    EXEC('CREATE PROCEDURE [dbo].[sp_GetInspectionsChartsData]
        @ShowActiveUnitsOnly BIT = 0,
        @ActiveAssets BIT = 1,
        @InactiveAssets BIT = 0,
        @PsmAssets BIT = 1,
        @NonPsmAssets BIT = 1,
        @MiRelevantAssets BIT = 1,
        @NonMiRelevantAssets BIT = 0,
        @ActiveSchedules BIT = 1,
        @InactiveSchedules BIT = 1,
        @UnitId INT = NULL,
        @CompanyLevelId INT = NULL
    AS BEGIN SET NOCOUNT ON; END')
END
GO

ALTER PROCEDURE [dbo].[sp_GetInspectionsChartsData]
    @ShowActiveUnitsOnly BIT = 0,
    @ActiveAssets BIT = 1,
    @InactiveAssets BIT = 0,
    @PsmAssets BIT = 1,
    @NonPsmAssets BIT = 1,
    @MiRelevantAssets BIT = 1,
    @NonMiRelevantAssets BIT = 0,
    @ActiveSchedules BIT = 1,
    @InactiveSchedules BIT = 1,
    @UnitId INT = NULL,
    @CompanyLevelId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    DECLARE @TodayPlus30 DATE = DATEADD(day, 30, @Today);
    DECLARE @CurrentYear INT = YEAR(@Today);

    -- Filtered asset IDs
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
    FilteredSchedules AS (
        SELECT
            tms.id,
            tms.next_done_date,
            tms.last_done_date,
            tmt.thickness_task
        FROM TaskMasterInspectionSchedule tms
        INNER JOIN TaskMasterTask tmt ON tms.task_id = tmt.id
        INNER JOIN AssetUnit au ON tms.unit_id = au.id
        LEFT JOIN CompanyLevel cl1 ON au.parent_level_id = cl1.id
        LEFT JOIN CompanyLevel cl2 ON cl1.parent_level_id = cl2.id
        LEFT JOIN CompanyLevel cl3 ON cl2.parent_level_id = cl3.id
        WHERE ((@ActiveSchedules = 1 AND tms.active = 1) OR (@InactiveSchedules = 1 AND tms.active = 0))
          AND (@ShowActiveUnitsOnly = 0 OR au.active = 1)
          AND (@UnitId IS NULL OR tms.unit_id = @UnitId)
          AND (@UnitId IS NOT NULL OR @CompanyLevelId IS NULL OR @CompanyLevelId IN (au.parent_level_id, cl1.id, cl2.id, cl3.id))
          AND (
              (tms.asset_type = 'tank' AND EXISTS (SELECT 1 FROM FilteredAtmTank ft WHERE ft.id = tms.tag_id))
              OR (tms.asset_type = 'piping' AND EXISTS (SELECT 1 FROM FilteredPiping fp WHERE fp.id = tms.tag_id))
              OR (tms.asset_type = 'pipeline' AND EXISTS (SELECT 1 FROM FilteredPipeline fpl WHERE fpl.id = tms.tag_id))
              OR (tms.asset_type = 'pressure-vessel' AND EXISTS (SELECT 1 FROM FilteredPressureVessels fpv WHERE fpv.id = tms.tag_id))
              OR (tms.asset_type = 'psv' AND EXISTS (SELECT 1 FROM FilteredPsv fpsv WHERE fpsv.id = tms.tag_id))
              OR tms.asset_type NOT IN ('tank', 'piping', 'pipeline', 'pressure-vessel', 'psv')
          )
    ),
    FilteredActivities AS (
        SELECT
            tma.id,
            tma.completed_date
        FROM TaskMasterActivity tma
        INNER JOIN TaskMasterTask tmt ON tma.task_id = tmt.id
        INNER JOIN AssetUnit au ON tma.unit_id = au.id
        LEFT JOIN CompanyLevel cl1 ON au.parent_level_id = cl1.id
        LEFT JOIN CompanyLevel cl2 ON cl1.parent_level_id = cl2.id
        LEFT JOIN CompanyLevel cl3 ON cl2.parent_level_id = cl3.id
        WHERE (@ShowActiveUnitsOnly = 0 OR au.active = 1)
          AND (@UnitId IS NULL OR tma.unit_id = @UnitId)
          AND (@UnitId IS NOT NULL OR @CompanyLevelId IS NULL OR @CompanyLevelId IN (au.parent_level_id, cl1.id, cl2.id, cl3.id))
          AND (
              (tmt.asset_type = 'tank' AND EXISTS (SELECT 1 FROM FilteredAtmTank ft WHERE ft.id = tma.tag_id))
              OR (tmt.asset_type = 'piping' AND EXISTS (SELECT 1 FROM FilteredPiping fp WHERE fp.id = tma.tag_id))
              OR (tmt.asset_type = 'pipeline' AND EXISTS (SELECT 1 FROM FilteredPipeline fpl WHERE fpl.id = tma.tag_id))
              OR (tmt.asset_type = 'pressure-vessel' AND EXISTS (SELECT 1 FROM FilteredPressureVessels fpv WHERE fpv.id = tma.tag_id))
              OR (tmt.asset_type = 'psv' AND EXISTS (SELECT 1 FROM FilteredPsv fpsv WHERE fpsv.id = tma.tag_id))
              OR tmt.asset_type NOT IN ('tank', 'piping', 'pipeline', 'pressure-vessel', 'psv')
          )
    )

    -- Result Set 1: inspections (Overdue first, then by year)
    SELECT [year], [count]
    FROM (
        SELECT 'Overdue' AS [year], COUNT(*) AS [count], 0 AS sort_order
        FROM FilteredSchedules
        WHERE next_done_date < @Today
        UNION ALL
        SELECT CAST(YEAR(next_done_date) AS NVARCHAR(10)) AS [year], COUNT(*) AS [count], 1 AS sort_order
        FROM FilteredSchedules
        WHERE next_done_date >= @Today
        GROUP BY YEAR(next_done_date)
    ) AS insp
    ORDER BY sort_order, [year];

    -- Result Set 2: activities (by completed year)
    SELECT CAST(YEAR(completed_date) AS NVARCHAR(10)) AS [year], COUNT(*) AS [count]
    FROM FilteredActivities
    GROUP BY YEAR(completed_date)
    ORDER BY [year];

    -- Result Set 3: All metrics (single row)
    SELECT
        SUM(CASE WHEN last_done_date >= DATEFROMPARTS(@CurrentYear, 1, 1) AND last_done_date < DATEFROMPARTS(@CurrentYear + 1, 1, 1) THEN 1 ELSE 0 END) AS completedThisYear,
        SUM(CASE WHEN thickness_task = 1 AND last_done_date >= DATEFROMPARTS(@CurrentYear, 1, 1) AND last_done_date < DATEFROMPARTS(@CurrentYear + 1, 1, 1) THEN 1 ELSE 0 END) AS thicknessCompletedThisYear,
        SUM(CASE WHEN thickness_task = 0 AND last_done_date >= DATEFROMPARTS(@CurrentYear, 1, 1) AND last_done_date < DATEFROMPARTS(@CurrentYear + 1, 1, 1) THEN 1 ELSE 0 END) AS nonThicknessCompletedThisYear,
        SUM(CASE WHEN next_done_date >= DATEFROMPARTS(@CurrentYear, 1, 1) AND next_done_date < DATEFROMPARTS(@CurrentYear + 1, 1, 1) THEN 1 ELSE 0 END) AS remainingDueThisYear,
        SUM(CASE WHEN thickness_task = 1 AND next_done_date >= DATEFROMPARTS(@CurrentYear, 1, 1) AND next_done_date < DATEFROMPARTS(@CurrentYear + 1, 1, 1) THEN 1 ELSE 0 END) AS thicknessRemainingDueThisYear,
        SUM(CASE WHEN thickness_task = 0 AND next_done_date >= DATEFROMPARTS(@CurrentYear, 1, 1) AND next_done_date < DATEFROMPARTS(@CurrentYear + 1, 1, 1) THEN 1 ELSE 0 END) AS nonThicknessRemainingDueThisYear,
        SUM(CASE WHEN next_done_date < @Today THEN 1 ELSE 0 END) AS pastDue,
        SUM(CASE WHEN thickness_task = 1 AND next_done_date < @Today THEN 1 ELSE 0 END) AS thicknessPastDue,
        SUM(CASE WHEN thickness_task = 0 AND next_done_date < @Today THEN 1 ELSE 0 END) AS nonThicknessPastDue,
        SUM(CASE WHEN next_done_date >= @Today AND next_done_date <= @TodayPlus30 THEN 1 ELSE 0 END) AS dueInThirtyDays,
        SUM(CASE WHEN thickness_task = 1 AND next_done_date >= @Today AND next_done_date <= @TodayPlus30 THEN 1 ELSE 0 END) AS thicknessDueInThirtyDays,
        SUM(CASE WHEN thickness_task = 0 AND next_done_date >= @Today AND next_done_date <= @TodayPlus30 THEN 1 ELSE 0 END) AS nonThicknessDueInThirtyDays,
        SUM(CASE WHEN YEAR(next_done_date) = @CurrentYear + 1 THEN 1 ELSE 0 END) AS nextDueOneYear,
        SUM(CASE WHEN thickness_task = 1 AND YEAR(next_done_date) = @CurrentYear + 1 THEN 1 ELSE 0 END) AS thicknessDueOneYear,
        SUM(CASE WHEN thickness_task = 0 AND YEAR(next_done_date) = @CurrentYear + 1 THEN 1 ELSE 0 END) AS nonThicknessDueOneYear,
        SUM(CASE WHEN YEAR(next_done_date) = @CurrentYear + 2 THEN 1 ELSE 0 END) AS nextDueTwoYears,
        SUM(CASE WHEN thickness_task = 1 AND YEAR(next_done_date) = @CurrentYear + 2 THEN 1 ELSE 0 END) AS thicknessDueTwoYears,
        SUM(CASE WHEN thickness_task = 0 AND YEAR(next_done_date) = @CurrentYear + 2 THEN 1 ELSE 0 END) AS nonThicknessDueTwoYears,
        SUM(CASE WHEN YEAR(next_done_date) = @CurrentYear + 3 THEN 1 ELSE 0 END) AS nextDueThreeYears,
        SUM(CASE WHEN thickness_task = 1 AND YEAR(next_done_date) = @CurrentYear + 3 THEN 1 ELSE 0 END) AS thicknessDueThreeYears,
        SUM(CASE WHEN thickness_task = 0 AND YEAR(next_done_date) = @CurrentYear + 3 THEN 1 ELSE 0 END) AS nonThicknessDueThreeYears,
        SUM(CASE WHEN YEAR(next_done_date) = @CurrentYear + 4 THEN 1 ELSE 0 END) AS nextDueFourYears,
        SUM(CASE WHEN thickness_task = 1 AND YEAR(next_done_date) = @CurrentYear + 4 THEN 1 ELSE 0 END) AS thicknessDueFourYears,
        SUM(CASE WHEN thickness_task = 0 AND YEAR(next_done_date) = @CurrentYear + 4 THEN 1 ELSE 0 END) AS nonThicknessDueFourYears,
        SUM(CASE WHEN YEAR(next_done_date) = @CurrentYear AND MONTH(next_done_date) <= 3 THEN 1 ELSE 0 END) AS dueFirstQuarter,
        SUM(CASE WHEN thickness_task = 1 AND YEAR(next_done_date) = @CurrentYear AND MONTH(next_done_date) <= 3 THEN 1 ELSE 0 END) AS thicknessDueFirstQuarter,
        SUM(CASE WHEN thickness_task = 0 AND YEAR(next_done_date) = @CurrentYear AND MONTH(next_done_date) <= 3 THEN 1 ELSE 0 END) AS nonThicknessDueFirstQuarter,
        SUM(CASE WHEN YEAR(next_done_date) = @CurrentYear AND MONTH(next_done_date) > 3 AND MONTH(next_done_date) <= 6 THEN 1 ELSE 0 END) AS dueSecondQuarter,
        SUM(CASE WHEN thickness_task = 1 AND YEAR(next_done_date) = @CurrentYear AND MONTH(next_done_date) > 3 AND MONTH(next_done_date) <= 6 THEN 1 ELSE 0 END) AS thicknessDueSecondQuarter,
        SUM(CASE WHEN thickness_task = 0 AND YEAR(next_done_date) = @CurrentYear AND MONTH(next_done_date) > 3 AND MONTH(next_done_date) <= 6 THEN 1 ELSE 0 END) AS nonThicknessDueSecondQuarter,
        SUM(CASE WHEN YEAR(next_done_date) = @CurrentYear AND MONTH(next_done_date) > 6 AND MONTH(next_done_date) <= 9 THEN 1 ELSE 0 END) AS dueThirdQuarter,
        SUM(CASE WHEN thickness_task = 1 AND YEAR(next_done_date) = @CurrentYear AND MONTH(next_done_date) > 6 AND MONTH(next_done_date) <= 9 THEN 1 ELSE 0 END) AS thicknessDueThirdQuarter,
        SUM(CASE WHEN thickness_task = 0 AND YEAR(next_done_date) = @CurrentYear AND MONTH(next_done_date) > 6 AND MONTH(next_done_date) <= 9 THEN 1 ELSE 0 END) AS nonThicknessDueThirdQuarter,
        SUM(CASE WHEN YEAR(next_done_date) = @CurrentYear AND MONTH(next_done_date) > 9 THEN 1 ELSE 0 END) AS dueFourthQuarter,
        SUM(CASE WHEN thickness_task = 1 AND YEAR(next_done_date) = @CurrentYear AND MONTH(next_done_date) > 9 THEN 1 ELSE 0 END) AS thicknessDueFourthQuarter,
        SUM(CASE WHEN thickness_task = 0 AND YEAR(next_done_date) = @CurrentYear AND MONTH(next_done_date) > 9 THEN 1 ELSE 0 END) AS nonThicknessDueFourthQuarter
    FROM FilteredSchedules;
END;
GO