Create Or Replace View af_10k_model As

With

/*************************
 Giving queries
*************************/

/* Current calendar */
cal As (
  Select *
  From v_current_calendar
)

/* Householded transactions, summing together split allocations within the same receipt number */
, giving_hh As (
  Select
    household_id
    , tx_number
    , tx_gypm_ind
    , payment_type
    , allocation_code
    , trunc(date_of_record) As date_of_record
    , fiscal_year
    , hh_recognition_credit
  From v_ksm_giving_trans_hh
)
, giving_hh_amt As (
  Select
    household_id As hhid
    , tx_number As txn
    , sum(hh_recognition_credit) As hhrc
  From giving_hh
  Group By
    household_id
    , tx_number
)

/* First year of Kellogg giving */
, ksm_giving_yr As (
  Select
    household_id
    , min(Case When hh_recognition_credit > 0 Then fiscal_year End) As first_year
  From giving_hh
  Group By household_id
)

/* Total lifetime giving transactions */
, ksm_giving As (
  Select
    giving_hh.household_id
    , count(Distinct Case When hh_recognition_credit > 0 Then allocation_code End) As gifts_allocs_supported
    , count(Distinct Case When hh_recognition_credit > 0 Then fiscal_year End) As gifts_fys_supported
    , min(Case When hh_recognition_credit > 0 Then fiscal_year End) As giving_first_year
    -- First year giving
    , sum(Case When fiscal_year = ksm_giving_yr.first_year And tx_gypm_ind <> 'P'
        Then hh_recognition_credit End) As giving_first_year_cash_amt
    , sum(Case When fiscal_year = ksm_giving_yr.first_year And tx_gypm_ind = 'P'
        Then hh_recognition_credit End) As giving_first_year_pledge_amt
    , max(Case When tx_gypm_ind Not In ('P', 'M') Then hhrc End) As giving_max_cash_amt
    -- Take largest transaction, combining receipts into one amount. In event of a tie, take earliest date of record.
    , min(fiscal_year) keep(dense_rank First
        Order By (Case When tx_gypm_ind Not In ('P', 'M') Then hhrc Else 0 End) Desc, date_of_record Asc) As giving_max_cash_fy
    , min(date_of_record) keep(dense_rank First
        Order By (Case When tx_gypm_ind Not In ('P', 'M') Then hhrc Else 0 End) Desc, date_of_record Asc) As giving_max_cash_dt
    , max(Case When tx_gypm_ind = 'P' Then hhrc End) As giving_max_pledge_amt
    , min(fiscal_year) keep(dense_rank First
        Order By (Case When tx_gypm_ind = 'P' Then hhrc Else 0 End) Desc, date_of_record Asc) As giving_max_pledge_fy
    , min(date_of_record) keep(dense_rank First
        Order By (Case When tx_gypm_ind = 'P' Then hhrc Else 0 End) Desc, date_of_record Asc) As giving_max_pledge_dt
    -- Totals
    , sum(Case When tx_gypm_ind = 'P' Then 0 Else hh_recognition_credit End) As giving_cash_total
    , sum(Case When tx_gypm_ind = 'P' Then hh_recognition_credit Else 0 End) As giving_pledge_total
    , sum(Case When tx_gypm_ind <> 'Y' Then hh_recognition_credit Else 0 End) As giving_ngc_total
    , count(Distinct Case When payment_type = 'Cash / Check' And tx_gypm_ind <> 'M' And hh_recognition_credit > 0 Then tx_number End) As gifts_cash
    , count(Distinct Case When payment_type = 'Credit Card' And tx_gypm_ind <> 'M' And hh_recognition_credit > 0 Then tx_number End) As gifts_credit_card
    , count(Distinct Case When payment_type = 'Securities' And tx_gypm_ind <> 'M' And hh_recognition_credit > 0 Then tx_number End) As gifts_stock
    , sum(Case When tx_gypm_ind <> 'P' And fiscal_year = cal.curr_fy - 1 Then hh_recognition_credit End) As cash_pfy1
    , sum(Case When tx_gypm_ind <> 'P' And fiscal_year = cal.curr_fy - 2 Then hh_recognition_credit End) As cash_pfy2
    , sum(Case When tx_gypm_ind <> 'P' And fiscal_year = cal.curr_fy - 3 Then hh_recognition_credit End) As cash_pfy3
    , sum(Case When tx_gypm_ind <> 'P' And fiscal_year = cal.curr_fy - 4 Then hh_recognition_credit End) As cash_pfy4
    , sum(Case When tx_gypm_ind <> 'P' And fiscal_year = cal.curr_fy - 5 Then hh_recognition_credit End) As cash_pfy5
    , sum(Case When tx_gypm_ind <> 'Y' And fiscal_year = cal.curr_fy - 1 Then hh_recognition_credit End) As ngc_pfy1
    , sum(Case When tx_gypm_ind <> 'Y' And fiscal_year = cal.curr_fy - 2 Then hh_recognition_credit End) As ngc_pfy2
    , sum(Case When tx_gypm_ind <> 'Y' And fiscal_year = cal.curr_fy - 3 Then hh_recognition_credit End) As ngc_pfy3
    , sum(Case When tx_gypm_ind <> 'Y' And fiscal_year = cal.curr_fy - 4 Then hh_recognition_credit End) As ngc_pfy4
    , sum(Case When tx_gypm_ind <> 'Y' And fiscal_year = cal.curr_fy - 5 Then hh_recognition_credit End) As ngc_pfy5
  From giving_hh
  Cross Join cal
  Inner Join giving_hh_amt On giving_hh_amt.hhid = giving_hh.household_id
    And giving_hh_amt.txn = giving_hh.tx_number
  Left Join ksm_giving_yr On ksm_giving_yr.household_id = giving_hh.household_id
  Group By giving_hh.household_id
)

/*************************
Entity information
*************************/

/* KSM householding */
, hh As (
  Select *
  From v_entity_ksm_households
)

/* Entity addresses */
, addresses As (
  Select
    household_id
    , Listagg(addr_type_code, ', '
      ) Within Group (Order By addr_type_code Asc) As addr_types
  From address
  Inner Join hh On hh.id_number = address.id_number
  Where addr_status_code = 'A' -- Active addresses only
    And addr_type_code In ('H', 'B', 'AH', 'AB', 'S') -- Home, Bus, Alt Home, Alt Bus, Seasonal
  Group By household_id
)

/* Entity phone */
, phones As (
  Select
    household_id
    , Listagg(telephone_type_code, ', '
      ) Within Group (Order By telephone_type_code Asc) As phone_types
  From telephone
  Inner Join hh On hh.id_number = telephone.id_number
  Where telephone_status_code = 'A' -- Active phone only
    And telephone_type_code In ('H', 'B', 'M') -- Home, Business, Mobile
  Group By household_id
)

/* Entity email */
, emails As (
  Select
    household_id
    , Listagg(email_type_code, ', '
      ) Within Group (Order By email_type_code Asc) As email_types
  From email
  Inner Join hh On hh.id_number = email.id_number
  Where email_status_code = 'A' -- Active emails only
    And email_type_code In ('X', 'Y') -- Home, Business
  Group By household_id
)

/* Entity employment */
, employer As (
  Select
    id_number
    , business_title
    , job_title
    , matching_status_ind
    , high_level_job_title
    , trim(fld_of_work || ' ' || fld_of_spec1 || ' ' || fld_of_spec2 || ' ' || fld_of_spec3) As career_specs
  From v_ksm_high_level_job_title
)

/* Employment aggregated to the household level */
, employer_hh As (
  Select
    household_id
    , Listagg(trim(business_title || '; ' || job_title), ' // '
      ) Within Group (Order By employer.id_number Asc) As bus_title_string
    , Listagg(matching_status_ind, ' '
      ) Within Group (Order By employer.id_number Asc) As bus_gift_match
    , Listagg(high_level_job_title, '; '
      ) Within Group (Order By employer.id_number Asc) As bus_high_lvl_job_title
    , Listagg(career_specs, '; '
      ) Within Group (Order By employer.id_number Asc) As bus_career_specs
  From employer
  Inner Join hh On hh.id_number = employer.id_number
  Group By household_id
)

/*************************
Prospect information
*************************/

/* Ever had a KSM program interest */
, ksm_prs_ids As (
  Select Distinct
    hh.household_id
  From program_prospect prs
  Inner Join prospect_entity prs_e On prs_e.prospect_id = prs.prospect_id
  Inner Join hh On hh.id_number = prs_e.id_number
  Where prs.program_code = 'KM'
)

/* Active KSM prospect records */
, ksm_prs_ids_active As (
  Select Distinct
    hh.household_id
  From program_prospect prs
  Inner Join prospect_entity prs_e On prs_e.prospect_id = prs.prospect_id
  Inner Join hh On hh.id_number = prs_e.id_number
  Inner Join prospect On prs.prospect_id = prospect.prospect_id
  Inner Join entity on entity.id_number = prs_e.id_number
  Where prs.program_code = 'KM'
    -- Active only
    And prs.active_ind = 'Y'
    And prospect.active_ind = 'Y'
    -- Exclude deceased, purgable
    And entity.record_status_code Not In ('D', 'X')
    -- Exclude Disqualified, Permanent Stewardship
    And prs.stage_code Not In (7, 11)
    And prospect.stage_code Not In (7, 11)
)

/* Visits in last 5 FY */
, recent_visits As (
  Select
    hh.household_id
    , rpt_pbh634.ksm_pkg.get_fiscal_year(contact_report.contact_date) As fiscal_year
    , contact_report.report_id
    , trunc(contact_report.contact_date) As contact_date
    , contact_report.author_id_number
  From contact_report
  Inner Join hh On hh.id_number = contact_report.id_number
  Cross Join cal
  Where rpt_pbh634.ksm_pkg.get_fiscal_year(contact_report.contact_date) Between cal.curr_fy - 5 And cal.curr_fy - 1
    And contact_report.contact_type = 'V'
)

/* Visits summary */
, visits As (
  Select
    household_id
    -- Unique visits, max of 1 per day
    , count(Distinct Case When fiscal_year = cal.curr_fy - 1 Then contact_date Else NULL End) As visits_pfy1
    , count(Distinct Case When fiscal_year = cal.curr_fy - 2 Then contact_date Else NULL End) As visits_pfy2
    , count(Distinct Case When fiscal_year = cal.curr_fy - 3 Then contact_date Else NULL End) As visits_pfy3
    , count(Distinct Case When fiscal_year = cal.curr_fy - 4 Then contact_date Else NULL End) As visits_pfy4
    , count(Distinct Case When fiscal_year = cal.curr_fy - 5 Then contact_date Else NULL End) As visits_pfy5
    -- Unique visitors based on author
    , count(Distinct Case When fiscal_year = cal.curr_fy - 1 Then author_id_number Else NULL End) As visitors_pfy1
    , count(Distinct Case When fiscal_year = cal.curr_fy - 2 Then author_id_number Else NULL End) As visitors_pfy2
    , count(Distinct Case When fiscal_year = cal.curr_fy - 3 Then author_id_number Else NULL End) As visitors_pfy3
    , count(Distinct Case When fiscal_year = cal.curr_fy - 4 Then author_id_number Else NULL End) As visitors_pfy4
    , count(Distinct Case When fiscal_year = cal.curr_fy - 5 Then author_id_number Else NULL End) As visitors_pfy5
  From recent_visits
  Cross Join cal
  Group By household_id
)

/*************************
 Engagement information
*************************/

/* Gift clubs data */
, gc_dat As (
  Select
    hh.household_id
    , gc.gift_club_code
    , substr(gc.gift_club_start_date, 1, 4) As start_yr
    , substr(gc.gift_club_end_date, 1, 4) As stop_yr
    , Case
        When gc.gift_club_code = 'LKM' Then 'KSM' -- Kellogg Leadership Circle
        When gc.gift_club_code In ('028', 'AHR') Then 'BEQ' -- Rogers Society
        When gc.gift_club_code In ('NUL', 'INF') Then 'LOYAL' -- NU Loyal, Infinity
        Else 'LDR' -- Other leadership, e.g. NULC, Law, Feinberg, SESP, etc.
      End As gc_category
  From gift_clubs gc
  Inner Join hh On hh.id_number = gc.gift_club_id_number
  Inner Join gift_club_table gct On gct.club_code = gc.gift_club_code
  Where gct.club_status = 'A' -- Only currently active gift clubs
)

/* Gift clubs summary */
, gc_summary As (
  Select
    household_id
    , count(Distinct Case When gc_category = 'KSM' Then stop_yr Else NULL End) As gift_club_klc_yrs
    , count(Distinct Case When gc_category = 'BEQ' Then stop_yr Else NULL End) As gift_club_bequest_yrs
    , count(Distinct Case When gc_category = 'LOYAL' Then stop_yr Else NULL End) As gift_club_loyal_yrs
    , count(Distinct Case When gc_category In ('LDR', 'KSM') Then stop_yr Else NULL End) As gift_club_nu_ldr_yrs
  From gc_dat
  Group By household_id
)

/* Activities data */
, activities As (
  Select
    hh.household_id
    , activity_code
    , substr(start_dt, 1, 4) As start_yr
    , substr(stop_dt, 1, 4) As stop_yr
  From activity
  Inner Join hh On hh.id_number = activity.id_number
)

/* Activities summary */
, acts As (
  Select
    household_id
    -- Kellogg speakers
    , count(Distinct Case When activity_code = 'KSP' Then stop_yr Else NULL End) As ksm_speaker_years
    , count(Case When activity_code = 'KSP' Then stop_yr Else NULL End) As ksm_speaker_times
    -- Kellogg communications
    , count(Distinct Case When activity_code = 'KCF' Then stop_yr Else NULL End) As ksm_featured_comm_years
    , count(Case When activity_code = 'KCF' Then stop_yr Else NULL End) As ksm_featured_comm_times
    -- Kellogg corporate recruiter
    , count(Distinct Case When activity_code = 'KCR' Then stop_yr Else NULL End) As ksm_corp_recruiter_years
    , count(Case When activity_code = 'KCR' Then stop_yr Else NULL End) As ksm_corp_recruiter_times
    -- Season tickets for basketball and football (BBSEA, FBSEA)
    , count(Distinct Case When activity_code In ('BBSEA', 'FBSEA') Then stop_yr Else NULL End) As athletics_ticket_years
    , to_number(max(Distinct Case When activity_code In ('BBSEA', 'FBSEA') Then stop_yr Else NULL End)) As athletics_ticket_last
  From activities
  Group By household_id
)

/* Committee data */
, cmtee As (
  Select
    hh.household_id
    , c.committee_status_code
    , c.committee_code
    , tms_ct.short_desc As committee
    , c.committee_role_code
    , tms_r.short_desc As role
    , Case
        When (tms_ct.short_desc || ' ' || tms_ct.full_desc) Like '%KSM%' Then 'Y'
        When (tms_ct.short_desc || ' ' || tms_ct.full_desc) Like '%Kellogg%' Then 'Y'
      End As ksm_committee
    , substr(c.start_dt, 1, 4) As start_yr
    , substr(c.stop_dt, 1, 4) As stop_yr
  From committee c
  Inner Join hh On hh.id_number = c.id_number
  Inner Join tms_committee_table tms_ct On tms_ct.committee_code = c.committee_code
  Inner Join tms_committee_status tms_cs On tms_cs.committee_status_code = c.committee_status_code
  Left Join tms_committee_role tms_r On tms_r.committee_role_code = c.committee_role_code
  Where c.committee_status_code In ('C', 'F', 'A', 'U') -- Current, Former, Active, Inactive; A/I for historic tracking
)

/* Committee summary */
, cmtees As (
  Select
    household_id
    , count(Distinct committee_code) As committee_nu_distinct
    , count(Distinct Case When start_yr <> '0000' Then start_yr Else NULL End) As committee_nu_years
    , count(Distinct Case When committee_status_code = 'C' Then committee_code Else NULL End) As committee_nu_active
    , count(Distinct Case When ksm_committee = 'Y' Then committee_code Else NULL End) As committee_ksm_distinct
    , count(Distinct Case When ksm_committee = 'Y' And start_yr <> '0000' Then start_yr Else NULL End) As committee_ksm_years
    , count(Distinct Case When ksm_committee = 'Y' And committee_status_code = 'C' Then committee_code Else NULL End) As committee_ksm_active
    , count(Distinct
    Case
      When ksm_committee = 'Y' And committee_role_code In (
        'B', 'C', 'CC', 'CL', 'DAL', 'E', 'I', 'P', 'PE', 'RGD', 'T', 'TA', 'TC', 'TF', 'TL', 'TN', 'TO', 'V'
      ) Then committee_code
      When committee_code In (
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
      ) Then committee_code
      Else NULL
    End) As committee_ksm_ldr
  , count(Distinct
    Case
      When committee_status_code = 'C' And ksm_committee = 'Y' And committee_role_code In (
        'B', 'C', 'CC', 'CL', 'DAL', 'E', 'I', 'P', 'PE', 'RGD', 'T', 'TA', 'TC', 'TF', 'TL', 'TN', 'TO', 'V'
      ) Then committee_code
      When committee_status_code = 'C' And committee_code In (
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
      ) Then committee_code
      Else NULL
    End) As committee_ksm_ldr_active
  From cmtee
  Group By household_id
)

/* Kellogg event IDs */
, ksm_event_ids As (
  Select Distinct
    event.event_id
    , event.event_name
    , event.event_type
    , trunc(event.event_start_datetime) As start_dt
    , trunc(event.event_stop_datetime) As stop_dt
  From ep_event event
  Left Join ep_event_organizer evo On event.event_id = evo.event_id
  Left Join entity On entity.id_number = evo.organization_id
  Where event.master_event_id Is Null -- Do not count individual sub-events
    And (
      event.event_name Like '%KSM%'
      Or event.event_name Like '%Kellogg%'
      Or evo.organization_id = '0000697410' -- Kellogg Event Admin ID
      Or lower(entity.report_name) Like lower('%Kellogg%') -- Kellogg club event organizers
    )
)

/* Events data */
, event_dat As (
  Select Distinct
    hh.household_id
    , ksm_event_ids.event_id
    , ksm_event_ids.event_name
    , tms_et.short_desc As event_type
    , extract(year from ksm_event_ids.start_dt) As start_yr
    , extract(year from ksm_event_ids.stop_dt) As stop_yr
  From ep_participant ppt
  Inner Join ksm_event_ids On ksm_event_ids.event_id = ppt.event_id -- KSM events
  Inner Join hh On hh.id_number = ppt.id_number
  Inner Join ep_participation ppn On ppn.registration_id = ppt.registration_id
  Left Join tms_event_type tms_et On tms_et.event_type = ksm_event_ids.event_type
  Where ppn.participation_status_code In (' ', 'P') -- Blank or Participated
)

/* Events summary */
, ksm_events As (
  Select
    household_id
    , count(Distinct event_id) As ksm_events_attended
    , count(Distinct start_yr) As ksm_events_yrs
    , count(Distinct Case When start_yr Between cal.curr_fy - 3 And cal.curr_fy - 1 Then event_id Else NULL End) As ksm_events_prev_3_fy
    , count(Distinct Case When event_type = 'Reunion' Or event_name Like '%Reunion%' Then start_yr Else NULL End) As ksm_events_reunions
  From event_dat
  Cross Join cal
  Group By household_id
)

/*************************
 Main query
*************************/

Select
  rownum As rn
  -- Identifiers
  , hh.id_number
  , hh.report_name
  , hh.record_status_code
  , hh.household_record
  , hh.household_id
  , Case When hh.id_number = hh.household_id Then 'Y' Else 'N' End As hh_primary
  -- Biographic indicators
  , hh.institutional_suffix
  , hh.first_ksm_year
  , entity.birth_dt
  , trunc(entity.date_added) As entity_dt_added
  , hh.degrees_concat
  , trim(hh.program_group) As program_group
  , hh.spouse_first_ksm_year
  , hh.spouse_suffix
  , entity.pref_addr_type_code
  , hh.household_city
  , hh.household_state
  , hh.household_country
  , hh.household_continent
  , Case When employer_hh.bus_title_string Is Not Null And employer_hh.bus_title_string Not In (';', '; // ;')
    Then 'Y' Else 'N' End As bus_is_employed
  , Case When employer_hh.bus_title_string Not In (';', '; // ;')
    Then employer_hh.bus_title_string End As bus_title_string
  , employer_hh.bus_high_lvl_job_title
  , employer_hh.bus_career_specs
  , Case When employer_hh.bus_career_specs Like '%Bank%'
      Or employer_hh.bus_career_specs Like '%Financ%'
      Or employer_hh.bus_career_specs Like '%Invest%'
      Then 'Y'
    End As bus_career_spec_finance
  , Case When employer_hh.bus_gift_match Like '%Y%' Then 'Y' Else 'N' End As bus_gift_match
  -- Contact indicators
  , Case When addresses.addr_types Like '%H%' Then 'Y' Else 'N' End As has_home_addr
  , Case When addresses.addr_types Like '%AH%' Then 'Y' Else 'N' End As has_alt_home_addr
  , Case When addresses.addr_types Like '%B%' Then 'Y' Else 'N' End As has_bus_addr
  , Case When addresses.addr_types Like '%S%' Then 'Y' Else 'N' End As has_seasonal_addr
  , Case When phones.phone_types Like '%H%' Then 'Y' Else 'N' End As has_home_phone
  , Case When phones.phone_types Like '%B%' Then 'Y' Else 'N' End As has_bus_phone
  , Case When phones.phone_types Like '%M%' Then 'Y' Else 'N' End As has_mobile_phone
  , Case When emails.email_types Like '%X%' Then 'Y' Else 'N' End As has_home_email
  , Case When emails.email_types Like '%Y%' Then 'Y' Else 'N' End As has_bus_email
  -- Giving indicators
  , ksm_giving.giving_first_year
  , ksm_giving.giving_first_year_cash_amt
  , ksm_giving.giving_first_year_pledge_amt
  , Case When ksm_giving.giving_max_cash_amt Is Not Null Then ksm_giving.giving_max_cash_fy End As giving_max_cash_fy
  , Case When ksm_giving.giving_max_cash_amt Is Not Null Then ksm_giving.giving_max_cash_dt End As giving_max_cash_dt
  , ksm_giving.giving_max_cash_amt
  , Case When ksm_giving.giving_max_pledge_amt Is Not Null Then ksm_giving.giving_max_pledge_fy End As giving_max_pledge_fy
  , Case When ksm_giving.giving_max_pledge_amt Is Not Null Then ksm_giving.giving_max_pledge_dt End As giving_max_pledge_dt
  , ksm_giving.giving_max_pledge_amt
  , ksm_giving.giving_cash_total
  , ksm_giving.giving_pledge_total
  , ksm_giving.giving_ngc_total
  , ksm_giving.gifts_allocs_supported
  , ksm_giving.gifts_fys_supported
  , ksm_giving.gifts_cash
  , ksm_giving.gifts_credit_card
  , ksm_giving.gifts_stock
  -- Recent giving
  , ksm_giving.cash_pfy1
  , ksm_giving.cash_pfy2
  , ksm_giving.cash_pfy3
  , ksm_giving.cash_pfy4
  , ksm_giving.cash_pfy5
  , ksm_giving.ngc_pfy1
  , ksm_giving.ngc_pfy2
  , ksm_giving.ngc_pfy3
  , ksm_giving.ngc_pfy4
  , ksm_giving.ngc_pfy5
  -- Gift clubs
  , gc_summary.gift_club_klc_yrs
  , gc_summary.gift_club_bequest_yrs
  , gc_summary.gift_club_loyal_yrs
  , gc_summary.gift_club_nu_ldr_yrs
  -- Prospect indicators
  , prs.evaluation_rating
  , Case When ksm_prs_ids_active.household_id Is Not Null Then 'Y' End As ksm_prospect_active
  , Case When ksm_prs_ids.household_id Is Not Null Then 'Y' End As ksm_prospect_any
  , visits.visits_pfy1
  , visits.visits_pfy2
  , visits.visits_pfy3
  , visits.visits_pfy4
  , visits.visits_pfy5
  , visits.visitors_pfy1
  , visits.visitors_pfy2
  , visits.visitors_pfy3
  , visits.visitors_pfy4
  , visits.visitors_pfy5
  -- Committee indicators
  , cmtees.committee_nu_distinct
  , cmtees.committee_nu_active
  , cmtees.committee_nu_years
  , cmtees.committee_ksm_distinct
  , cmtees.committee_ksm_active
  , cmtees.committee_ksm_years
  , cmtees.committee_ksm_ldr
  , cmtees.committee_ksm_ldr_active
  -- Event indicators
  , ksm_events.ksm_events_attended
  , ksm_events.ksm_events_yrs
  , ksm_events.ksm_events_prev_3_fy
  , ksm_events.ksm_events_reunions
  -- Activity indicators
  , acts.ksm_speaker_years
  , acts.ksm_speaker_times
  , acts.ksm_featured_comm_years
  , acts.ksm_featured_comm_times
  , acts.ksm_corp_recruiter_years
  , acts.ksm_corp_recruiter_times
  , acts.athletics_ticket_years
  , acts.athletics_ticket_last
From hh
Inner Join entity On entity.id_number = hh.id_number
-- Giving
Left Join ksm_giving On ksm_giving.household_id = hh.household_id
-- Entity
Left Join addresses On addresses.household_id = hh.household_id
Left Join phones On phones.household_id = hh.household_id
Left Join emails On emails.household_id = hh.household_id
Left Join employer_hh On employer_hh.household_id = hh.household_id
-- Prospect
Left Join nu_prs_trp_prospect prs On prs.id_number = hh.id_number
Left Join ksm_prs_ids On ksm_prs_ids.household_id = hh.household_id
Left Join ksm_prs_ids_active On ksm_prs_ids_active.household_id = hh.household_id
Left Join visits On visits.household_id = hh.household_id
-- Engagement
Left Join gc_summary On gc_summary.household_id = hh.household_id
Left Join cmtees On cmtees.household_id = hh.household_id
Left Join acts On acts.household_id = hh.household_id
Left Join ksm_events On ksm_events.household_id = hh.household_id
-- Conditionals
Where
  -- Exclude organizations
  hh.person_or_org = 'P'
  -- No inactive or purgable records
  And hh.record_status_code Not In ('I', 'X')
  -- Must be Kellogg alumni, donor, or past prospect
  And (
    hh.degrees_concat Is Not Null
    Or ksm_giving.giving_first_year Is Not Null
    Or ksm_prs_ids.household_id Is Not Null
  )
