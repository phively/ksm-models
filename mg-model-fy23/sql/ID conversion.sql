Select
  hhf.household_id
  , hhf.id_number
  , pe.prospect_id
From v_entity_ksm_households_fast hhf
Left Join prospect_entity pe
  On pe.id_number = hhf.id_number
