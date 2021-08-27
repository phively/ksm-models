-- Gifts
Select
  gt.*
  , mg.id_segment
  , mg.id_score
  , mg.pr_segment
  , mg.pr_score
From v_ksm_giving_trans gt
Inner Join entity
  On entity.id_number = gt.id_number
Left Join v_ksm_model_mg mg
  On mg.id_number = gt.id_number
Where
  gt.tx_gypm_ind <> 'Y'
  And gt.credit_amount >= 250E3
  And gt.fiscal_year Between 2020 And 2021
  And entity.person_or_org = 'P'
;

-- Proposals
Select
  ph.*
  , pp.id_number
  , pp.report_name
  , pp.degrees_concat
  , pp.mgo_id_model
  , pp.mgo_id_score
  , pp.mgo_pr_model
  , pp.mgo_pr_score
From v_proposal_history ph
Inner Join v_ksm_prospect_pool pp
  On pp.prospect_id = ph.prospect_id
  And pp.primary_ind = 'Y'
Where
  ph.ksm_linked_amounts >= 250E3
  Or ph.ksm_bin >= .25
  And close_fy Between 2020 And 2021
;

