With

/*************************
 Giving queries
*************************/

/* Current calendar */
cal As (
  Select *
  From v_current_calendar
),

/* Householded transactions */
giving_hh As (
  Select *
  From v_ksm_giving_trans_hh
),

/* First year of Kellogg giving */
ksm_giving_yr As (
  Select
    household_id
    , min(Case When hh_recognition_credit > 0 Then fiscal_year End) As first_year
  From giving_hh
  Group By household_id
),

/* Total lifetime giving transactions */
ksm_giving As (
  Select
    giving_hh.household_id
    , count(Distinct Case When hh_recognition_credit > 0 Then allocation_code End) As gifts_allocs_supported
    , count(Distinct Case When hh_recognition_credit > 0 Then fiscal_year End) As gifts_fys_supported
    , min(Case When hh_recognition_credit > 0 Then fiscal_year End) As giving_first_year
    , sum(Case When fiscal_year = ksm_giving_yr.first_year And tx_gypm_ind <> 'P'
        Then hh_recognition_credit End) As giving_first_year_cash_amt
    , sum(Case When fiscal_year = ksm_giving_yr.first_year And tx_gypm_ind = 'P'
        Then hh_recognition_credit End) As giving_first_year_pledge_amt
    , max(Case When tx_gypm_ind <> 'P' Then hh_recognition_credit End) As giving_max_cash_amt
    , max(Case When tx_gypm_ind = 'P' Then hh_recognition_credit End) As giving_max_pledge_amt 
    , sum(Case When tx_gypm_ind = 'P' Then 0 Else hh_recognition_credit End) As giving_cash_total
    , sum(Case When tx_gypm_ind = 'P' Then hh_recognition_credit Else 0 End) As giving_pledge_total
    , sum(Case When tx_gypm_ind <> 'Y' Then hh_recognition_credit Else 0 End) As giving_ngc_total
    , sum(Case When payment_type = 'Cash / Check' And tx_gypm_ind <> 'M' And hh_recognition_credit > 0 Then 1 End) As gifts_cash
    , sum(Case When payment_type = 'Credit Card' And tx_gypm_ind <> 'M' And hh_recognition_credit > 0 Then 1 End) As gifts_credit_card
    , sum(Case When payment_type = 'Securities' And tx_gypm_ind <> 'M' And hh_recognition_credit > 0 Then 1 End) As gifts_stock
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
  Left Join ksm_giving_yr On ksm_giving_yr.household_id = giving_hh.household_id
  Group By giving_hh.household_id
),

/*************************
Entity information
*************************/

/* KSM householding */
hh As (
  Select *
  From v_entity_ksm_households
),

/* Entity addresses */
addresses As (
  Select
    household_id
    , Listagg(addr_type_code, ', '
      ) Within Group (Order By addr_type_code Asc) As addr_types
  From address
  Inner Join hh On hh.id_number = address.id_number
  Where addr_status_code = 'A' -- Active addresses only
    And addr_type_code In ('H', 'B', 'AH', 'AB', 'S') -- Home, Bus, Alt Home, Alt Bus, Seasonal
  Group By household_id
),

/* Entity phone */
phones As (
  Select
    household_id
    , Listagg(telephone_type_code, ', '
      ) Within Group (Order By telephone_type_code Asc) As phone_types
  From telephone
  Inner Join hh On hh.id_number = telephone.id_number
  Where telephone_status_code = 'A' -- Active phone only
    And telephone_type_code In ('H', 'B', 'M') -- Home, Business, Mobile
  Group By household_id
),

/* Entity email */
emails As (
  Select
    household_id
    , Listagg(email_type_code, ', '
      ) Within Group (Order By email_type_code Asc) As email_types
  From email
  Inner Join hh On hh.id_number = email.id_number
  Where email_status_code = 'A' -- Active emails only
    And email_type_code In ('X', 'Y') -- Home, Business
  Group By household_id
),

/* Entity employment */
employer As (
  Select
    id_number
    , business_title
    , job_title
    , matching_status_ind
    , high_level_job_title
    , trim(fld_of_work || ' ' || fld_of_spec1 || ' ' || fld_of_spec2 || ' ' || fld_of_spec3) As career_specs
  From v_ksm_high_level_job_title
),

/* Employment aggregated to the household level */
employer_hh As (
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
),

/*************************
Prospect information
*************************/

/* Ever had a KSM program interest */
ksm_prs_ids As (
  Select Distinct
    hh.household_id
  From program_prospect prs
  Inner Join prospect_entity prs_e On prs_e.prospect_id = prs.prospect_id
  Inner Join hh On hh.id_number = prs_e.id_number
  Where prs.program_code = 'KM'
),

/* Active KSM prospect records */
ksm_prs_ids_active As (
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
),

/* Visits in last 5 FY */
recent_visits As (
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
),

/* Visits summary */
visits As (
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
),

/*************************
 Engagement information
*************************/

/* Athletics season tickets */
tickets As (
  Select
    hh.household_id
    , count(Distinct substr(stop_dt, 1, 4)) As athletics_ticket_years
    , max(Distinct substr(stop_dt, 1, 4)) As athletics_ticket_last
  From activity
  Inner Join hh On hh.id_number = activity.id_number
  Where activity_code In ('BBSEA', 'FBSEA')
  Group By hh.household_id
),

/* Committee data */
cmtee As (
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
    , c.start_dt
    , c.stop_dt
  From committee c
  Inner Join hh On hh.id_number = c.id_number
  Inner Join tms_committee_table tms_ct On tms_ct.committee_code = c.committee_code
  Inner Join tms_committee_status tms_cs On tms_cs.committee_status_code = c.committee_status_code
  Left Join tms_committee_role tms_r On tms_r.committee_role_code = c.committee_role_code
  Where c.committee_status_code In ('C', 'F', 'A', 'U') -- Current, Former, Active, Inactive; A/I for historic tracking
),

/* Committee summary */
cmtees As (
  Select
    household_id
    , count(Distinct committee_code) As committee_nu_distinct
    , count(Distinct Case When committee_status_code = 'C' Then committee_code Else NULL End) As committee_nu_active
    , count(Distinct Case When ksm_committee = 'Y' Then committee_code Else NULL End) As committee_ksm_distinct
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

/*************************
 Main query
*************************/

Select
  -- Identifiers
    hh.id_number
  , hh.report_name
  , hh.record_status_code
  , hh.household_record
  , hh.household_id
  , Case When hh.id_number = hh.household_id Then 'Y' Else 'N' End As hh_primary
  -- Biographic indicators
  , hh.institutional_suffix
  , hh.first_ksm_year
  , entity.birth_dt
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
  , ksm_giving.giving_max_cash_amt
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
  --, gift clubs in each of past 5 FY
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
  -- Engagement indicators
  , cmtees.committee_nu_distinct
  , cmtees.committee_nu_active
  , cmtees.committee_ksm_distinct
  , cmtees.committee_ksm_active
  , cmtees.committee_ksm_ldr
  , cmtees.committee_ksm_ldr_active
  --, number of FY on committees
  --, number of events attended
  --, ever attended Reunion
  --, number of FY attending events
  --, number of events as volunteer
  , tickets.athletics_ticket_years
  , tickets.athletics_ticket_last
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
Left Join cmtees On cmtees.household_id = hh.household_id
Left Join tickets On tickets.household_id = hh.household_id
-- Conditionals
Where
  -- Exclude organizations
  hh.person_or_org = 'P'
  -- Must be Kellogg alumni, donor, or past prospect
  And (
    hh.degrees_concat Is Not Null
    Or ksm_giving.giving_first_year Is Not Null
    Or ksm_prs_ids.household_id Is Not Null
  )
