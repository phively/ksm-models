-- Historic goals
Select
  -- Materialized view fields
  gos.id_number
  , gos.report_name
  , gos.start_dt
  , gos.stop_dt
  -- Total tenure in KSM GO role, in years
  , round(
      (Case When stop_dt Is Not Null Then stop_dt Else cal.today End -- stop_dt if available
       - start_dt) / 365.25
       , 2
    ) As go_tenure_ksm_total
  -- Tenure in GO role as of start of indicated PY, in years
  , round(
      (to_date(goal.year - 1 || '0501', 'yyyymmdd') -- PY start is May (5)
       - start_dt) / 365.25
       , 2
    ) As go_tenure_py_start
  -- Account for GOs whose start/stop date was midway through the PY: what % of the year was at KSM
  , round(
      Case
        When start_dt > to_date(goal.year - 1 || '0501', 'yyyymmdd') Then
          (to_date(goal.year || '0430', 'yyyymmdd') - start_dt) / 365.25
        When stop_dt Is Null Then 1
        When stop_dt >= to_date(goal.year || '0430', 'yyyymmdd') Then 1
        When stop_dt < to_date(goal.year - 1 || '0501', 'yyyymmdd') Then 0
        Else (stop_dt - to_date(goal.year - 1 || '0501', 'yyyymmdd')) / 365.25
      End
      , 4
    ) As go_tenure_pct_at_ksm
  -- Goal table fields
  , goal.year
  , goal.goal_1 As closes_goal
  , goal.goal_2 As solicitations_goal
  , goal.goal_3 As dollars_goal
  , goal.goal_4 As visits_goal
  , goal.goal_5 As qualifications_goal
From goal
Cross Join v_current_calendar cal
Inner Join mv_past_ksm_gos gos On gos.id_number = goal.id_number
Order By
  report_name Asc
  , year Asc
