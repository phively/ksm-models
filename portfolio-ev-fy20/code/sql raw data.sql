-- Household snapshot -- run once
/*
Drop Materialized View tmp_mv_hh
;

Create Materialized View tmp_mv_hh As
Select
  hh.*
  , cal.yesterday As data_as_of
From v_entity_ksm_households hh
Cross Join v_current_calendar cal
Where
  -- Alumni only
  hh.household_program_group Is Not Null
;

Drop Materialized View tmp_mv_gt
;

Create Materialized View tmp_mv_gt As
Select
  gth.*
  , cal.yesterday As data_as_of
From v_ksm_giving_trans_hh gth
Cross Join v_current_calendar cal
Where gth.hh_recognition_credit > 0
;
*/

--------------------
---- Base table ----
--------------------

-- Alumni
Select
  hh.household_id
  , Case
      When household_spouse_rpt_name Is Not Null
        Then 2
      Else 1
      End
    As hh_count
  , hh.household_rpt_name
  , hh.household_spouse_id
  , hh.household_spouse_rpt_name
  , hh.record_status_code
  , hh.household_ksm_year
  , hh.household_masters_year
  , hh.household_last_masters_year
  , hh.household_program
  , hh.household_program_group
  , trunc(entity.date_added)
    As date_added
  , hh.data_as_of
From tmp_mv_hh hh
Inner Join entity
  On entity.id_number = hh.id_number
Where
  -- Primary only
  hh.household_primary = 'Y'
;

--------------------
---- Engagement ----
--------------------

-- Committees
Select
  hh.household_id
  , c.id_number
  , c.committee_code
  , c.committee_desc
  , c.committee_role_code
  , c.committee_role
  , c.committee_role_xsequence
  , c.ksm_committee
  , c.committee_status
  , c.start_dt_calc
  , c.stop_dt_calc
  , Case
      When c.committee_role_code In (
          'B', 'C', 'CC', 'CL', 'DAL', 'E', 'I', 'P', 'PE', 'RGD', 'T', 'TA', 'TC', 'TF', 'TL', 'TN', 'TO', 'V'
        )
        Then 'Y'
      When c.committee_code In (
          'KPH' -- PHS
          , 'UA' -- KAC (historical)
          , 'KACNA' -- KAC
          , 'U' -- GAB
          , 'KCC' -- Campaign Committee
          , 'KGAB' -- GAB (historical)
          , 'KACAS' -- KAC (historical)
          , 'KACEM' -- KAC (historical)
          , 'KACLA' -- KAC (historical)
          , 'KAMP' -- Asset Management
          , 'KCGN' -- Corporate Governance
          , 'CEW' -- Executive Women
          , 'KCDO' -- Diversity
        )
        Then 'Y'
      End
    As ksm_leader
From v_nu_committees c
Inner Join tmp_mv_hh hh
  On hh.id_number = c.id_number
Where c.committee_status_code In ('C', 'F', 'A', 'U') -- Current, Former, Active, Inactive; A/I for historic tracking
    And c.committee_role_code Not In ('EF') -- Our NU Follower
;

-- Events
Select
  hh.household_id
  , e.id_number
  , e.event_id
  , e.event_name
  , e.ksm_event
  , e.event_type
  , e.start_dt_calc
  , e.stop_dt_calc
  , e.start_fy_calc
  , e.stop_fy_calc
From v_nu_event_participants_fast e
Inner Join tmp_mv_hh hh
  On hh.id_number = e.id_number
;

-- Activities
Select
  hh.household_id
  , a.id_number
  , a.activity_desc
  , a.ksm_activity
  , a.activity_participation_code
  , a.start_dt
  , a.stop_dt
  , a.date_added
  , a.date_modified
  , a.start_fy_calc
  , a.stop_fy_calc
From v_nu_activities_fast a
Inner Join tmp_mv_hh hh
  On hh.id_number = a.id_number
;

--------------------
------ Giving ------
--------------------

-- NGC/Cash transactions (can include DAF flag)
Select
  hh.household_id
  , gt.tx_number
  , gt.tx_sequence
  , gt.transaction_type
  , gt.tx_gypm_ind
  , gt.associated_desc
  , gt.pledge_number
  , gt.matched_tx_number
  , gt.matched_fiscal_year
  , gt.payment_type
  , gt.alloc_short_name
  , gt.af_flag
  , gt.cru_flag
  , gt.proposal_id
  , gt.date_of_record
  , gt.fiscal_year
  , gt.legal_amount
  , gt.hh_recognition_credit
From tmp_mv_gt gt
Inner Join tmp_mv_hh hh
  On hh.id_number = gt.id_number
;

-- Pledge payment schedule
Select
  pay.payment_schedule_pledge_nbr
    As pledge_number
  , pp.prim_pledge_date_of_record
    As pledge_date
  , pp.prim_pledge_year_of_giving
    As pledge_fy
  , rpt_pbh634.ksm_pkg.to_date2(pay.payment_schedule_date)
    As payment_schedule_date
  , rpt_pbh634.ksm_pkg.get_fiscal_year(rpt_pbh634.ksm_pkg.to_date2(pay.payment_schedule_date))
    As payment_schedule_fy
  , pay.payment_schedule_amount
From payment_schedule pay
Inner Join primary_pledge pp
  On pp.prim_pledge_number = pay.payment_schedule_pledge_nbr
Inner Join (Select Distinct pledge_number From tmp_mv_gt) plg
  On plg.pledge_number = pay.payment_schedule_pledge_nbr
;

-- Gift clubs
Select
  hh.household_id
  , gct.club_description As gift_club
  , gc.gift_club_code
  , gc.gift_club_start_date
  , gc.gift_club_end_date
  , ksm_pkg.to_date2(gc.gift_club_start_date) As start_dt
  , ksm_pkg.to_date2(gc.gift_club_end_date) As stop_dt
  , gc.date_added
  , gc.date_modified
  , Case
      When substr(gc.gift_club_start_date, 1, 4) <> '0000'
        And substr(gc.gift_club_start_date, 5, 2) <> '00'
          Then to_number(substr(gc.gift_club_start_date, 1, 4)) +
            (Case When to_number(substr(gc.gift_club_start_date, 5, 2)) >= 9 Then 1 Else 0 End)
      When substr(gc.gift_club_start_date, 1, 4) <> '0000'
        Then to_number(substr(gc.gift_club_start_date, 1, 4))
      Else ksm_pkg.get_fiscal_year(gc.date_added)
      End
    As start_fy_calc
  , Case
      When substr(gc.gift_club_end_date, 1, 4) <> '0000'
        And substr(gc.gift_club_end_date, 5, 2) <> '00'
          Then to_number(substr(gc.gift_club_end_date, 1, 4)) +
            (Case When to_number(substr(gc.gift_club_end_date, 5, 2)) >= 9 Then 1 Else 0 End)
      When substr(gc.gift_club_end_date, 1, 4) <> '0000'
        Then to_number(substr(gc.gift_club_end_date, 1, 4))
      Else ksm_pkg.get_fiscal_year(gc.date_added)
      End
    As stop_fy_calc
  , Case
      When gc.gift_club_code = 'LKM'
        Then 'KSM' -- Kellogg Leadership Circle
      When gc.gift_club_code In ('028', 'AHR')
        Then 'BEQ' -- Rogers Society
      When gc.gift_club_code In ('NUL', 'INF')
        Then 'LOYAL' -- NU Loyal, Infinity
      Else 'LDR' -- Other leadership, e.g. NULC, Law, Feinberg, SESP, etc.
      End
    As gc_category
From gift_clubs gc
Inner Join tmp_mv_hh hh
  On hh.id_number = gc.gift_club_id_number
Inner Join gift_club_table gct
  On gct.club_code = gc.gift_club_code
Where gct.club_status = 'A' -- Only current gift clubs
;

--------------------
----- Prospect -----
--------------------

-- Evaluation
With
eval_with_id As (
  Select
    Case
      When trim(e.id_number) Is Not Null
        Then e.id_number
      Else prs_e.id_number
      End
      As id_number
    , e.evaluation_type
    , tet.short_desc
      As evaluation_desc
    , e.rating_code
    , trt.short_desc
      As rating_desc
    , Case
        When trt.rating_code = 0 -- Under $10K set to 100
          Then 100
        Else ksm_pkg.get_number_from_dollar(trt.short_desc)
        End
      As rating_numeric
    , trunc(e.evaluation_date)
      As eval_dt
  From evaluation e
  Left Join prospect_entity prs_e
    On prs_e.prospect_id = e.prospect_id
  Inner Join tms_rating trt
    On trt.rating_code = e.rating_code
  Inner Join tms_evaluation_type tet
    On tet.evaluation_type = e.evaluation_type
  Where e.evaluation_type In ('PR', 'UR')
)
Select Distinct
  hh.household_id
  , e.*
From eval_with_id e
Inner Join tmp_mv_hh hh
  On hh.id_number = e.id_number
;

-- Contact
Select
  hh.household_id
  , crf.credited_name
  , crf.contact_credit_type
  , crf.contact_credit_desc
  , crf.contact_date
  , crf.fiscal_year
  , crf.ard_staff
  , crf.frontline_ksm_staff
  , crf.contact_type_category
  , crf.visit_type
From v_contact_reports_fast crf
Inner Join tmp_mv_hh hh
  On hh.id_number = crf.id_number
;

-- Program interest
Select
  hh.household_id
  , prs.program_code
  , tp.short_desc
    As program
  , trunc(prs.start_date)
    As start_date
  , trunc(prs.stop_date)
    As stop_date
  , trunc(prs.date_added)
    As date_added
  , trunc(prs.date_modified)
    As date_modified
  , Case
      When prs.start_date Is Not Null
        Then rpt_pbh634.ksm_pkg.get_fiscal_year(prs.start_date)
      Else rpt_pbh634.ksm_pkg.get_fiscal_year(prs.date_added)
      End
    As start_fy_calc
  , Case
      When prs.stop_date Is Not Null
        Then rpt_pbh634.ksm_pkg.get_fiscal_year(prs.stop_date)
      When prs.active_ind = 'N'
        Then rpt_pbh634.ksm_pkg.get_fiscal_year(prs.date_modified)
      Else NULL
      End
    As stop_fy_calc
From program_prospect prs
Inner Join prospect_entity prs_e
  On prs_e.prospect_id = prs.prospect_id
Inner Join tmp_mv_hh hh
  On hh.id_number = prs_e.id_number
Inner Join tms_program tp
  On tp.program_code = prs.program_code
Where
  -- Active programs only
  tp.status_code = 'A'
;

-- Manager
Select
  hh.household_id
  , vah.assignment_type
  , vah.assignment_type_desc
  , vah.start_dt_calc
  , vah.stop_dt_calc
  , vah.assignment_report_name
  , vah.committee_desc
From v_assignment_history vah
Inner Join tmp_mv_hh hh
  On hh.id_number = vah.id_number
Where
  -- NU assignments
  vah.assignment_type In ('PM', 'PP', 'LG', 'AF')
;

--------------------
------ Biodata -----
--------------------

-- Employment
Select
  hh.household_id
  , e.start_dt
  , e.stop_dt
  , trunc(e.date_added)
    As date_added
  , trunc(e.date_modified)
    As date_modified
  , Case
      When e.start_dt Is Not Null
        And substr(e.start_dt, 1, 4) <> '0000'
        And substr(e.start_dt, 5, 2) <> '00'
          Then rpt_pbh634.ksm_pkg.get_fiscal_year(to_date(substr(e.start_dt, 1, 6) || '01', 'yyyymmdd'))
      Else rpt_pbh634.ksm_pkg.get_fiscal_year(e.date_added)
      End
    As start_fy_calc
  , Case
      When e.stop_dt Is Not Null
        And e.job_status_code Not In ('C', 'D')
        And substr(e.stop_dt, 1, 4) <> '0000'
        And substr(e.stop_dt, 5, 2) <> '00'
          Then rpt_pbh634.ksm_pkg.get_fiscal_year(to_date(substr(e.stop_dt, 1, 6) || '01', 'yyyymmdd'))
      When e.job_status_code Not In ('C', 'D')
        Then rpt_pbh634.ksm_pkg.get_fiscal_year(e.date_modified)
      Else NULL
      End
    As stop_fy_calc
  , e.job_status_code
  , e.job_title
  , trim(e.employer_name1 || ' ' || e.employer_name2)
    As employer_name
  , e.self_employ_ind
  , e.matching_status_ind
From employment e
Inner Join tmp_mv_hh hh
  On hh.id_number = e.id_number
Where e.employ_relat_code In ('PE', 'PF', 'SE') -- Primary, previous, secondary employer
;

-- Have email
Select
  hh.household_id
  , e.email_type_code
  , te.short_desc
    As email_type
  , e.email_status_code
  , trunc(e.status_change_date)
    As status_change_date
  , e.start_dt
  , e.stop_dt
  , trunc(e.date_added)
    As date_added
  , trunc(e.date_modified)
    As date_modified
  , Case
      When start_dt Is Not Null
        And substr(e.start_dt, 1, 4) <> '0000'
        And substr(e.start_dt, 5, 2) <> '00'
          Then rpt_pbh634.ksm_pkg.get_fiscal_year(to_date(substr(e.start_dt, 1, 6) || '01', 'yyyymmdd'))
      Else rpt_pbh634.ksm_pkg.get_fiscal_year(e.date_added)
      End
    As start_fy_calc
  , Case
      When e.stop_dt Is Not Null
        And e.email_status_code <> 'A'
        And substr(e.stop_dt, 1, 4) <> '0000'
        And substr(e.stop_dt, 5, 2) <> '00'
          Then rpt_pbh634.ksm_pkg.get_fiscal_year(to_date(substr(e.stop_dt, 1, 6) || '01', 'yyyymmdd'))
      When e.email_status_code <> 'A'
        Then rpt_pbh634.ksm_pkg.get_fiscal_year(e.date_modified)
      Else NULL
      End
    As stop_fy_calc
From email e
Inner Join tmp_mv_hh hh
  On hh.id_number = e.id_number
Inner Join tms_email_type te
  On te.email_type_code = e.email_type_code
Where e.email_type_code <> 'M' -- mismatch
;

-- Have phone
Select
  hh.household_id
  , t.telephone_type_code
  , tt.short_desc
    As telephone_type
  , tt.business_ind
  , tt.current_ind
  , t.telephone_status_code
  , t.start_dt
  , t.stop_dt
  , t.status_change_date
  , trunc(t.date_added)
    As date_added
  , trunc(t.date_modified)
    As date_modified
  , Case
      When t.start_dt Is Not Null
        And ksm_pkg.to_date2(t.start_dt) Is Not Null
          Then rpt_pbh634.ksm_pkg.get_fiscal_year(ksm_pkg.to_date2(substr(t.start_dt, 1, 6) || '01', 'yyyymmdd'))
      Else rpt_pbh634.ksm_pkg.get_fiscal_year(t.date_added)
      End
    As start_fy_calc
  , Case
      When t.stop_dt Is Not Null
        And t.telephone_status_code <> 'A'
        And ksm_pkg.to_date2(t.start_dt) Is Not Null
          Then rpt_pbh634.ksm_pkg.get_fiscal_year(ksm_pkg.to_date2(substr(t.stop_dt, 1, 6) || '01', 'yyyymmdd'))
      When t.telephone_status_code <> 'A'
        Then rpt_pbh634.ksm_pkg.get_fiscal_year(t.date_modified)
      Else NULL
      End
    As stop_fy_calc
From telephone t
Inner Join tmp_mv_hh hh
  On hh.id_number = t.id_number
Inner Join tms_telephone_type tt
  On tt.telephone_type_code = t.telephone_type_code
Where t.telephone_type_code In ('H', 'P', 'B', 'Q', 'M', 'PM') -- Home, Business, Mobile
;

-- Have address
Select
  hh.household_id
  , a.start_dt
  , a.stop_dt
  , trunc(a.date_added)
    As date_added
  , trunc(a.date_modified)
    As date_modified
  , a.addr_type_code
  , ta.short_desc
    As addr_type
  , ta.business_ind
  , ta.hbs_code
  , a.addr_status_code
  , Case
      When a.start_dt Is Not Null
        And substr(a.start_dt, 1, 4) <> '0000'
        And substr(a.start_dt, 5, 2) <> '00'
          Then rpt_pbh634.ksm_pkg.get_fiscal_year(to_date(substr(a.start_dt, 1, 6) || '01', 'yyyymmdd'))
      Else rpt_pbh634.ksm_pkg.get_fiscal_year(a.date_added)
      End
    As start_fy_calc
  , Case
      When a.stop_dt Is Not Null
        And a.addr_status_code <> 'A'
        And substr(a.stop_dt, 1, 4) <> '0000'
        And substr(a.stop_dt, 5, 2) <> '00'
          Then rpt_pbh634.ksm_pkg.get_fiscal_year(to_date(substr(a.stop_dt, 1, 6) || '01', 'yyyymmdd'))
      When a.addr_status_code <> 'A'
        Then rpt_pbh634.ksm_pkg.get_fiscal_year(a.date_modified)
      Else NULL
      End
    As stop_fy_calc
From address a
Inner Join tmp_mv_hh hh
  On hh.id_number = a.id_number
Inner Join tms_address_type ta
  On ta.addr_type_code = a.addr_type_code
Where a.addr_type_code In ('AB', 'AH', 'B', 'H', 'P', 'Q', 'R', 'S', 'T') -- Home, Bus, Alt Home, Alt Bus, Seasonal
;
