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
  -- Tenure in GO role as of start of indicated month, in years
  , round(
      (to_date(goals.cal_year || lpad(goals.cal_month, 2, '0') || '01', 'yyyymmdd') -- PY start is May (5)
       - start_dt) / 365.25
       , 2
    ) As go_tenure_mo_start
  -- Account for GOs whose start/stop date was during/before/after the time period
  , round(
      Case
        When start_dt > to_date(goals.cal_year || lpad(goals.cal_month, 2, '0') || '01', 'yyyymmdd') Then
          (to_date(goals.cal_year || lpad(goals.cal_month, 2, '0') || '01', 'yyyymmdd') - start_dt) / 365.25
        When stop_dt Is Null Then 1
        -- Start of next month - 1 day = end of current month; modulo so that 12 wraps to 1
        -- Wasn't able to test this due to no data as of 3/29/18
        When stop_dt >= to_date(goals.cal_year || lpad(mod(goals.cal_month, 12) + 1, 2, '0') || '01', 'yyyymmdd') - 1 Then 1
        When stop_dt < to_date(goals.cal_year || lpad(mod(goals.cal_month, 12) + 1, 2, '0') || '01', 'yyyymmdd') - 1 Then 0
        Else (stop_dt - to_date(goals.cal_year || lpad(mod(goals.cal_month, 12) + 1, 2, '0') || '01', 'yyyymmdd') - 1) / 365.25
      End
      , 4
    ) As go_tenure_at_ksm
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
From v_mgo_goals_monthly goals
Cross Join v_current_calendar cal
Inner Join mv_past_ksm_gos gos On gos.id_number = goals.id_number
Order By
  report_name Asc
  , year Asc
