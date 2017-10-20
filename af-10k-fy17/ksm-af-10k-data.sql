With

/*************************
 Giving queries
*************************/

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
  From giving_hh
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
  --, pref addr continent
  , Case When addresses.addr_types Like '%H%' Then 'Y' Else 'N' End As has_home_addr
  , Case When addresses.addr_types Like '%B%' Then 'Y' Else 'N' End As has_bus_addr
  , Case When addresses.addr_types Like '%S%' Then 'Y' Else 'N' End As has_seasonal_addr
  --, has pref phone
  --, has pref email
  --, special handling?
  --, high-level business title
  --, high-income career specialty
  --, company has matching program
  --, citizenship continent?
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
  -- Prospect indicators
  --, research capacity rating (careful, endogenous)
  --, active prospect record (careful, endogenous)
  --, inactive prospect record (careful, endogenous)
  --, count of visits with NU
  --, count of visits with KSM
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
Left Join ksm_giving On ksm_giving.household_id = hh.household_id
Left Join addresses On addresses.household_id = hh.household_id
Where
  -- Exclude organizations
  hh.person_or_org = 'P'
  -- Must be Kellogg alumni or donor
  And (
    hh.degrees_concat Is Not Null
    Or ksm_giving.giving_first_year Is Not Null
  )
