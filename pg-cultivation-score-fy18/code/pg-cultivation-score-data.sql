/****** N.B. this query uses @catrackstobi connector -- DO NOT RUN OUTSIDE OF BUSINESS HOURS ******/

With

-- PG checklist
pg_checklist As (
  Select
    pgc.*
    , Case
        When ("Double-Alum" + "3 Year Season-Ticket Holder" + "Past or Current Parent") > 0
          Then 1
        Else 0
      End As "Deep Engagement"
    , "Active Prop Indicator" + "AGE" + "PM Visit Last 2Yrs" + "5 + Visits C Rpts" + "25K To Annual" + 
      "10+ Dist Yrs 1 Gft in Last 3" + "MG $250000 or more" + "Morty Visit" + "Trustee or Advisory BD" + 
      "Alumnus" + "CHICAGO_HOME"
      As other_indicators
  From rpt_pbh634.v_pg_checklist pgc
)

-- MG modeled scores
, mg_scores As (
  Select
    seg.id_number
    , seg.segment_code
    , sh.description As segment_desc
    , seg.segment_year
    , seg.xcomment As score
  From segment seg
  Inner Join segment_header sh
    On sh.segment_code = seg.segment_code
  Where seg.segment_code In ('MGPR1', 'MGPR2', 'MGPR3', 'MGAD1', 'MGAD2', 'MGAD3')
)
, mg_id As (
  Select
    id_number
    , max(segment_desc) keep(dense_rank First Order By segment_year Desc, segment_code Asc)
      As mg_id_model_desc
    , max(segment_year) keep(dense_rank First Order By segment_year Desc, segment_code Asc)
      As mg_id_model_year
    , max(score) keep(dense_rank First Order By segment_year Desc, segment_code Asc)
      As mg_id_model_score
  From mg_scores
  Where segment_code In ('MGAD1', 'MGAD2', 'MGAD3')
  Group By id_number
)
, mg_priority As (
  Select
    id_number
    , max(segment_desc) keep(dense_rank First Order By segment_year Desc, segment_code Asc)
      As mg_pr_model_desc
    , max(segment_year) keep(dense_rank First Order By segment_year Desc, segment_code Asc)
      As mg_pr_model_year
    , max(score) keep(dense_rank First Order By segment_year Desc, segment_code Asc)
      As mg_pr_model_score
  From mg_scores
  Where segment_code In ('MGPR1', 'MGPR2', 'MGPR3')
  Group By id_number
)

-- Largest cash transaction
, big_gift As (
  Select
    id_number
    , max(credit_amount) As largest_gift_or_payment
  From nu_gft_trp_gifttrans
  Where tx_gypm_ind In ('G', 'Y') -- Gift or pledge payment only
  Group By id_number
)


Select
  "Primary Entity ID" As id_number
  , "Prospect ID" As prospect_id
  , "Prospect Name" As prospect_name
  , ("Deep Engagement" + other_indicators) As cultivation_score
  , "Qualification Level" As qual_level
  , "Pref State US/ Country (Int)" As pref_addr
  , "All NU Degrees" As nu_deg
  , "All NU Degrees Spouse" As nu_deg_spouse
  , "Prospect Manager" As prospect_mgr
  , "Affinity Score" As affinity_score
  , "CAMPAIGN_NEWGIFT_CMIT_CREDIT"
  , "ACTIVE_PLEDGE_BALANCE"
  , "MULTI_OR_SINGLE_INTEREST"
  , "POTENTIAL_INTEREST_AREAS"
  , "Active Prop Indicator" As active_proposals
  , "AGE"
  , "PM Visit Last 2Yrs" As pm_visit_last_2_yrs
  , "5 + Visits C Rpts" As visits_5plus
  , "25K To Annual" As af_25k_gift
  , "10+ Dist Yrs 1 Gft in Last 3" As gave_in_last_3_yrs
  , "MG $250000 or more" As mg_250K_plus
  , "Morty Visit" As president_visit
  , "Trustee or Advisory BD" As trustee_or_advisory_board
  , "Alumnus"
  , "Deep Engagement" As deep_engagement
  , "CHICAGO_HOME"
  , "Double-Alum" As double_alum
  , "3 Year Season-Ticket Holder" As season_ticket_3plus_yrs
  , "Past or Current Parent" As ever_parent
  , "PREF_NAME_SORT"
  , "PG Prospect Flag" As pg_prospect_flag
  , mg_id.mg_id_model_score
  , mg_id.mg_id_model_year
  , mg_id.mg_id_model_desc
  , mg_priority.mg_pr_model_score
  , mg_priority.mg_pr_model_year
  , mg_priority.mg_pr_model_desc
  , coalesce(big_gift.largest_gift_or_payment, 0)
    As largest_gift_or_payment
From pg_checklist
Left Join mg_id
  On mg_id.id_number = pg_checklist."Primary Entity ID"
Left Join mg_priority
  On mg_priority.id_number = pg_checklist."Primary Entity ID"
Left Join big_gift
  On big_gift.id_number = pg_checklist."Primary Entity ID"
Order By
  ("Deep Engagement" + other_indicators) Desc
  , "Qualification Level" Asc
  , "PREF_NAME_SORT" Asc
