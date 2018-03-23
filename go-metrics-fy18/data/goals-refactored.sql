/******** Refactored version of ADVANCE_NU.NU_GFT_V_OFFICER_METRICS ********/

With

/**** If any of the parameters ever change, update them here ****/
custom_params As (
  Select
/********************* UPDATE BELOW HERE *********************/
       100000 As param_ask_amt -- As of 2018-03-23
    ,   48000 As param_granted_amt -- As of 2018-03-23
/********************* UPDATE ABOVE HERE *********************/
  From DUAL
)

/**** Refactor subqueries in lines 78-124 ****/
-- 7 clones, at 205-251, 332-378, 459-505, 855-901, 991-1037, 1127-1173, 1263-1309
, proposal_dates_data As (
  -- In determining which date to use, evaluate outright gifts and pledges first and then if necessary
  -- use the date from a pledge payment.
    Select proposal_id
      , 1 As rank
      , min(prim_gift_date_of_record) As date_of_record --- gifts
    From primary_gift
    Where proposal_id Is Not Null
      And proposal_id != 0
      And pledge_payment_ind = 'N'
    Group By proposal_id
  Union
    Select proposal_id
      , 2 As rank
      , min(prim_gift_date_of_record) As date_of_record --- pledge payments
    From primary_gift
    Where proposal_id Is Not Null
      And proposal_id != 0
      And pledge_payment_ind = 'Y'
    Group By proposal_id
  Union
    Select proposal_id
        , 1 As rank
        , min(prim_pledge_date_of_record) As date_of_record --- pledges
      From primary_pledge
      Where proposal_id Is Not Null
        And proposal_id != 0
      Group By proposal_id
)
, proposal_dates As (
  Select proposal_id
    , min(date_of_record) keep(dense_rank First Order By rank Asc)
      As date_of_record
  From proposal_dates_data
  Group By proposal_id
)

/**** Refactor subqueries in lines 848-982 ****/
-- 3 clones, at 984-1118, 1120-1254, 1256-1390
, proposals As (
  Select p.proposal_id
    , a.assignment_id_number
    , a.active_ind As assignment_active_ind
    , p.active_ind As proposal_active_ind
    , p.ask_amt
    , p.granted_amt
    , p.proposal_status_code
    , p.stop_date As proposal_stop_date
    , a.stop_date As assignment_stop_date
    , count(*) Over(Partition By a.proposal_id) As proposalManagerCount
  From proposal p
  Inner Join assignment a
    On a.proposal_id = p.proposal_id
  Where a.assignment_type = 'PA' -- Proposal Manager
    And a.assignment_id_number != ' '
    And p.ask_amt >= (Select param_ask_amt From custom_params)
    And p.proposal_status_code In ('C', '5', '7', '8') -- submitted/approved/declined/funded
)

-- Credit for funded proposal goals
, proposals_funded_cr As (
  -- Must be funded status, and above the granted amount threshold
  Select *
  From proposals
  Where granted_amt >= (Select param_granted_amt From custom_params)
    And proposal_status_code = '7' -- Only funded
)
, funded_credit As (
    -- 1st priority - Look across all proposal managers on a proposal (inactive OR active).
    -- If there is ONE proposal manager only, credit that for that proposal ID.
    Select proposal_id
      , assignment_id_number
      , granted_amt
      , 1 As info_rank
    From proposals_funded_cr
    Where proposalManagerCount = 1 ----- only one proposal manager/ credit that PA
  Union
    -- 2nd priority - For #2 if there is more than one active proposal managers on a proposal credit BOTH and exit the process.
    Select proposal_id
       , assignment_id_number
       , granted_amt
       , 2 As info_rank
    From proposals_funded_cr
    Where assignment_active_ind = 'Y'
  Union
    -- 3rd priority - For #3, Credit all inactive proposal managers where proposal stop date and assignment stop date within 24 hours
    Select proposal_id
       , assignment_id_number
       , granted_amt
       , 3 As info_rank
    From proposals_funded_cr
    Where proposal_active_ind = 'N'
      And proposal_stop_date - assignment_stop_date <= 1
  Order By info_rank
)
, funded_ranked As (
  Select proposal_id
    , assignment_id_number
    , max(granted_amt) keep(dense_rank First Order By info_rank Asc)
      As granted_amt
  From funded_credit
  Group By proposal_id
    , assignment_id_number
)


/**** Main query 848-982 ****/

SELECT g.year,
       g.id_number,
       'MGDR' goal_type,
       1 as quarter,
       g.goal_3 as goal,
       sum(pr.granted_amt) cnt
  FROM goal g,
        proposal_dates fprop,
       funded_ranked pr
 WHERE g.id_number = pr.assignment_id_number
   AND (fprop.proposal_id = pr.proposal_id)
   AND nu_sys_f_getquarter(fprop.date_of_record) = 1
   AND g.year = nu_sys_f_getfiscalyear(fprop.date_of_record)
 GROUP BY g.year, g.id_number, g.goal_3
 
 
Order By id_number, year
