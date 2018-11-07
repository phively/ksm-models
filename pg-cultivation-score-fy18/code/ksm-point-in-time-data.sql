Create Table point_in_time_model As

With

-- N.B. work in progress as of 2018-10-12

/*************************
Parameters
*************************/
params As (
  Select
    2016 As training_fy
    , 2017 As target_fy1
    , 2018 As target_fy2
  From DUAL
)

/*************************
 Giving queries
*************************/

/* Current calendar */
, cal As (
  Select *
  From v_current_calendar
)

/* Householded transactions, summing together split allocations within the same receipt number */
, daf As (
  Select Distinct
    tx_number
    , 'Y' As daf_assoc
  From nu_gft_trp_gifttrans
  Where associated_code = 'D'
)
-- No need to make point-in-time
, giving_hh As (
  Select
    household_id
    , gthh.tx_number
    , gthh.pledge_number
    , tx_gypm_ind
    , daf.daf_assoc
    , payment_type
    , allocation_code
    , trunc(date_of_record)
      As date_of_record
    , fiscal_year
    , hh_recognition_credit
    , legal_amount
  From v_ksm_giving_trans_hh gthh
  Left Join daf
    On daf.tx_number = gthh.tx_number
)
, giving_hh_amt As (
  Select
    household_id As hhid
    , tx_number As txn
    , sum(hh_recognition_credit)
      As hhrc
  From giving_hh
  Group By
    household_id
    , tx_number
)
, planned_gifts As (
  Select
    tx_number
    , sum(legal_amount)
      As nu_planned_giving
  From nu_gft_trp_gifttrans
  Cross Join params
  Where transaction_type In ('BE', 'LE')
    And fiscal_year  <= training_fy
  Group By tx_number
)
, pit_plg_payments As (
  Select
    pledge_number
    , tx_gypm_ind
    , sum(legal_amount)
      As future_amt
  From giving_hh
  Cross Join params
  Where fiscal_year > training_fy -- Future pledge payments need to be added into balance
    And tx_gypm_ind = 'Y'
  Group By
    pledge_number
    , tx_gypm_ind
)
, pit_pledge_bal As (
  Select Distinct
    household_id
    , sum(plgd.prim_pledge_remaining_balance + nvl(pit_plg_payments.future_amt, 0))
      As pledge_balance
    , sum(planned_gifts.nu_planned_giving)
      As nu_planned_giving
  From table(ksm_pkg.plg_discount) plgd
  Cross Join params
  Inner Join giving_hh
    On giving_hh.tx_number = plgd.pledge_number
    And hh_recognition_credit > 0
  Left Join pit_plg_payments
    On pit_plg_payments.pledge_number = plgd.pledge_number
  Left Join planned_gifts
    On planned_gifts.tx_number = plgd.pledge_number
  Where fiscal_year <= training_fy
    And pledge_amount > 0
  Group By household_id
)

/* First year of Kellogg giving */
, ksm_giving_yr As (
  Select
    household_id
    , min(Case When hh_recognition_credit > 0 Then fiscal_year End)
      As first_year
  From giving_hh
  Cross Join params
  -- Point-in-time
  Where fiscal_year <= training_fy
  Group By household_id
)

/* Total lifetime giving transactions */
, ksm_giving As (
  Select
    giving_hh.household_id
    -- Point-in-time
    , count(Distinct Case When hh_recognition_credit > 0 And fiscal_year <= training_fy
        Then allocation_code End)
      As gifts_allocs_supported
    , count(Distinct Case When hh_recognition_credit > 0 And fiscal_year <= training_fy
        Then fiscal_year End)
      As gifts_fys_supported
    , min(ksm_giving_yr.first_year)
      As giving_first_year
    , count(Case When fiscal_year <= training_fy Then daf_assoc End)
      As daf_gifts
    , sum(Case When daf_assoc = 'Y' And fiscal_year <= training_fy
        Then hh_recognition_credit Else 0 End)
      As daf_gifts_amt
    , min(pit_pledge_bal.pledge_balance)
      As pledge_balance
    , min(pit_pledge_bal.nu_planned_giving)
      As nu_planned_giving
    -- First year giving
    , sum(Case When fiscal_year = ksm_giving_yr.first_year And tx_gypm_ind <> 'P'
        Then hh_recognition_credit End)
      As giving_first_year_cash_amt
    , sum(Case When fiscal_year = ksm_giving_yr.first_year And tx_gypm_ind = 'P'
        Then hh_recognition_credit End)
      As giving_first_year_pledge_amt
    , max(Case When tx_gypm_ind Not In ('P', 'M') And fiscal_year <= training_fy
        Then hhrc End)
      As giving_max_cash_amt
    -- Take largest transaction, combining receipts into one amount. In event of a tie, take earliest date of record.
    , min(fiscal_year) keep(dense_rank First
        Order By (Case When tx_gypm_ind Not In ('P', 'M') And fiscal_year <= training_fy
          Then hhrc Else 0 End) Desc, date_of_record Desc)
      As giving_max_cash_fy
    , min(date_of_record) keep(dense_rank First
        Order By (Case When tx_gypm_ind Not In ('P', 'M') And fiscal_year <= training_fy
          Then hhrc Else 0 End) Desc, date_of_record Desc)
      As giving_max_cash_dt
    , max(Case When tx_gypm_ind = 'P' And fiscal_year <= training_fy
        Then hhrc End)
      As giving_max_pledge_amt
    , min(fiscal_year) keep(dense_rank First
        Order By (Case When tx_gypm_ind = 'P' And fiscal_year <= training_fy
          Then hhrc Else 0 End) Desc, date_of_record Desc)
      As giving_max_pledge_fy
    , min(date_of_record) keep(dense_rank First
        Order By (Case When tx_gypm_ind = 'P' And fiscal_year <= training_fy
          Then hhrc Else 0 End) Desc, date_of_record Desc)
      As giving_max_pledge_dt
    -- Totals
    , sum(Case When tx_gypm_ind <> 'P' And fiscal_year <= training_fy
        Then hh_recognition_credit Else 0 End)
      As giving_cash_total
    , sum(Case When tx_gypm_ind = 'P' And fiscal_year <= training_fy
        Then hh_recognition_credit Else 0 End)
      As giving_pledge_total
    , sum(Case When tx_gypm_ind <> 'Y' And fiscal_year <= training_fy
        Then hh_recognition_credit Else 0 End)
      As giving_ngc_total
    , count(Distinct Case When payment_type = 'Cash / Check' And tx_gypm_ind <> 'M'
        And hh_recognition_credit > 0 And fiscal_year <= training_fy
          Then tx_number End)
      As gifts_cash
    , count(Distinct Case When payment_type = 'Credit Card' And tx_gypm_ind <> 'M'
        And hh_recognition_credit > 0 And fiscal_year <= training_fy
          Then tx_number End)
      As gifts_credit_card
    , count(Distinct Case When payment_type = 'Securities' And tx_gypm_ind <> 'M'
        And hh_recognition_credit > 0 And fiscal_year <= training_fy
          Then tx_number End)
      As gifts_stock
    , sum(Case When tx_gypm_ind <> 'P' And fiscal_year = target_fy2
        Then hh_recognition_credit End)
      As cash_target_fy2
    , sum(Case When tx_gypm_ind <> 'P' And fiscal_year = target_fy1
        Then hh_recognition_credit End)
      As cash_target_fy1
    , sum(Case When tx_gypm_ind <> 'P' And fiscal_year = training_fy
        Then hh_recognition_credit End)
      As cash_pfy1
    , sum(Case When tx_gypm_ind <> 'P' And fiscal_year = training_fy - 1
        Then hh_recognition_credit End)
      As cash_pfy2
    , sum(Case When tx_gypm_ind <> 'P' And fiscal_year = training_fy - 2
        Then hh_recognition_credit End)
      As cash_pfy3
    , sum(Case When tx_gypm_ind <> 'P' And fiscal_year = training_fy - 3
        Then hh_recognition_credit End)
      As cash_pfy4
    , sum(Case When tx_gypm_ind <> 'P' And fiscal_year = training_fy - 4
        Then hh_recognition_credit End)
      As cash_pfy5
    , sum(Case When tx_gypm_ind <> 'Y' And fiscal_year = target_fy2
        Then hh_recognition_credit End)
      As ngc_target_fy2
    , sum(Case When tx_gypm_ind <> 'Y' And fiscal_year = target_fy1
        Then hh_recognition_credit End)
      As ngc_target_fy1
    , sum(Case When tx_gypm_ind <> 'Y' And fiscal_year = training_fy
        Then hh_recognition_credit End)
      As ngc_pfy1
    , sum(Case When tx_gypm_ind <> 'Y' And fiscal_year = training_fy - 1
        Then hh_recognition_credit End)
      As ngc_pfy2
    , sum(Case When tx_gypm_ind <> 'Y' And fiscal_year = training_fy - 2
        Then hh_recognition_credit End)
      As ngc_pfy3
    , sum(Case When tx_gypm_ind <> 'Y' And fiscal_year = training_fy - 3
        Then hh_recognition_credit End)
      As ngc_pfy4
    , sum(Case When tx_gypm_ind <> 'Y' And fiscal_year = training_fy - 4
        Then hh_recognition_credit End)
      As ngc_pfy5
  From giving_hh
  Cross Join cal
  Cross Join params
  Inner Join giving_hh_amt
    On giving_hh_amt.hhid = giving_hh.household_id
    And giving_hh_amt.txn = giving_hh.tx_number
  Left Join ksm_giving_yr
    On ksm_giving_yr.household_id = giving_hh.household_id
  Left Join pit_pledge_bal
    On pit_pledge_bal.household_id = giving_hh.household_id
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
, address_dt As (
  Select
    id_number
    , start_dt
    , stop_dt
    , date_added
    , date_modified
    , addr_type_code
    , addr_status_code
    , Case
        When start_dt Is Not Null
          And substr(start_dt, 1, 4) <> '0000'
          And substr(start_dt, 5, 2) <> '00'
            Then rpt_pbh634.ksm_pkg.get_fiscal_year(to_date(substr(start_dt, 1, 6) || '01', 'yyyymmdd'))
        Else rpt_pbh634.ksm_pkg.get_fiscal_year(date_added)
        End
      As start_fy_calc
    , Case
        When stop_dt Is Not Null
          And addr_status_code <> 'A'
          And substr(stop_dt, 1, 4) <> '0000'
          And substr(stop_dt, 5, 2) <> '00'
            Then rpt_pbh634.ksm_pkg.get_fiscal_year(to_date(substr(stop_dt, 1, 6) || '01', 'yyyymmdd'))
        When addr_status_code <> 'A'
          Then rpt_pbh634.ksm_pkg.get_fiscal_year(date_modified)
        Else NULL
        End
      As stop_fy_calc
  From address
  Where addr_type_code In ('H', 'B', 'AH', 'AB', 'S') -- Home, Bus, Alt Home, Alt Bus, Seasonal
)
, pit_address As (
  Select
    id_number
    , addr_type_code
    , addr_status_code
    , start_dt
    , stop_dt
    , date_added
    , date_modified
    , start_fy_calc
    , stop_fy_calc
    , Case
        -- Address must be active during the training period
        When start_fy_calc <= training_fy
          Then Case
            -- Still active
            When stop_fy_calc Is Null
              Then 'Y'
            When addr_status_code = 'A'
              Then 'Y'
            -- Point-in-time active
            When stop_fy_calc > training_fy
              Then 'Y'
            End
        End
      As was_active
  From address_dt
  Cross Join params
)
, addresses As (
  Select
    household_id
    , Listagg(addr_type_code, ', ') Within Group (Order By addr_type_code Asc)
      As addr_types
  From pit_address
  Inner Join hh
    On hh.id_number = pit_address.id_number
  Where was_active = 'Y' -- Point-in-time
  Group By household_id
)

/* Entity phone */
, phones_dt As (
  Select
    id_number
    , telephone_type_code
    , telephone_status_code
    , start_dt
    , stop_dt
    , status_change_date
    , date_added
    , date_modified
    , Case
        When start_dt Is Not Null
          And substr(start_dt, 1, 4) <> '0000'
          And substr(start_dt, 5, 2) <> '00'
            Then rpt_pbh634.ksm_pkg.get_fiscal_year(to_date(substr(start_dt, 1, 6) || '01', 'yyyymmdd'))
        Else rpt_pbh634.ksm_pkg.get_fiscal_year(date_added)
        End
      As start_fy_calc
    , Case
        When stop_dt Is Not Null
          And telephone_status_code <> 'A'
          And substr(stop_dt, 1, 4) <> '0000'
          And substr(stop_dt, 5, 2) <> '00'
            Then rpt_pbh634.ksm_pkg.get_fiscal_year(to_date(substr(stop_dt, 1, 6) || '01', 'yyyymmdd'))
        When telephone_status_code <> 'A'
          Then rpt_pbh634.ksm_pkg.get_fiscal_year(date_modified)
        Else NULL
        End
      As stop_fy_calc
  From telephone
  Where telephone_type_code In ('H', 'B', 'M') -- Home, Business, Mobile
)
, pit_phones As (
  Select
    id_number
    , telephone_type_code
    , telephone_status_code
    , start_dt
    , stop_dt
    , status_change_date
    , date_added
    , date_modified
    , start_fy_calc
    , stop_fy_calc
    , Case
        -- Phone must be active during the training period
        When start_fy_calc <= training_fy
          Then Case
            -- Still active
            When stop_fy_calc Is Null
              Then 'Y'
            When telephone_status_code = 'A'
              Then 'Y'
            -- Point-in-time active
            When stop_fy_calc > training_fy
              Then 'Y'
            End
        End
      As was_active
  From phones_dt
  Cross Join params
)
, phones As (
  Select
    household_id
    , Listagg(telephone_type_code, ', ') Within Group (Order By telephone_type_code Asc)
      As phone_types
  From pit_phones
  Inner Join hh
    On hh.id_number = pit_phones.id_number
  Where was_active = 'Y' -- Active point-in-time phone only
  Group By household_id
)

/* Entity email */
, email_dts As (
  Select
    id_number
    , email_type_code
    , email_status_code
    , status_change_date
    , start_dt
    , stop_dt
    , date_added
    , date_modified
    , Case
        When start_dt Is Not Null
          And substr(start_dt, 1, 4) <> '0000'
          And substr(start_dt, 5, 2) <> '00'
            Then rpt_pbh634.ksm_pkg.get_fiscal_year(to_date(substr(start_dt, 1, 6) || '01', 'yyyymmdd'))
        Else rpt_pbh634.ksm_pkg.get_fiscal_year(date_added)
        End
      As start_fy_calc
    , Case
        When stop_dt Is Not Null
          And email_status_code <> 'A'
          And substr(stop_dt, 1, 4) <> '0000'
          And substr(stop_dt, 5, 2) <> '00'
            Then rpt_pbh634.ksm_pkg.get_fiscal_year(to_date(substr(stop_dt, 1, 6) || '01', 'yyyymmdd'))
        When email_status_code <> 'A'
          Then rpt_pbh634.ksm_pkg.get_fiscal_year(date_modified)
        Else NULL
        End
      As stop_fy_calc
  From email
  Where email_type_code In ('X', 'Y') -- Home, Business
)
, pit_email As (
    Select
    id_number
    , email_type_code
    , email_status_code
    , start_dt
    , stop_dt
    , date_added
    , date_modified
    , start_fy_calc
    , stop_fy_calc
    , Case
        -- Address must be active during the training period
        When start_fy_calc <= training_fy
          Then Case
            -- Still active
            When stop_fy_calc Is Null
              Then 'Y'
            When email_status_code = 'A'
              Then 'Y'
            -- Point-in-time active
            When stop_fy_calc > training_fy
              Then 'Y'
            End
        End
      As was_active
  From email_dts
  Cross Join params
)
, emails As (
  Select
    household_id
    , Listagg(email_type_code, ', ') Within Group (Order By email_type_code Asc)
      As email_types
  From pit_email
  Inner Join hh
    On hh.id_number = pit_email.id_number
  Where was_active = 'Y' -- Point-in-time active
  Group By household_id
)

/* Employment aggregated to the household level */
, employer_dts As (
    Select
    id_number
    , start_dt
    , stop_dt
    , date_added
    , date_modified
    , Case
        When start_dt Is Not Null
          And substr(start_dt, 1, 4) <> '0000'
          And substr(start_dt, 5, 2) <> '00'
            Then rpt_pbh634.ksm_pkg.get_fiscal_year(to_date(substr(start_dt, 1, 6) || '01', 'yyyymmdd'))
        Else rpt_pbh634.ksm_pkg.get_fiscal_year(date_added)
        End
      As start_fy_calc
    , Case
        When stop_dt Is Not Null
          And job_status_code Not In ('C', 'D')
          And substr(stop_dt, 1, 4) <> '0000'
          And substr(stop_dt, 5, 2) <> '00'
            Then rpt_pbh634.ksm_pkg.get_fiscal_year(to_date(substr(stop_dt, 1, 6) || '01', 'yyyymmdd'))
        When job_status_code Not In ('C', 'D')
          Then rpt_pbh634.ksm_pkg.get_fiscal_year(date_modified)
        Else NULL
        End
      As stop_fy_calc
    , job_status_code
    , job_title
    , trim(employer_name1 || ' ' || employer_name2)
      As employer_name
    , self_employ_ind
    , matching_status_ind
  From employment
  Where employ_relat_code In ('PE', 'PF', 'SE') -- Primary, previous, secondary employer
)
, pit_employer As (
  Select Distinct
    id_number
    , Case
        -- Address must be active during the training period
        When start_fy_calc <= training_fy
          Then Case
            -- Still active
            When stop_fy_calc Is Null
              Then 'Y'
            When job_status_code In ('C', 'D')
              Then 'Y'
            -- Point-in-time active
            When stop_fy_calc > training_fy
              Then 'Y'
            End
        End
      As was_active
  From employer_dts
  Cross Join params
)
, pit_bus_addr As (
  Select
    household_id
    , 'Y' As was_active
  From addresses
  Where addr_types Like '%B%'
)
, employer_hh As (
  Select
    hh.household_id
    , 'Y' As bus_is_employed
  From hh
  Left Join pit_employer
    On pit_employer.id_number = hh.id_number
  Left Join pit_bus_addr
    On pit_bus_addr.household_id = hh.household_id
  Where pit_employer.was_active = 'Y'
    Or pit_bus_addr.was_active = 'Y'
  Group By hh.household_id
)

/*************************
Prospect information
*************************/

/* Ever had a KSM program interest */
, prs_dt As (
    Select
    prs.prospect_id
    , prs_e.id_number
    , prs.active_ind As program_active_ind
    , prospect.active_ind As prospect_active_ind
    , prs.start_date
    , prs.stop_date
    , prs.date_added
    , prs.date_modified
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
  Inner Join prospect
    On prospect.prospect_id = prs.prospect_id
  Where prs.program_code = 'KM'
)
, ksm_prs_ids As (
  Select Distinct
    hh.household_id
  From prs_dt
  Inner Join hh
    On hh.id_number = prs_dt.id_number
  Cross Join params
  Where start_fy_calc <= training_fy
)

/* Active KSM prospect records */
, ksm_prs_ids_active As (
  Select Distinct
    hh.household_id
  From prs_dt
  Cross Join params
  Inner Join hh
    On hh.id_number = prs_dt.id_number
  Where start_fy_calc <= training_fy
    -- Can't see historical prospect status; use stop_fy_calc as a substitute
    And (
      stop_fy_calc Is Null
      Or stop_fy_calc > training_fy
    )
)

/* Visits in last 5 FY */
, recent_visits As (
  Select
    hh.household_id
    , rpt_pbh634.ksm_pkg.get_fiscal_year(contact_report.contact_date)
      As fiscal_year
    , contact_report.report_id
    , trunc(contact_report.contact_date)
      As contact_date
    , contact_report.author_id_number
  From contact_report
  Inner Join hh
    On hh.id_number = contact_report.id_number
  Cross Join params
  Where rpt_pbh634.ksm_pkg.get_fiscal_year(contact_report.contact_date) Between training_fy - 4 And training_fy
    And contact_report.contact_type = 'V'
)

/* Visits summary */
, visits As (
  Select
    household_id
    -- Unique visits, max of 1 per day
    , count(Distinct Case When fiscal_year = training_fy     Then contact_date Else NULL End)
      As visits_cfy
    , count(Distinct Case When fiscal_year = training_fy - 1 Then contact_date Else NULL End)
      As visits_pfy1
    , count(Distinct Case When fiscal_year = training_fy - 2 Then contact_date Else NULL End)
      As visits_pfy2
    , count(Distinct Case When fiscal_year = training_fy - 3 Then contact_date Else NULL End)
      As visits_pfy3
    , count(Distinct Case When fiscal_year = training_fy - 4 Then contact_date Else NULL End)
      As visits_pfy4
    -- Unique visitors based on author
    , count(Distinct Case When fiscal_year = training_fy     Then author_id_number Else NULL End)
      As visitors_cfy
    , count(Distinct Case When fiscal_year = training_fy - 1 Then author_id_number Else NULL End)
      As visitors_pfy1
    , count(Distinct Case When fiscal_year = training_fy - 2 Then author_id_number Else NULL End)
      As visitors_pfy2
    , count(Distinct Case When fiscal_year = training_fy - 3 Then author_id_number Else NULL End)
      As visitors_pfy3
    , count(Distinct Case When fiscal_year = training_fy - 4 Then author_id_number Else NULL End)
      As visitors_pfy4
  From recent_visits
  Cross Join params
  Group By household_id
)

/*************************
 Engagement information
*************************/

/* Gift clubs data */
, gc_dat As (
  Select
    hh.household_id
    , gct.club_description
    , gc.gift_club_code
    , gc.gift_club_start_date As start_dt
    , gc.gift_club_end_date As stop_dt
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
  Cross Join params
  Inner Join hh
    On hh.id_number = gc.gift_club_id_number
  Inner Join gift_club_table gct
    On gct.club_code = gc.gift_club_code
  Where gct.club_status = 'A' -- Only currently active gift clubs
)

/* Gift clubs summary */
, gc_summary As (
  Select
    household_id
    , count(Distinct Case When gc_category = 'KSM' Then stop_fy_calc Else NULL End)
      As gift_club_klc_yrs
    , count(Distinct Case When gc_category = 'BEQ' Then stop_fy_calc Else NULL End)
      As gift_club_bequest_yrs
    , count(Distinct Case When gc_category = 'LOYAL' Then stop_fy_calc Else NULL End)
      As gift_club_loyal_yrs
    , count(Distinct Case When gc_category In ('LDR', 'KSM') Then stop_fy_calc Else NULL End)
      As gift_club_nu_ldr_yrs
    , sum(Case When training_fy     Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As gift_clubs_cfy
    , sum(Case When training_fy - 1 Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As gift_clubs_pfy1
    , sum(Case When training_fy - 2 Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As gift_clubs_pfy2
    , sum(Case When training_fy - 3 Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As gift_clubs_pfy3
    , sum(Case When training_fy - 4 Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As gift_clubs_pfy4
  From gc_dat
  Cross Join params
  Where start_fy_calc <= training_fy
  Group By household_id
)

/* Activities data */
, activities As (
  Select
    hh.household_id
    , activity_code
    , start_dt
    , stop_dt
    , Case
        When substr(start_dt, 1, 4) <> '0000'
          And substr(start_dt, 5, 2) <> '00'
            Then to_number(substr(start_dt, 1, 4)) +
              (Case When to_number(substr(start_dt, 5, 2)) >= 9 Then 1 Else 0 End)
        When substr(start_dt, 1, 4) <> '0000'
          Then to_number(substr(start_dt, 1, 4))
        Else ksm_pkg.get_fiscal_year(date_added)
        End
      As start_fy_calc
    , Case
        When substr(stop_dt, 1, 4) <> '0000'
          And substr(stop_dt, 5, 2) <> '00'
            Then to_number(substr(stop_dt, 1, 4)) +
              (Case When to_number(substr(stop_dt, 5, 2)) >= 9 Then 1 Else 0 End)
        When substr(stop_dt, 1, 4) <> '0000'
          Then to_number(substr(stop_dt, 1, 4))
        Else ksm_pkg.get_fiscal_year(date_added) -- Intentionally not date_modified; assume activity is only that year
        End
      As stop_fy_calc
  From activity
  Inner Join hh
    On hh.id_number = activity.id_number
)

/* Activities summary */
, acts As (
  Select
    household_id
    -- Kellogg speakers
    , count(Distinct Case When activity_code = 'KSP' Then stop_fy_calc Else NULL End)
      As ksm_speaker_years
    , count(Case When activity_code = 'KSP' Then stop_fy_calc Else NULL End)
      As ksm_speaker_times
    -- Kellogg communications
    , count(Distinct Case When activity_code = 'KCF' Then stop_fy_calc Else NULL End)
      As ksm_featured_comm_years
    , count(Case When activity_code = 'KCF' Then stop_fy_calc Else NULL End)
      As ksm_featured_comm_times
    -- Kellogg corporate recruiter
    , count(Distinct Case When activity_code = 'KCR' Then stop_fy_calc Else NULL End)
      As ksm_corp_recruiter_years
    , count(Case When activity_code = 'KCR' Then stop_fy_calc Else NULL End)
      As ksm_corp_recruiter_times
    -- Season tickets for basketball and football (BBSEA, FBSEA)
    , count(Distinct Case When activity_code In ('BBSEA', 'FBSEA') Then stop_fy_calc Else NULL End)
      As athletics_ticket_years
    , to_number(max(Distinct Case When activity_code In ('BBSEA', 'FBSEA') Then stop_fy_calc Else NULL End))
      As athletics_ticket_last
    -- Yearly summary
    , sum(Case When training_fy     Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As activities_cfy
    , sum(Case When training_fy - 1 Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As activities_pfy1
    , sum(Case When training_fy - 2 Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As activities_pfy2
    , sum(Case When training_fy - 3 Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As activities_pfy3
    , sum(Case When training_fy - 4 Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As activities_pfy4
  From activities
  Cross Join params
  Where start_fy_calc <= training_fy
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
        When (tms_ct.short_desc || ' ' || tms_ct.full_desc) Like '%KSM%'
          Then 'Y'
        When (tms_ct.short_desc || ' ' || tms_ct.full_desc) Like '%Kellogg%'
          Then 'Y'
        End
      As ksm_committee
    , c.start_dt
    , c.stop_dt
    , c.date_added
    , c.date_modified
    , Case
        When substr(c.start_dt, 1, 4) <> '0000'
          And substr(c.start_dt, 5, 2) <> '00'
            Then to_number(substr(c.start_dt, 1, 4)) +
              (Case When to_number(substr(c.start_dt, 5, 2)) >= 9 Then 1 Else 0 End)
        When substr(c.start_dt, 1, 4) <> '0000'
          Then to_number(substr(c.start_dt, 1, 4))
        Else ksm_pkg.get_fiscal_year(c.date_added)
        End
      As start_fy_calc
    , Case
        When substr(c.stop_dt, 1, 4) <> '0000'
          And substr(c.stop_dt, 5, 2) <> '00'
            Then to_number(substr(c.stop_dt, 1, 4)) +
              (Case When to_number(substr(c.stop_dt, 5, 2)) >= 9 Then 1 Else 0 End)
        When substr(c.stop_dt, 1, 4) <> '0000'
          Then to_number(substr(c.stop_dt, 1, 4))
        When c.committee_status_code = 'C' -- Assume current status is through the date entered
          Then ksm_pkg.get_fiscal_year(c.date_modified)
        Else ksm_pkg.get_fiscal_year(c.date_added) -- Assume non-current status was one year only
        End
      As stop_fy_calc
  From committee c
  Inner Join hh
    On hh.id_number = c.id_number
  Inner Join tms_committee_table tms_ct
    On tms_ct.committee_code = c.committee_code
  Inner Join tms_committee_status tms_cs
    On tms_cs.committee_status_code = c.committee_status_code
  Left Join tms_committee_role tms_r
    On tms_r.committee_role_code = c.committee_role_code
  Where c.committee_status_code In ('C', 'F', 'A', 'U') -- Current, Former, Active, Inactive; A/I for historic tracking
    And c.committee_role_code Not In ('EF') -- Our NU Follower
)

/* Committee summary */
, cmtees As (
  Select
    household_id
    , count(Distinct committee_code)
      As committee_nu_distinct
    , count(Distinct stop_fy_calc)
      As committee_nu_years
    , count(Distinct Case When committee_status_code = 'C' Then committee_code Else NULL End)
      As committee_nu_active
    , count(Distinct Case When ksm_committee = 'Y' Then committee_code Else NULL End)
      As committee_ksm_distinct
    , count(Distinct Case When ksm_committee = 'Y' Then stop_fy_calc Else NULL End)
      As committee_ksm_years
    , count(Distinct Case When ksm_committee = 'Y' And committee_status_code = 'C' Then committee_code Else NULL End)
      As committee_ksm_active
    , count(Distinct
        Case
          When ksm_committee = 'Y'
            And committee_role_code In (
              'B', 'C', 'CC', 'CL', 'DAL', 'E', 'I', 'P', 'PE', 'RGD', 'T', 'TA', 'TC', 'TF', 'TL', 'TN', 'TO', 'V'
            )
            Then committee_code
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
          )
            Then committee_code
          Else NULL
        End)
      As committee_ksm_ldr
  , count(Distinct
      Case
        When committee_status_code = 'C'
          And ksm_committee = 'Y'
          And committee_role_code In (
            'B', 'C', 'CC', 'CL', 'DAL', 'E', 'I', 'P', 'PE', 'RGD', 'T', 'TA', 'TC', 'TF', 'TL', 'TN', 'TO', 'V'
          )
            Then committee_code
        When committee_status_code = 'C'
          And committee_code In (
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
            Then committee_code
        Else NULL
      End)
      As committee_ksm_ldr_active
    -- Yearly summary
    , sum(Case When training_fy     Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As committees_cfy
    , sum(Case When training_fy - 1 Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As committees_pfy1
    , sum(Case When training_fy - 2 Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As committees_pfy2
    , sum(Case When training_fy - 3 Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As committees_pfy3
    , sum(Case When training_fy - 4 Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As committees_pfy4
  From cmtee
  Cross Join params
  Where cmtee.start_fy_calc <= training_fy
  Group By household_id
)

/* All event IDs */
, event_ids As (
  Select Distinct
    event.event_id
    , event.event_name
    , event.event_type
    , trunc(event.event_start_datetime)
      As start_dt
    , trunc(event.event_stop_datetime)
      As stop_dt
    -- Assume events are one day, so if stop or start date is missing, use the other 
    -- If both are missing could fall back to date added (noisy) or omit
    , ksm_pkg.get_fiscal_year(
        Case
          When event.event_start_datetime Is Not Null
            Then trunc(event.event_start_datetime)
          When event.event_stop_datetime Is Not Null
            Then trunc(event.event_stop_datetime)
          End
      )
      As start_fy_calc
    , ksm_pkg.get_fiscal_year(
        Case
          When event.event_stop_datetime Is Not Null
            Then trunc(event.event_stop_datetime)
          When event.event_start_datetime Is Not Null
            Then trunc(event.event_start_datetime)
          End
      )
      As stop_fy_calc
    , Case
        When event.event_name Like '%KSM%'
          Or event.event_name Like '%Kellogg%'
          Or evo.organization_id = '0000697410' -- Kellogg Event Admin ID
          Or lower(entity.report_name) Like lower('%Kellogg%') -- Kellogg club event organizers
          Then 'Y'
        End
      As ksm_event
  From ep_event event
  Left Join ep_event_organizer evo
    On event.event_id = evo.event_id
  Left Join entity
    On entity.id_number = evo.organization_id
  Where event.master_event_id Is Null -- Do not count individual sub-events
)

/* Events data */
, event_dat As (
  Select Distinct
    hh.household_id
    , event_ids.event_id
    , event_ids.event_name
    , event_ids.ksm_event
    , tms_et.short_desc As event_type
    , start_fy_calc
    , stop_fy_calc
  From ep_participant ppt
  Cross Join params
  Inner Join event_ids
    On event_ids.event_id = ppt.event_id -- KSM events
  Inner Join hh
    On hh.id_number = ppt.id_number
  Inner Join ep_participation ppn
    On ppn.registration_id = ppt.registration_id
  Left Join tms_event_type tms_et
    On tms_et.event_type = event_ids.event_type
  Where ppn.participation_status_code In (' ', 'P', 'A') -- Blank, Participated, or Accepted
)

/* Events summary */
, nu_events As (
  Select
    household_id
    , count(event_id)
      As events_attended
    , count(start_fy_calc)
      As events_yrs
    , count(Distinct Case When start_fy_calc Between training_fy - 2 And training_fy Then event_id Else NULL End)
      As events_prev_3_fy
    , count(Distinct Case When ksm_event = 'Y' Then event_id End)
      As ksm_events_attended
    , count(Distinct Case When ksm_event = 'Y' Then start_fy_calc End)
      As ksm_events_yrs
    , count(Distinct Case When ksm_event = 'Y' And start_fy_calc Between training_fy - 2 And training_fy Then event_id Else NULL End)
      As ksm_events_prev_3_fy
    , count(Distinct Case When ksm_event = 'Y' And (event_type = 'Reunion' Or event_name Like '%Reunion%') Then start_fy_calc Else NULL End)
      As ksm_events_reunions
    -- Yearly summary
    , sum(Case When training_fy     Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As events_cfy
    , sum(Case When training_fy - 1 Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As events_pfy1
    , sum(Case When training_fy - 2 Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As events_pfy2
    , sum(Case When training_fy - 3 Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As events_pfy3
    , sum(Case When training_fy - 4 Between start_fy_calc And stop_fy_calc Then 1 Else 0 End)
      As events_pfy4
  From event_dat
  Cross Join params
  Where start_fy_calc <= training_fy
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
  , Case When hh.id_number = hh.household_id Then 'Y' Else 'N' End
    As hh_primary
  -- Biographic indicators
  , hh.institutional_suffix
  , hh.first_ksm_year
  , entity.birth_dt
  , trunc(entity.date_added)
    As entity_dt_added
  , hh.degrees_concat
  , trim(hh.program_group)
    As program_group
  , hh.spouse_first_ksm_year
  , hh.spouse_suffix
  , entity.pref_addr_type_code
  , hh.household_city
  , hh.household_state
  , hh.household_country
  , hh.household_continent
  , employer_hh.bus_is_employed
  -- Contact indicators
  , Case When addresses.addr_types Like '%H%' Then 'Y' Else 'N' End
    As has_home_addr
  , Case When addresses.addr_types Like '%AH%' Then 'Y' Else 'N' End
    As has_alt_home_addr
  , Case When addresses.addr_types Like '%B%' Then 'Y' Else 'N' End
    As has_bus_addr
  , Case When addresses.addr_types Like '%S%' Then 'Y' Else 'N' End
    As has_seasonal_addr
  , Case When phones.phone_types Like '%H%' Then 'Y' Else 'N' End
    As has_home_phone
  , Case When phones.phone_types Like '%B%' Then 'Y' Else 'N' End
    As has_bus_phone
  , Case When phones.phone_types Like '%M%' Then 'Y' Else 'N' End
    As has_mobile_phone
  , Case When emails.email_types Like '%X%' Then 'Y' Else 'N' End
    As has_home_email
  , Case When emails.email_types Like '%Y%' Then 'Y' Else 'N' End
    As has_bus_email
  -- Giving indicators
  , ksm_giving.giving_first_year
  , ksm_giving.giving_first_year_cash_amt
  , ksm_giving.giving_first_year_pledge_amt
  , Case When ksm_giving.giving_max_cash_amt Is Not Null Then ksm_giving.giving_max_cash_fy End
    As giving_max_cash_fy
  , Case When ksm_giving.giving_max_cash_amt Is Not Null Then ksm_giving.giving_max_cash_dt End
    As giving_max_cash_dt
  , ksm_giving.giving_max_cash_amt
  , Case When ksm_giving.giving_max_pledge_amt Is Not Null Then ksm_giving.giving_max_pledge_fy End
    As giving_max_pledge_fy
  , Case When ksm_giving.giving_max_pledge_amt Is Not Null Then ksm_giving.giving_max_pledge_dt End
    As giving_max_pledge_dt
  , ksm_giving.giving_max_pledge_amt
  , ksm_giving.giving_cash_total
  , ksm_giving.giving_pledge_total
  , ksm_giving.giving_ngc_total
  , ksm_giving.gifts_allocs_supported
  , ksm_giving.gifts_fys_supported
  , ksm_giving.gifts_cash
  , ksm_giving.gifts_credit_card
  , ksm_giving.gifts_stock
  , ksm_giving.daf_gifts
  , ksm_giving.daf_gifts_amt
  , ksm_giving.pledge_balance
  , ksm_giving.nu_planned_giving
  -- Recent giving
  , ksm_giving.cash_target_fy2
  , ksm_giving.cash_target_fy1
  , ksm_giving.cash_pfy1
  , ksm_giving.cash_pfy2
  , ksm_giving.cash_pfy3
  , ksm_giving.cash_pfy4
  , ksm_giving.cash_pfy5
  , ksm_giving.ngc_target_fy2
  , ksm_giving.ngc_target_fy1
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
  , gc_summary.gift_clubs_cfy
  , gc_summary.gift_clubs_pfy1
  , gc_summary.gift_clubs_pfy2
  , gc_summary.gift_clubs_pfy3
  , gc_summary.gift_clubs_pfy4
  -- Prospect indicators
  , prs.evaluation_rating
  , Case When ksm_prs_ids_active.household_id Is Not Null Then 'Y' End
    As ksm_prospect_active
  , Case When ksm_prs_ids.household_id Is Not Null Then 'Y' End
    As ksm_prospect_any
  , visits.visits_cfy
  , visits.visits_pfy1
  , visits.visits_pfy2
  , visits.visits_pfy3
  , visits.visits_pfy4
  , visits.visitors_cfy
  , visits.visitors_pfy1
  , visits.visitors_pfy2
  , visits.visitors_pfy3
  , visits.visitors_pfy4
  -- Committee indicators
  , cmtees.committee_nu_distinct
  , cmtees.committee_nu_active
  , cmtees.committee_nu_years
  , cmtees.committee_ksm_distinct
  , cmtees.committee_ksm_active
  , cmtees.committee_ksm_years
  , cmtees.committee_ksm_ldr
  , cmtees.committee_ksm_ldr_active
  , cmtees.committees_cfy
  , cmtees.committees_pfy1
  , cmtees.committees_pfy2
  , cmtees.committees_pfy3
  , cmtees.committees_pfy4
  -- Event indicators
  , nu_events.events_attended
  , nu_events.events_yrs
  , nu_events.events_prev_3_fy
  , nu_events.ksm_events_attended
  , nu_events.ksm_events_yrs
  , nu_events.ksm_events_prev_3_fy
  , nu_events.ksm_events_reunions
  , nu_events.events_cfy
  , nu_events.events_pfy1
  , nu_events.events_pfy2
  , nu_events.events_pfy3
  , nu_events.events_pfy4
  -- Activity indicators
  , acts.ksm_speaker_years
  , acts.ksm_speaker_times
  , acts.ksm_featured_comm_years
  , acts.ksm_featured_comm_times
  , acts.ksm_corp_recruiter_years
  , acts.ksm_corp_recruiter_times
  , acts.athletics_ticket_years
  , acts.athletics_ticket_last
  , acts.activities_cfy
  , acts.activities_pfy1
  , acts.activities_pfy2
  , acts.activities_pfy3
  , acts.activities_pfy4
From hh
Inner Join entity
  On entity.id_number = hh.id_number
-- Giving
Left Join ksm_giving
  On ksm_giving.household_id = hh.household_id
-- Entity
Left Join addresses
  On addresses.household_id = hh.household_id
Left Join phones
  On phones.household_id = hh.household_id
Left Join emails
  On emails.household_id = hh.household_id
Left Join employer_hh
  On employer_hh.household_id = hh.household_id
-- Prospect
Left Join nu_prs_trp_prospect prs
  On prs.id_number = hh.id_number
Left Join ksm_prs_ids
  On ksm_prs_ids.household_id = hh.household_id
Left Join ksm_prs_ids_active
  On ksm_prs_ids_active.household_id = hh.household_id
Left Join visits
  On visits.household_id = hh.household_id
-- Engagement
Left Join gc_summary
  On gc_summary.household_id = hh.household_id
Left Join cmtees
  On cmtees.household_id = hh.household_id
Left Join acts
  On acts.household_id = hh.household_id
Left Join nu_events
  On nu_events.household_id = hh.household_id
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
