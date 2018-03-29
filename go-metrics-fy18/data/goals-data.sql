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
      (to_date(goals.cal_year || lpad(goals.cal_month, 2, '0') || '01', 'yyyymmdd') -- PY start is May (5)
       - start_dt) / 365.25
       , 2
    ) As go_tenure_mo_start
  -- Account for GOs whose start/stop date was during/before/after the time period
  , Case
      When to_date(goals.cal_year || lpad(goals.cal_month, 2, '0') || '01', 'yyyymmdd')
        Between start_dt And stop_dt
        Then 1
      When to_date(goals.cal_year || lpad(goals.cal_month, 2, '0') || '01', 'yyyymmdd') >= start_dt
        And stop_dt Is Null
        Then 1
      Else 0
    End As go_at_ksm
  -- Goal view fields
  , goals.goal_type
  , Case
      When goals.goal_type = 'MGC' Then 'Closes'
      When goals.goal_type = 'MGDR' Then 'Dollars'
      When goals.goal_type = 'MGS' Then 'Solicitations'
      When goals.goal_type = 'NOQV' Then 'Qualifications'
      When goals.goal_type = 'NOV' Then 'Visits'
      When goals.goal_type = 'PA' Then 'Assists'
    End As goal_desc
  , goals.cal_year
  , goals.cal_month
  , goals.perf_quarter
  , goals.perf_year
  , goals.goal
  , goals.cnt
  -- PY goal from self join
  , Case
      When goals2.goal Is Not Null Then goals2.goal
      Else goals.goal
    End As py_goal
From v_mgo_goals_monthly goals
Cross Join v_current_calendar cal
Inner Join mv_past_ksm_gos gos On gos.id_number = goals.id_number
-- Self join to add PY goal
Left Join v_mgo_goals_monthly goals2
  On goals2.id_number = goals.id_number
  And goals2.goal_type = goals.goal_type
  And goals2.perf_year = goals.year
  And goals2.cal_month = goals.cal_month
Order By
  report_name Asc
  , cal_year Asc
  , cal_month Asc
  , goal_desc Asc
