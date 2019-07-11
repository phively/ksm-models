With

-- Contact reports
crf As (
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

-- IDs attmempted to be qualified in CFY or PFY-1
, qual_ids As (
  Select Distinct
    id_number
    , report_name
  From crf
  Cross Join v_current_calendar cal
  Where contact_purpose Like '1-%' -- Qualification
    And fiscal_year In (cal.curr_fy, cal.curr_fy + 1)
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
    , count(Case When fiscal_year = cal.curr_fy And contact_type_code = 'A' Then report_id End)
      As cfy_outreach
    , count(Case When fiscal_year = cal.curr_fy - 1 And contact_type_code = 'A' Then report_id End)
      As pfy1_outreach
    , count(Case When fiscal_year = cal.curr_fy And contact_type_code = 'E' Then report_id End)
      As cfy_email
    , count(Case When fiscal_year = cal.curr_fy - 1 And contact_type_code = 'E' Then report_id End)
      As pfy1_email
    , count(Case When fiscal_year = cal.curr_fy And contact_type_code = 'P' Then report_id End)
      As cfy_phone
    , count(Case When fiscal_year = cal.curr_fy - 1 And contact_type_code = 'P' Then report_id End)
      As pfy1_phone
    , count(Case When fiscal_year = cal.curr_fy And contact_purpose Like '1-%' Then report_id End)
      As cfy_qualification
    , count(Case When fiscal_year = cal.curr_fy - 1 And contact_purpose Like '1-%' Then report_id End)
      As pfy1_qualification
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
  , oc.first_outreach_fy
  , oc.first_qualification_fy
  , oc.first_visit_fy
  , oc.cfy_visits
  , oc.pfy1_visits
  , oc.cfy_outreach
  , oc.pfy1_outreach
  , oc.cfy_email
  , oc.pfy1_email
  , oc.cfy_phone
  , oc.pfy1_phone
  , oc.cfy_qualification
  , oc.pfy1_qualification
  , mg.pr_score
From qual_ids qi
Inner Join v_entity_ksm_households hh
  On hh.id_number = qi.id_number
Inner Join outreach_counts oc
  On oc.id_number = qi.id_number
Left Join v_ksm_model_mg mg
  On mg.id_number = qi.id_number
