-- Not point-in-time!
Select
  hhf.household_id
  , hhf.household_rpt_name
  , hhf.degrees_concat
  , hhf.household_spouse_id
  , hhf.spouse_degrees_concat
  , hhf.household_record
  , hhf.person_or_org
  , hhf.household_ksm_year
  , ksm_pkg_tmp.to_date2(deg.first_ksm_grad_dt)
    As first_ksm_grad_dt
  , hhf.record_status_code
  , trunc(entity.status_change_date)
    As status_change_date
  , ksm_pkg_tmp.to_date2(entity.death_dt)
    As entity_death_dt
  , hhf.household_masters_year
  , hhf.household_last_masters_year
  , hhf.household_program
  , hhf.household_program_group
From v_entity_ksm_households_fast hhf
Inner Join entity
  On entity.id_number = hhf.id_number
Inner Join table(ksm_pkg_degrees.tbl_entity_degrees_concat_ksm) deg
  On deg.id_number = hhf.id_number
Where household_primary = 'Y'
  And degrees_concat Is Not Null
  And household_program_group <> 'NONGRD'
  And household_ksm_year > 1900
