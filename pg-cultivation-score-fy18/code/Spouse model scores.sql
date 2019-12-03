With

mg As (
  Select *
  From v_ksm_model_mg
)

Select
  hh.household_id
  , hh.household_primary
  , hh.report_name
  , hh.household_spouse_rpt_name
  , hh.id_number As own_id_number
  , mg.*
From v_entity_ksm_households hh
Inner Join mg
  On hh.household_id = mg.id_number
Where hh.record_status_code <> 'D'
