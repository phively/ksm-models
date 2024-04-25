With

evals As (
  Select Distinct id_number
  From evaluation
  Where evaluation.evaluation_type In ('PR', 'UR') -- Prospect Research, UOR
    And trim(evaluation.id_number) Is Not Null
)

Select gt.*
From v_ksm_giving_trans gt
-- Alumni only
Inner Join v_entity_ksm_degrees deg
  On deg.id_number = gt.id_number
-- Rated only
Inner Join evals
  On evals.id_number = gt.id_number
-- NGC only
Where gt.tx_gypm_ind In ('G', 'P')
  And gt.recognition_credit > 0
