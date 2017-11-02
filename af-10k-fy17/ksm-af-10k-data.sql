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
  --, count of NU committees
  --, count of KSM committees
  --, GAB indicator
  --, Trustee indicator (careful, endogenous)
  --, Reunion indicator
  --, Club Leader indicator
  --, number of FY on committees
  --, number of events attended
  --, number of FY attending events
  --, ever attended Reunion
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
Where
  -- Exclude organizations
  hh.person_or_org = 'P'
  -- Must be Kellogg alumni or donor
  And (
    hh.degrees_concat Is Not Null
    Or ksm_giving.giving_first_year Is Not Null
  )
