With

/*************************
 Giving queries
*************************/

/* First year of Kellogg giving */
ksm_giving_yr As (
  Select
    id_number
    , min(Case When recognition_credit > 0 Then fiscal_year End) As first_year
  From v_ksm_giving_trans
  Group By id_number
),

/* Total lifetime giving transactions */
ksm_giving As (
  Select
    v.id_number
    , count(Distinct Case When recognition_credit > 0 Then allocation_code End) As gifts_allocs_supported
    , count(Distinct Case When recognition_credit > 0 Then fiscal_year End) As gifts_fys_supported
    , min(Case When recognition_credit > 0 Then fiscal_year End) As giving_first_year
    , sum(Case When fiscal_year = ksm_giving_yr.first_year And tx_gypm_ind <> 'P'
        Then recognition_credit End) As giving_first_cash_amount
    , sum(Case When fiscal_year = ksm_giving_yr.first_year And tx_gypm_ind = 'P'
        Then recognition_credit End) As giving_first_pledge_amount
    , sum(Case When tx_gypm_ind = 'P' Then NULL Else recognition_credit End) As giving_cash_total
    , sum(Case When tx_gypm_ind = 'P' And pledge_status Not In ('I', 'R') -- Exclude inactive and reconciliation
        Then recognition_credit Else NULL End) As giving_pledge_total
    , sum(Case When (tx_gypm_ind = 'P' And pledge_status Not In ('I', 'R')) Or tx_gypm_ind In ('G', 'M')
        Then recognition_credit Else NULL End) As giving_ngc_total
    , sum(Case When payment_type = 'Cash / Check' And tx_gypm_ind <> 'M' Then 1 End) As gifts_cash
    , sum(Case When payment_type = 'Credit Card' And tx_gypm_ind <> 'M' Then 1 End) As gifts_credit_card
    , sum(Case When payment_type = 'Securities' And tx_gypm_ind <> 'M' Then 1 End) As gifts_stock
  From v_ksm_giving_trans v
  Left Join ksm_giving_yr On ksm_giving_yr.id_number = v.id_number
  Group By v.id_number
)

/*************************
 Main query
*************************/

Select
  -- Identifiers
    entity.id_number
  , entity.report_name
  , entity.record_status_code
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
From entity
Left Join ksm_giving On ksm_giving.id_number = entity.id_number
