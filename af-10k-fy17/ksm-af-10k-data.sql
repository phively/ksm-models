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
        Then hh_recognition_credit End) As giving_first_cash_amount
    , sum(Case When fiscal_year = ksm_giving_yr.first_year And tx_gypm_ind = 'P'
        Then hh_recognition_credit End) As giving_first_pledge_amount
    , sum(Case When tx_gypm_ind = 'P' Then NULL Else hh_recognition_credit End) As giving_cash_total
    , sum(Case When tx_gypm_ind = 'P' And pledge_status Not In ('I', 'R') -- Exclude inactive and reconciliation
        Then hh_recognition_credit Else NULL End) As giving_pledge_total
    , sum(Case When (tx_gypm_ind = 'P' And pledge_status Not In ('I', 'R')) Or tx_gypm_ind In ('G', 'M')
        Then hh_recognition_credit Else NULL End) As giving_ngc_total
    , sum(Case When payment_type = 'Cash / Check' And tx_gypm_ind <> 'M' Then 1 End) As gifts_cash
    , sum(Case When payment_type = 'Credit Card' And tx_gypm_ind <> 'M' Then 1 End) As gifts_credit_card
    , sum(Case When payment_type = 'Securities' And tx_gypm_ind <> 'M' Then 1 End) As gifts_stock
  From giving_hh
  Left Join ksm_giving_yr On ksm_giving_yr.household_id = giving_hh.household_id
  Group By giving_hh.household_id
)

/*************************
 Main query
*************************/

Select
  -- Identifiers
    hh.id_number
  , hh.report_name
  , hh.record_status_code
  , hh.household_id
  , Case When hh.id_number = hh.household_id Then 'Y' Else 'N' End As hh_primary
  -- Dependent variables
  --, dependent variable -- ever made a $10K gift
  --, dependent variable -- ever made a $100K gift
  -- Biographic indicators
  --, alum flag
  --, class year
  --, age
  --, program
  --, program group
  --, spouse indicator: married, NU, KSM?
  --, pref addr type code
  --, pref addr IL indicator
  --, pref addr USA indicator
  --, pref addr continent
  --, has home addr
  --, has bus addr
  --, has seasonal addr
  --, has pref phone
  --, has pref email
  --, special handling?
  --, high-level business title
  --, high-income career specialty
  --, company has matching program
  --, citizenship continent?
  -- Giving indicators
  , ksm_giving.giving_first_year
  , ksm_giving.giving_first_cash_amount
  , ksm_giving.giving_first_pledge_amount
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
  --, number of events attended
  --, ever attended Reunion
From v_entity_ksm_households hh
Left Join ksm_giving On ksm_giving.household_id = hh.household_id
