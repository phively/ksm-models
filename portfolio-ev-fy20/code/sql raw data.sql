-- Alumni table
Select *
From v_entity_ksm_degrees
;

-- Committees
Select c.*
From v_nu_committees c
Inner Join v_entity_ksm_degrees deg
  On deg.id_number = c.id_number
;
