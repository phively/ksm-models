-- Not point-in-time!
Select
  household_id
  , household_rpt_name
  , degrees_concat
  , household_spouse_id
  , spouse_degrees_concat
  , household_record
  , person_or_org
  , household_ksm_year
  , household_masters_year
  , household_last_masters_year
  , household_program
  , household_program_group
From v_entity_ksm_households_fast
Where household_primary = 'Y'
