-- Raw proposal data
Select
  phf.prospect_id
  , phf.prospect_name
  , phf.proposal_type
  , phf.probability
  , phf.proposal_status
  , Case
      When proposal_status In ('Withdrawn', 'Declined')
        Then 'Declined/Withdrawn'
      When  proposal_status In ('Funded', 'Approved')
        Then 'Funded/Approved'
      Else proposal_status
    End
    As proposal_status_grouped
  , phf.start_dt_calc
  , phf.ask_date
  , phf.close_dt_calc
  , phf.total_original_ask_amt
  , phf.total_ask_amt
  , phf.total_anticipated_amt
  , phf.total_granted_amt
From v_proposal_history_fast phf
;

-- Aggregated proposal data
With

decwi As (
Select
  phf.prospect_id
  , phf.prospect_name
  , sum(Case When proposal_status = 'Withdrawn' Then 1 Else 0 End) As withdrawn
  , sum(Case When proposal_status = 'Declined' Then 1 Else 0 End) As declined
  , sum(Case When proposal_status In ('Withdrawn', 'Declined') Then 1 Else 0 End) As withdrawn_and_declined
  , sum(Case When proposal_status = 'Funded' Then 1 Else 0 End) As funded
  , sum(Case When proposal_status = 'Approved' Then 1 Else 0 End) As approved
  , sum(Case When proposal_status In ('Funded', 'Approved') Then 1 Else 0 End) As funded_and_approved
From v_proposal_history_fast phf
Group By phf.prospect_name
  , phf.prospect_id
)

Select
  prospect_id
  , prospect_name
  , pea.id_number
  , pea.primary_ind
  , entity.person_or_org
  , withdrawn
  , declined
  , withdrawn_and_declined
  , funded
  , approved
  , funded_and_approved
  , funded_and_approved / (withdrawn_and_declined + funded_and_approved)
    As pct_funded
From decwi
Inner Join table(ksm_pkg_prospect.tbl_prospect_entity_active) pea
  On pea.prospect_id = decwi.prospect_id
Inner Join entity
  On entity.id_number = pea.id_number
Where withdrawn_and_declined > 0
  And primary_ind = 'Y'
Order By withdrawn_and_declined Desc
;
