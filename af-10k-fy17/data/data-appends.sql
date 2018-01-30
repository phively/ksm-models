With

-- Active trustee definition
trustee As (
  Select
    affiliation.id_number
    , Case
        When affil_code = 'TR' Then tms_al.short_desc -- Trustee
        When affil_code = 'TS' Then 'Trustee Spouse' -- Trustee Spouse
      End As trustee
  From affiliation
  Inner Join tms_affiliation_level tms_al On tms_al.affil_level_code = affiliation.affil_level_code
  Where affil_code In ('TR', 'TS') -- Trustee, Trustee Spouse
    And affil_status_code = 'C' -- Current
)

-- Active GAB definition
, gab As (
  Select
    id_number
    , 'GAB' As gab
  From table(rpt_pbh634.ksm_pkg.tbl_committee_gab)
)

-- Active KAC definition
, kac As (
  Select
    id_number
    , 'KAC' As kac
  From table(rpt_pbh634.ksm_pkg.tbl_committee_kac)
)

-- Active Kellogg assignments
, assign As (
  Select Distinct
    assignment.prospect_id
    , prospect_entity.id_number
    , office_code
    , assignment_id_number
    , staff.report_name
  From assignment
  Inner Join table(rpt_pbh634.ksm_pkg.tbl_frontline_ksm_staff) staff On staff.id_number = assignment.assignment_id_number
  Inner Join prospect_entity On prospect_entity.prospect_id = assignment.prospect_id
  Where active_ind = 'Y' -- Active assignments only
    And assignment_type In ('PP', 'PM', 'AF') -- Program Manager (PP), Prospect Manager (PM), Annual Fund Officer (AF)
)
, assign_conc As (
  Select
    prospect_id
    , Listagg(trim(report_name), ';  ') Within Group (Order By report_name) As ksm_managers
    , Listagg(assignment_id_number, ';  ') Within Group (Order By report_name) As ksm_manager_ids
  From (Select Distinct prospect_id, report_name, assignment_id_number From assign)
  Group By prospect_id
)

-- Active Kellogg proposal
, ksm_prop As (
  Select
    prospect_id
    , max(proposal_status)
      keep(dense_rank First Order By hierarchy_order Desc, close_date Asc, proposal_id Asc)
      As furthest_proposal
    , max(close_date)
      keep(dense_rank First Order By hierarchy_order Desc, close_date Asc, proposal_id Asc)
      As furthest_proposal_close_dt
    , count(Distinct proposal_id) As total_proposals
    , sum(ksm_or_univ_ask) As total_asks
  From v_ksm_proposal_history
  Where proposal_in_progress = 'Y'
    And proposal_active = 'Y'
  Group By prospect_id
)

-- Active pledge
, ksm_plg As (
  Select
    id_number
    , count(Distinct tx_number) As total_pledges
    , sum(pledge_balance) As total_pledge_balance
  From nu_gft_trp_gifttrans
  Where alloc_school = 'KM' -- Kellogg only
    And tx_gypm_ind = 'P' -- Pledges only
    And transaction_type Not In ('BE', 'LE') -- Not bequest/life expectancy
    And pledge_status = 'A' -- Active only
    And pledge_balance > 0 -- Unpaid only
  Group By id_number
)

-- AF CYDs
, ksm_af_cyd As (
  Select
    id_number
    , af_cfy
    , af_pfy1
    , af_pfy2
    , af_pfy3
    , af_pfy4
    , af_pfy5
    , af_status
  From v_ksm_giving_summary
)

-- All IDs
, ids As (
    Select id_number
    From trustee
  Union
    Select id_number
    From gab
  Union
    Select id_number
    From kac
  Union
    Select id_number
    From assign
  Union
    Select id_number
    From (Select pe.id_number From ksm_prop kp Inner Join prospect_entity.pe On pe.prospect_id = kp.prospect_id)
  Union
    Select id_number
    From ksm_plg
  Union
    Select id_number
    From ksm_af_cyd
)

-- Main query
Select
  id_list.id_number
  , pe.prospect_id
  , pe.primary_ind
From ids
Left Join prospect_entity pe On pe.id_number = id_list.id_number
Left Join trustee On ... = ids.id_number
Left Join gab On ... = ids.id_number
Left Join kac On ... = ids.id_number
Left Join assign On ... = ids.id_number
Left Join ksm_prop On ... = pe.prospect_id
Left Join ksm_plg On ... = ids.id_number
Left Join ksm_af_cyd On ... = ids.id_number
