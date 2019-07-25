With

-- Parameters
params As (
  Select
    2018 As training_fy
  From DUAL
)

-- Household table
, hh As (
  Select *
  From v_entity_ksm_households
)

-- Contact reports
, crf As (
  Select
    report_id
    , id_number
    , report_name
    , contact_type_code
    , contact_type
    , contact_type_category
    , contact_purpose
    , contact_date
    , fiscal_year
  From v_contact_reports_fast
  Where contact_type_code In ('A', 'E', 'P', 'V') -- Attempted, email, phone, visit
)

-- Point-in-time eval
, all_evals As (
  Select
    e.id_number
    , e.prospect_id
    , e.evaluation_type
    , tet.short_desc As eval_type_desc
    , trunc(e.evaluation_date) As eval_start_dt
    -- Computed stop date for most recent active eval is just the end of this month
    -- For inactive evals, take the day before the next rating as the current rating's stop date
    -- If null, fill in modified date
    , Case
        When active_ind = 'Y' And evaluation_date = max(evaluation_date)
          Over(Partition By Case When prospect_id Is Not Null Then to_char(prospect_id) Else id_number End)
          Then last_day(cal.today)
        Else nvl(
          min(trunc(evaluation_date))
            Over(Partition By Case When prospect_id Is Not Null Then to_char(prospect_id) Else id_number End
              Order By evaluation_date Asc Rows Between 1 Following And Unbounded Following) - 1
          , trunc(e.date_modified)
        )
      End As eval_stop_dt
    , e.evaluator_id_number
    , e.active_ind
    , e.rating_code
    , trt.short_desc As rating_desc
    , e.xcomment As rating_comment
    -- Numeric value of lower end of eval rating range, using regular expressions
    , Case
        When trt.rating_code = 0 Then 0 -- Under $10K becomes 0
        Else rpt_pbh634.ksm_pkg.get_number_from_dollar(trt.short_desc)
      End As rating_lower_bound
  From evaluation e
  Cross Join rpt_pbh634.v_current_calendar cal
  Inner Join tms_evaluation_type tet On tet.evaluation_type = e.evaluation_type
  Inner Join tms_rating trt On trt.rating_code = e.rating_code
  Where tet.evaluation_type In ('PR', 'UR') -- Research, UOR
)
, evals As (
  Select Distinct
    hh.household_id
    , min(rating_lower_bound) keep(dense_rank First
        Order By eval_start_dt Desc, eval_stop_dt Desc, rating_lower_bound Desc)
      As evaluation_lower_bound
  From all_evals
  Cross Join params
  Inner Join hh
    On hh.id_number = all_evals.id_number
  Where to_date(params.training_fy || '0831', 'yyyymmdd') Between eval_start_dt And eval_stop_dt
    And evaluation_type = 'PR'
  Group By hh.household_id
)

-- IDs attmempted to be qualified in CFY or PFY-1
, qual_ids As (
  Select Distinct
    id_number
    , report_name
  From crf
  Cross Join v_current_calendar cal
  Where contact_purpose Like '1-%' -- Qualification
    And fiscal_year In (cal.curr_fy, cal.curr_fy - 1)
)

-- Count of contacts for IDs attempted to be qualified
, outreach_counts As (
  Select
    id_number
    , min(Case When contact_type_code = 'A' Then fiscal_year End)
      As first_outreach_fy
    , min(Case When contact_purpose Like '1-%' Then fiscal_year End)
      As first_qualification_fy
    ,min(Case When contact_type_code = 'V' Then fiscal_year End)
      As first_visit_fy
    , count(Case When fiscal_year = cal.curr_fy And contact_type_code = 'V' Then report_id End)
      As cfy_visits
    , count(Case When fiscal_year = cal.curr_fy - 1 And contact_type_code = 'V' Then report_id End)
      As pfy1_visits
    , count(Case When fiscal_year = cal.curr_fy - 2 And contact_type_code = 'V' Then report_id End)
      As pfy2_visits
    , count(Case When fiscal_year = cal.curr_fy - 3 And contact_type_code = 'V' Then report_id End)
      As pfy3_visits
    , count(Case When fiscal_year = cal.curr_fy And contact_type_code = 'A' Then report_id End)
      As cfy_outreach
    , count(Case When fiscal_year = cal.curr_fy - 1 And contact_type_code = 'A' Then report_id End)
      As pfy1_outreach
    , count(Case When fiscal_year = cal.curr_fy - 2 And contact_type_code = 'A' Then report_id End)
      As pfy2_outreach
    , count(Case When fiscal_year = cal.curr_fy - 3 And contact_type_code = 'A' Then report_id End)
      As pfy3_outreach
    , count(Case When fiscal_year = cal.curr_fy And contact_type_code = 'E' Then report_id End)
      As cfy_email
    , count(Case When fiscal_year = cal.curr_fy - 1 And contact_type_code = 'E' Then report_id End)
      As pfy1_email
    , count(Case When fiscal_year = cal.curr_fy - 2 And contact_type_code = 'E' Then report_id End)
      As pfy2_email
    , count(Case When fiscal_year = cal.curr_fy - 3 And contact_type_code = 'E' Then report_id End)
      As pfy3_email
    , count(Case When fiscal_year = cal.curr_fy And contact_type_code = 'P' Then report_id End)
      As cfy_phone
    , count(Case When fiscal_year = cal.curr_fy - 1 And contact_type_code = 'P' Then report_id End)
      As pfy1_phone
    , count(Case When fiscal_year = cal.curr_fy - 2 And contact_type_code = 'P' Then report_id End)
      As pfy2_phone
    , count(Case When fiscal_year = cal.curr_fy - 3 And contact_type_code = 'P' Then report_id End)
      As pfy3_phone
    , count(Case When fiscal_year = cal.curr_fy And contact_purpose Like '1-%' Then report_id End)
      As cfy_qualification
    , count(Case When fiscal_year = cal.curr_fy - 1 And contact_purpose Like '1-%' Then report_id End)
      As pfy1_qualification
    , count(Case When fiscal_year = cal.curr_fy - 2 And contact_purpose Like '1-%' Then report_id End)
      As pfy2_qualification
    , count(Case When fiscal_year = cal.curr_fy - 3 And contact_purpose Like '1-%' Then report_id End)
      As pfy3_qualification
    , count(Case When fiscal_year = cal.curr_fy And contact_purpose Like '1-%' And contact_type_code <> 'V'
        Then report_id End)
      As cfy_qualification_excl_visit
    , count(Case When fiscal_year = cal.curr_fy - 1 And contact_purpose Like '1-%' And contact_type_code <> 'V'
        Then report_id End)
      As pfy1_qualification_excl_visit
    , count(Case When fiscal_year = cal.curr_fy - 2 And contact_purpose Like '1-%' And contact_type_code <> 'V'
        Then report_id End)
      As pfy2_qualification_excl_visit
    , count(Case When fiscal_year = cal.curr_fy - 3 And contact_purpose Like '1-%' And contact_type_code <> 'V'
        Then report_id End)
      As pfy3_qualification_excl_visit
  From crf
  Cross Join v_current_calendar cal
  Group By id_number
)

Select
  qi.id_number
  , hh.report_name
  , hh.institutional_suffix
  , hh.record_status_code
  , hh.degrees_concat
  , hh.program_group
  , oc.first_outreach_fy
  , oc.first_qualification_fy
  , oc.first_visit_fy
  , oc.cfy_visits
  , oc.pfy1_visits
  , oc.pfy2_visits
  , oc.pfy3_visits
  , oc.cfy_outreach
  , oc.pfy1_outreach
  , oc.pfy2_outreach
  , oc.pfy3_outreach
  , oc.cfy_email
  , oc.pfy1_email
  , oc.pfy2_email
  , oc.pfy3_email
  , oc.cfy_phone
  , oc.pfy1_phone
  , oc.pfy2_phone
  , oc.pfy3_phone
  , oc.cfy_qualification
  , oc.pfy1_qualification
  , oc.pfy2_qualification
  , oc.pfy3_qualification
  , oc.cfy_qualification_excl_visit
  , oc.pfy1_qualification_excl_visit
  , oc.pfy2_qualification_excl_visit
  , oc.pfy3_qualification_excl_visit
  , mg.pr_score
  , mg.id_score
  , evals.evaluation_lower_bound
From qual_ids qi
Inner Join hh
  On hh.id_number = qi.id_number
Inner Join outreach_counts oc
  On oc.id_number = qi.id_number
Left Join v_ksm_model_mg mg
  On mg.id_number = qi.id_number
Left Join evals
  On evals.household_id = hh.household_id
