With

ratings As (
  Select
    evaluation.evaluation_id
    -- If prospect record, fill in one UOR per associated id_number
    , Case
        When trim(evaluation.id_number) Is Not Null
          Then evaluation.id_number
        Else pe.id_number
        End
      As id_number
    , evaluation.prospect_id
    , pe.primary_ind
    , evaluation.evaluation_type
    , tms_et.short_desc
      As evaluation_type_desc
    , evaluation.evaluation_date
    , evaluation.active_ind
    , evaluation.rating_code
    , tms_r.short_desc
      As rating_desc
    , evaluation.xcomment
    , evaluation.evaluator_id_number
    , entity.report_name
      As evaluator_rpt_name
  From evaluation
  Inner Join tms_rating tms_r
    On tms_r.rating_code = evaluation.rating_code
  Inner Join tms_evaluation_type tms_et
    On tms_et.evaluation_type = evaluation.evaluation_type
  Left Join prospect_entity pe
    On pe.prospect_id = evaluation.prospect_id
  Left Join entity
    On entity.id_number = evaluation.evaluator_id_number
  Where evaluation.evaluation_type In ('PR', 'UR') -- Prospect Research, UOR
)

---- Evaluation ratings
Select
  ratings.evaluation_id
  , ratings.id_number
  , ratings.prospect_id
  , ratings.primary_ind
  , deg.report_name
  , deg.record_status_code
  , deg.degrees_concat
  , deg.first_ksm_year
  , deg.program_group
  , ratings.evaluation_type
  , ratings.evaluation_type_desc
  , ratings.evaluation_date
  , ratings.active_ind
  , ratings.rating_code
  , ratings.rating_desc
  , ksm_pkg_tmp.get_number_from_dollar(rating_desc)
    As rating_amt_low
  , ratings.xcomment
  , ratings.evaluator_id_number
  , ratings.evaluator_rpt_name
From ratings
Inner Join v_entity_ksm_degrees deg
  On deg.id_number = ratings.id_number
