With

daf As (
  Select Distinct
    tx_number
    , 'Y' As daf_assoc
  From nu_gft_trp_gifttrans
  Where associated_code = 'D'
)

, plg As (
  Select
    pledge_number
    , pledge_sequence
    , prim_pledge_type As pledge_type
    , prim_pledge_status
    , short_desc As pledge_status
    , status_change_date As pledge_status_change_dt
    , prim_pledge_original_amount As pledge_original_amount
  From table(rpt_pbh634.ksm_pkg_tmp.plg_discount) plgd
  Inner Join tms_pledge_status tps
    On tps.pledge_status_code = plgd.prim_pledge_status
)

Select
  household_id
  , gthh.tx_number
  , gthh.pledge_number
  , gthh.tx_gypm_ind
  , daf.daf_assoc
  , gthh.payment_type
  , gthh.allocation_code
  , trunc(gthh.date_of_record)
    As date_of_record
  , gthh.fiscal_year
  , gthh.hh_recognition_credit
  , gthh.legal_amount
  , Case
      When gthh.tx_gypm_ind In ('G', 'P', 'M')
        Then 'Y'
      End
    As ngc_flag
  , Case
      When gthh.tx_gypm_ind In ('G', 'Y', 'M')
        Then 'Y'
      End
    As cash_flag
  , gthh.af_flag
  , gthh.cru_flag
  , Case
      When gthh.transaction_type_code In ('BE', 'LE')
        Then 'Y'
      End
    As planned_gift_flag
  , plg.pledge_type
  , plg.pledge_status
  , plg.pledge_status_change_dt
  , plg.pledge_original_amount
From v_ksm_giving_trans_hh gthh
Left Join daf
  On daf.tx_number = gthh.tx_number
Left Join plg
  On plg.pledge_number = gthh.pledge_number
