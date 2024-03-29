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
  -- Tenure as an NU GO as of start of indicated month, in years
  , round(
      (to_date(act.cal_year || lpad(act.cal_month, 2, '0') || '01', 'yyyymmdd') -- PY start is May (5)
       - start_dt) / 365.25
       , 2
    ) As go_tenure_mo_start
  -- Account for GOs whose start/stop date was during/before/after the time period
  , Case
      When to_date(act.cal_year || lpad(act.cal_month, 2, '0') || '01', 'yyyymmdd')
        Between start_dt And stop_dt
        Then 1
      When to_date(act.cal_year || lpad(act.cal_month, 2, '0') || '01', 'yyyymmdd') >= start_dt
        And stop_dt Is Null
        Then 1
      Else 0
    End As go_at_ksm
  -- Goal/activity view fields
  , act.goal_type
  , Case
      When act.goal_type = 'MGC' Then 'Closes'
      When act.goal_type = 'MGDR' Then 'Dollars'
      When act.goal_type = 'MGS' Then 'Solicitations'
      When act.goal_type = 'NOQV' Then 'Qualifications'
      When act.goal_type = 'NOV' Then 'Visits'
      When act.goal_type = 'PA' Then 'Assists'
    End As goal_desc
  , act.cal_year
  , act.cal_month
  , act.perf_year
  , act.perf_quarter
  , act.fy_goal
  , act.py_goal
  , act.adjusted_progress
From v_mgo_activity_monthly act
Cross Join v_current_calendar cal
Inner Join mv_past_ksm_gos gos On gos.id_number = act.id_number
Order By
  report_name Asc
  , cal_year Asc
  , cal_month Asc
  , goal_desc Asc
