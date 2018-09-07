With

planned_gifts As (
Select
  transaction_type_code
  , short_desc
From tms_transaction_type
Where short_desc Like '%Bequest%'
  Or short_desc Like '%Insurance%'
Union
Select
  pledge_type_code
  , short_desc
From tms_pledge_type
Where short_desc Like '%Bequest%'
  Or short_desc Like '%Insurance%'
)

Select
  id_number
  , short_desc As planned_giving
  , sum(credited_amount) As credit
From nu_rpt_t_cmmt_dtl_daily daily
Inner Join planned_gifts
  On planned_gifts.transaction_type_code = daily.transaction_type
Group By
  id_number
  , short_desc
