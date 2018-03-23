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

/**** Refactor subqueries in lines 76-122 ****/
-- 7 clones, at 203-249, 330-376, 457-503, 853-899, 989-1035, 1125-1171, 1261-1307
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

/**** Refactor subqueries in lines 846-980 ****/
-- 3 clones, at 982-1168, 1118-1252, 1254-1388
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

/**** Main query ****/
SELECT g.year,
       g.id_number,
       'MGC' goal_type,
       1 as quarter,
       g.goal_1 as goal,
       count(distinct(pr.proposal_id)) cnt
  FROM goal g,
       (SELECT e1.proposal_id
               , e1.assignment_id_number
          FROM (SELECT e.proposal_id
                       , e.assignment_id_number
                       , row_number() over(partition by e.proposal_id, e.assignment_id_number ORDER BY e.info_rank) proposal_rank
                  FROM ( -- 1st priority - Look across all proposal managers on a proposal (inactive OR active).
                         -- If there is ONE proposal manager only, credit that for that proposal ID.
                         SELECT tbl.PROPOSAL_ID,
                                tbl.ASSIGNMENT_ID_NUMBER,
                                tbl.info_rank
                         FROM (SELECT resolveProposals.PROPOSAL_ID
                                      , resolveProposals.ASSIGNMENT_ID_NUMBER
                                      , resolveProposals.proposalManagerCount
                                      , resolveProposals.info_rank
                              FROM (
                                  SELECT p.proposal_id,
                                        a.assignment_id_number,
                                        count(*) over(partition by a.proposal_id) as proposalManagerCount,
                                        1 as info_rank
                                   FROM proposal p, assignment a
                                  WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA' -- Proposal Manager
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.granted_amt >= 98000
                                    AND p.proposal_status_code = '7' -- Only funded
                                 ) resolveProposals
                               WHERE proposalManagerCount = 1 ----- only one proposal manager/ credit that PA
                               ) tbl
                        UNION
                        -- 2nd priority - For #2 if there is more than one active proposal managers on a proposal credit BOTH and exit the process.
                        SELECT tbl.PROPOSAL_ID
                             , tbl.ASSIGNMENT_ID_NUMBER
                             , tbl.info_rank
                        FROM (SELECT p.proposal_id,
                                     a.assignment_id_number,
                                     2 as info_rank
                             FROM proposal p, assignment a
                             WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA'      -- Proposal Manager
                                    AND a.active_ind = 'Y'
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.granted_amt >= 98000
                                    AND p.proposal_status_code = '7'  -- Only funded
                             ) tbl
                        UNION
                        -- 3rd priority - For #3, Credit all inactive proposal managers where proposal stop date and assignment stop date within 24 hours
                        SELECT tbl.PROPOSAL_ID
                             , tbl.ASSIGNMENT_ID_NUMBER
                             , tbl.info_rank
                        FROM (SELECT p.proposal_id,
                                     a.assignment_id_number,
                                     3 as info_rank
                             FROM proposal p, assignment a
                             WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA'      -- Proposal Manager
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.granted_amt >= 98000
                                    AND p.active_ind = 'N'            -- Inactives on the proposal.
                                    AND p.proposal_status_code = '7'  -- Only funded
                                    AND p.stop_date - a.stop_date <= 1
                              ) tbl
                         ORDER BY info_rank)
                       e) e1
         WHERE e1.proposal_rank = 1) pr,
       proposal_dates pd
 WHERE g.id_number       = pr.assignment_id_number
   AND pd.proposal_id = pr.proposal_id
   AND nu_sys_f_getquarter(pd.date_of_record) = 1
   AND g.year = nu_sys_f_getfiscalyear(pd.date_of_record)
 GROUP BY g.year, g.id_number, g.goal_1
UNION
SELECT g.year,
       g.id_number,
       'MGC' goal_type,
       2 as quarter,
       g.goal_1 as goal,
       count(distinct(pr.proposal_id)) cnt
  FROM goal g,
       (SELECT e1.proposal_id
               , e1.assignment_id_number
          FROM (SELECT e.proposal_id
                       , e.assignment_id_number
                       , row_number() over(partition by e.proposal_id, e.assignment_id_number ORDER BY e.info_rank) proposal_rank
                  FROM ( -- 1st priority - Look across all proposal managers on a proposal (inactive OR active).
                         -- If there is ONE proposal manager only, credit that for that proposal ID.
                         SELECT tbl.PROPOSAL_ID,
                                tbl.ASSIGNMENT_ID_NUMBER,
                                tbl.info_rank
                         FROM (SELECT resolveProposals.PROPOSAL_ID
                                      , resolveProposals.ASSIGNMENT_ID_NUMBER
                                      , resolveProposals.proposalManagerCount
                                      , resolveProposals.info_rank
                              FROM (
                                  SELECT p.proposal_id,
                                        a.assignment_id_number,
                                        count(*) over(partition by a.proposal_id) as proposalManagerCount,
                                        1 as info_rank
                                   FROM proposal p, assignment a
                                  WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA' -- Proposal Manager
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.granted_amt >= 98000
                                    AND p.proposal_status_code = '7' -- Only funded
                                 ) resolveProposals
                               WHERE proposalManagerCount = 1 ----- only one proposal manager/ credit that PA
                               ) tbl
                        UNION
                        -- 2nd priority - For #2 if there is more than one active proposal managers on a proposal credit BOTH and exit the process.
                        SELECT tbl.PROPOSAL_ID
                             , tbl.ASSIGNMENT_ID_NUMBER
                             , tbl.info_rank
                        FROM (SELECT p.proposal_id,
                                     a.assignment_id_number,
                                     2 as info_rank
                             FROM proposal p, assignment a
                             WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA'      -- Proposal Manager
                                    AND a.active_ind = 'Y'
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.granted_amt >= 98000
                                    AND p.proposal_status_code = '7'  -- Only funded
                             ) tbl
                        UNION
                        -- 3rd priority - For #3, Credit all inactive proposal managers where proposal stop date and assignment stop date within 24 hours
                        SELECT tbl.PROPOSAL_ID
                             , tbl.ASSIGNMENT_ID_NUMBER
                             , tbl.info_rank
                        FROM (SELECT p.proposal_id,
                                     a.assignment_id_number,
                                     3 as info_rank
                             FROM proposal p, assignment a
                             WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA'      -- Proposal Manager
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.granted_amt >= 98000
                                    AND p.active_ind = 'N'            -- Inactives on the proposal.
                                    AND p.proposal_status_code = '7'  -- Only funded
                                    AND p.stop_date - a.stop_date <= 1
                              ) tbl
                         ORDER BY info_rank)
                       e) e1
         WHERE e1.proposal_rank = 1) pr,
       proposal_dates pd
 WHERE g.id_number       = pr.assignment_id_number
   AND pd.proposal_id = pr.proposal_id
   AND nu_sys_f_getquarter(pd.date_of_record) = 2
   AND g.year = nu_sys_f_getfiscalyear(pd.date_of_record)
 GROUP BY g.year, g.id_number, g.goal_1
UNION
SELECT g.year,
       g.id_number,
       'MGC' goal_type,
       3 as quarter,
       g.goal_1 as goal,
       count(distinct(pr.proposal_id)) cnt
  FROM goal g,
       (SELECT e1.proposal_id
               , e1.assignment_id_number
          FROM (SELECT e.proposal_id
                       , e.assignment_id_number
                       , row_number() over(partition by e.proposal_id, e.assignment_id_number ORDER BY e.info_rank) proposal_rank
                  FROM ( -- 1st priority - Look across all proposal managers on a proposal (inactive OR active).
                         -- If there is ONE proposal manager only, credit that for that proposal ID.
                         SELECT tbl.PROPOSAL_ID,
                                tbl.ASSIGNMENT_ID_NUMBER,
                                tbl.info_rank
                         FROM (SELECT resolveProposals.PROPOSAL_ID
                                      , resolveProposals.ASSIGNMENT_ID_NUMBER
                                      , resolveProposals.proposalManagerCount
                                      , resolveProposals.info_rank
                              FROM (
                                  SELECT p.proposal_id,
                                        a.assignment_id_number,
                                        count(*) over(partition by a.proposal_id) as proposalManagerCount,
                                        1 as info_rank
                                   FROM proposal p, assignment a
                                  WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA' -- Proposal Manager
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.granted_amt >= 98000
                                    AND p.proposal_status_code = '7' -- Only funded
                                 ) resolveProposals
                               WHERE proposalManagerCount = 1 ----- only one proposal manager/ credit that PA
                               ) tbl
                        UNION
                        -- 2nd priority - For #2 if there is more than one active proposal managers on a proposal credit BOTH and exit the process.
                        SELECT tbl.PROPOSAL_ID
                             , tbl.ASSIGNMENT_ID_NUMBER
                             , tbl.info_rank
                        FROM (SELECT p.proposal_id,
                                     a.assignment_id_number,
                                     2 as info_rank
                             FROM proposal p, assignment a
                             WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA'      -- Proposal Manager
                                    AND a.active_ind = 'Y'
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.granted_amt >= 98000
                                    AND p.proposal_status_code = '7'  -- Only funded
                             ) tbl
                        UNION
                        -- 3rd priority - For #3, Credit all inactive proposal managers where proposal stop date and assignment stop date within 24 hours
                        SELECT tbl.PROPOSAL_ID
                             , tbl.ASSIGNMENT_ID_NUMBER
                             , tbl.info_rank
                        FROM (SELECT p.proposal_id,
                                     a.assignment_id_number,
                                     3 as info_rank
                             FROM proposal p, assignment a
                             WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA'      -- Proposal Manager
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.granted_amt >= 98000
                                    AND p.active_ind = 'N'            -- Inactives on the proposal.
                                    AND p.proposal_status_code = '7'  -- Only funded
                                    AND p.stop_date - a.stop_date <= 1
                              ) tbl
                         ORDER BY info_rank)
                       e) e1
         WHERE e1.proposal_rank = 1) pr,
              proposal_dates pd
 WHERE g.id_number       = pr.assignment_id_number
   AND pd.proposal_id = pr.proposal_id
   AND nu_sys_f_getquarter(pd.date_of_record) = 3
   AND g.year = nu_sys_f_getfiscalyear(pd.date_of_record)
 GROUP BY g.year, g.id_number, g.goal_1
UNION
SELECT g.year,
       g.id_number,
       'MGC' goal_type,
       4 as quarter,
       g.goal_1 as goal,
       count(distinct(pr.proposal_id)) cnt
  FROM goal g,
       (SELECT e1.proposal_id
               , e1.assignment_id_number
          FROM (SELECT e.proposal_id
                       , e.assignment_id_number
                       , row_number() over(partition by e.proposal_id, e.assignment_id_number ORDER BY e.info_rank) proposal_rank
                  FROM ( -- 1st priority - Look across all proposal managers on a proposal (inactive OR active).
                         -- If there is ONE proposal manager only, credit that for that proposal ID.
                         SELECT tbl.PROPOSAL_ID,
                                tbl.ASSIGNMENT_ID_NUMBER,
                                tbl.info_rank
                         FROM (SELECT resolveProposals.PROPOSAL_ID
                                      , resolveProposals.ASSIGNMENT_ID_NUMBER
                                      , resolveProposals.proposalManagerCount
                                      , resolveProposals.info_rank
                              FROM (
                                  SELECT p.proposal_id,
                                        a.assignment_id_number,
                                        count(*) over(partition by a.proposal_id) as proposalManagerCount,
                                        1 as info_rank
                                   FROM proposal p, assignment a
                                  WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA' -- Proposal Manager
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.granted_amt >= 98000
                                    AND p.proposal_status_code = '7' -- Only funded
                                 ) resolveProposals
                               WHERE proposalManagerCount = 1 ----- only one proposal manager/ credit that PA
                               ) tbl
                        UNION
                        -- 2nd priority - For #2 if there is more than one active proposal managers on a proposal credit BOTH and exit the process.
                        SELECT tbl.PROPOSAL_ID
                             , tbl.ASSIGNMENT_ID_NUMBER
                             , tbl.info_rank
                        FROM (SELECT p.proposal_id,
                                     a.assignment_id_number,
                                     2 as info_rank
                             FROM proposal p, assignment a
                             WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA'      -- Proposal Manager
                                    AND a.active_ind = 'Y'
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.granted_amt >= 98000
                                    AND p.proposal_status_code = '7'  -- Only funded
                             ) tbl
                        UNION
                        -- 3rd priority - For #3, Credit all inactive proposal managers where proposal stop date and assignment stop date within 24 hours
                        SELECT tbl.PROPOSAL_ID
                             , tbl.ASSIGNMENT_ID_NUMBER
                             , tbl.info_rank
                        FROM (SELECT p.proposal_id,
                                     a.assignment_id_number,
                                     3 as info_rank
                             FROM proposal p, assignment a
                             WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA'      -- Proposal Manager
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.granted_amt >= 98000
                                    AND p.active_ind = 'N'            -- Inactives on the proposal.
                                    AND p.proposal_status_code = '7'  -- Only funded
                                    AND p.stop_date - a.stop_date <= 1
                              ) tbl
                         ORDER BY info_rank)
                       e) e1
         WHERE e1.proposal_rank = 1) pr,
       proposal_dates pd
 WHERE g.id_number       = pr.assignment_id_number
   AND pd.proposal_id = pr.proposal_id
   AND nu_sys_f_getquarter(pd.date_of_record) = 4
   AND g.year = nu_sys_f_getfiscalyear(pd.date_of_record)
 GROUP BY g.year, g.id_number, g.goal_1
UNION
SELECT g.year,
       g.id_number,
       'MGS' as goal_type,
       1 as quarter,
       g.goal_2 as goal,
       count(distinct(pr.proposal_id)) cnt
  FROM goal g, (SELECT e1.proposal_id
                     , e1.assignment_id_number
                     , e1.initial_contribution_date
               FROM (SELECT e.proposal_id
                       , e.assignment_id_number
                       , e.initial_contribution_date
                       , row_number() over(partition by e.proposal_id, e.assignment_id_number ORDER BY e.info_rank) proposal_rank
                     FROM ( -- 1st priority - Look across all proposal managers on a proposal (inactive OR active).
                         -- If there is ONE proposal manager only, credit that for that proposal ID.
                         SELECT tbl.PROPOSAL_ID
                              , tbl.ASSIGNMENT_ID_NUMBER
                              , tbl.initial_contribution_date
                              , tbl.info_rank
                         FROM (SELECT resolveProposals.PROPOSAL_ID
                                      , resolveProposals.ASSIGNMENT_ID_NUMBER
                                      , resolveProposals.initial_contribution_date
                                      , resolveProposals.proposalManagerCount
                                      , resolveProposals.info_rank
                              FROM (
                                  SELECT p.proposal_id
                                       , a.assignment_id_number
                                       , p.initial_contribution_date
                                       , count(*) over(partition by a.proposal_id) as proposalManagerCount
                                       , 1 as info_rank
                                   FROM proposal p, assignment a
                                  WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA' -- Proposal Manager
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                                 ) resolveProposals
                               WHERE proposalManagerCount = 1 ----- only one proposal manager/ credit that PA
                               ) tbl
                        UNION
                        -- 2nd priority - For #2 if there is more than one active proposal managers on a proposal credit BOTH and exit the process.
                        SELECT tbl.PROPOSAL_ID
                             , tbl.ASSIGNMENT_ID_NUMBER
                             , tbl.initial_contribution_date
                             , tbl.info_rank
                        FROM (SELECT p.proposal_id
                                   , a.assignment_id_number
                                   , p.initial_contribution_date
                                   , 2 as info_rank
                             FROM proposal p, assignment a
                             WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA'      -- Proposal Manager
                                    AND a.active_ind = 'Y'
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                             ) tbl
                        UNION
                        -- 3rd priority - For #3, Credit all inactive proposal managers where proposal stop date and assignment stop date within 24 hours
                        SELECT tbl.PROPOSAL_ID
                             , tbl.ASSIGNMENT_ID_NUMBER
                             , tbl.initial_contribution_date
                             , tbl.info_rank
                        FROM (SELECT p.proposal_id
                                   , a.assignment_id_number
                                   , p.initial_contribution_date
                                   , 3 as info_rank
                             FROM proposal p, assignment a
                             WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA'      -- Proposal Manager
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.active_ind = 'N'            -- Inactives on the proposal.
                                    AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                                    AND p.stop_date - a.stop_date <= 1
                              ) tbl
                         ORDER BY info_rank)
                       e) e1
         WHERE e1.proposal_rank = 1) pr
 WHERE g.id_number = pr.assignment_id_number
   AND g.year = nu_sys_f_getfiscalyear(pr.initial_contribution_date) -- initial_contribution_date is 'ask_date'
   AND nu_sys_f_getquarter(pr.initial_contribution_date) = 1
 GROUP BY g.year, g.id_number, g.goal_2
UNION
SELECT g.year,
       g.id_number,
       'MGS' as goal_type,
       2 as quarter,
       g.goal_2 as goal,
       count(distinct(pr.proposal_id)) cnt
  FROM goal g, (SELECT e1.proposal_id
                     , e1.assignment_id_number
                     , e1.initial_contribution_date
               FROM (SELECT e.proposal_id
                       , e.assignment_id_number
                       , e.initial_contribution_date
                       , row_number() over(partition by e.proposal_id, e.assignment_id_number ORDER BY e.info_rank) proposal_rank
                     FROM ( -- 1st priority - Look across all proposal managers on a proposal (inactive OR active).
                         -- If there is ONE proposal manager only, credit that for that proposal ID.
                         SELECT tbl.PROPOSAL_ID
                              , tbl.ASSIGNMENT_ID_NUMBER
                              , tbl.initial_contribution_date
                              , tbl.info_rank
                         FROM (SELECT resolveProposals.PROPOSAL_ID
                                      , resolveProposals.ASSIGNMENT_ID_NUMBER
                                      , resolveProposals.initial_contribution_date
                                      , resolveProposals.proposalManagerCount
                                      , resolveProposals.info_rank
                              FROM (
                                  SELECT p.proposal_id
                                       , a.assignment_id_number
                                       , p.initial_contribution_date
                                       , count(*) over(partition by a.proposal_id) as proposalManagerCount
                                       , 1 as info_rank
                                   FROM proposal p, assignment a
                                  WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA' -- Proposal Manager
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                                 ) resolveProposals
                               WHERE proposalManagerCount = 1 ----- only one proposal manager/ credit that PA
                               ) tbl
                        UNION
                        -- 2nd priority - For #2 if there is more than one active proposal managers on a proposal credit BOTH and exit the process.
                        SELECT tbl.PROPOSAL_ID
                             , tbl.ASSIGNMENT_ID_NUMBER
                             , tbl.initial_contribution_date
                             , tbl.info_rank
                        FROM (SELECT p.proposal_id
                                   , a.assignment_id_number
                                   , p.initial_contribution_date
                                   , 2 as info_rank
                             FROM proposal p, assignment a
                             WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA'      -- Proposal Manager
                                    AND a.active_ind = 'Y'
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                             ) tbl
                        UNION
                        -- 3rd priority - For #3, Credit all inactive proposal managers where proposal stop date and assignment stop date within 24 hours
                        SELECT tbl.PROPOSAL_ID
                             , tbl.ASSIGNMENT_ID_NUMBER
                             , tbl.initial_contribution_date
                             , tbl.info_rank
                        FROM (SELECT p.proposal_id
                                   , a.assignment_id_number
                                   , p.initial_contribution_date
                                   , 3 as info_rank
                             FROM proposal p, assignment a
                             WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA'      -- Proposal Manager
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.active_ind = 'N'            -- Inactives on the proposal.
                                    AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                                    AND p.stop_date - a.stop_date <= 1
                              ) tbl
                         ORDER BY info_rank)
                       e) e1
         WHERE e1.proposal_rank = 1) pr
 WHERE g.id_number = pr.assignment_id_number
   AND g.year = nu_sys_f_getfiscalyear(pr.initial_contribution_date) -- initial_contribution_date is 'ask_date'
   AND nu_sys_f_getquarter(pr.initial_contribution_date) = 2
 GROUP BY g.year, g.id_number, g.goal_2
UNION
SELECT g.year,
       g.id_number,
       'MGS' as goal_type,
       3 as quarter,
       g.goal_2 as goal,
       count(distinct(pr.proposal_id)) cnt
  FROM goal g, (SELECT e1.proposal_id
                     , e1.assignment_id_number
                     , e1.initial_contribution_date
               FROM (SELECT e.proposal_id
                       , e.assignment_id_number
                       , e.initial_contribution_date
                       , row_number() over(partition by e.proposal_id, e.assignment_id_number ORDER BY e.info_rank) proposal_rank
                     FROM ( -- 1st priority - Look across all proposal managers on a proposal (inactive OR active).
                         -- If there is ONE proposal manager only, credit that for that proposal ID.
                         SELECT tbl.PROPOSAL_ID
                              , tbl.ASSIGNMENT_ID_NUMBER
                              , tbl.initial_contribution_date
                              , tbl.info_rank
                         FROM (SELECT resolveProposals.PROPOSAL_ID
                                      , resolveProposals.ASSIGNMENT_ID_NUMBER
                                      , resolveProposals.initial_contribution_date
                                      , resolveProposals.proposalManagerCount
                                      , resolveProposals.info_rank
                              FROM (
                                  SELECT p.proposal_id
                                       , a.assignment_id_number
                                       , p.initial_contribution_date
                                       , count(*) over(partition by a.proposal_id) as proposalManagerCount
                                       , 1 as info_rank
                                   FROM proposal p, assignment a
                                  WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA' -- Proposal Manager
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                                 ) resolveProposals
                               WHERE proposalManagerCount = 1 ----- only one proposal manager/ credit that PA
                               ) tbl
                        UNION
                        -- 2nd priority - For #2 if there is more than one active proposal managers on a proposal credit BOTH and exit the process.
                        SELECT tbl.PROPOSAL_ID
                             , tbl.ASSIGNMENT_ID_NUMBER
                             , tbl.initial_contribution_date
                             , tbl.info_rank
                        FROM (SELECT p.proposal_id
                                   , a.assignment_id_number
                                   , p.initial_contribution_date
                                   , 2 as info_rank
                             FROM proposal p, assignment a
                             WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA'      -- Proposal Manager
                                    AND a.active_ind = 'Y'
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                             ) tbl
                        UNION
                        -- 3rd priority - For #3, Credit all inactive proposal managers where proposal stop date and assignment stop date within 24 hours
                        SELECT tbl.PROPOSAL_ID
                             , tbl.ASSIGNMENT_ID_NUMBER
                             , tbl.initial_contribution_date
                             , tbl.info_rank
                        FROM (SELECT p.proposal_id
                                   , a.assignment_id_number
                                   , p.initial_contribution_date
                                   , 3 as info_rank
                             FROM proposal p, assignment a
                             WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA'      -- Proposal Manager
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.active_ind = 'N'            -- Inactives on the proposal.
                                    AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                                    AND p.stop_date - a.stop_date <= 1
                              ) tbl
                         ORDER BY info_rank)
                       e) e1
         WHERE e1.proposal_rank = 1) pr
 WHERE g.id_number = pr.assignment_id_number
   AND g.year = nu_sys_f_getfiscalyear(pr.initial_contribution_date) -- initial_contribution_date is 'ask_date'
   AND nu_sys_f_getquarter(pr.initial_contribution_date) = 3
 GROUP BY g.year, g.id_number, g.goal_2
UNION
SELECT g.year,
       g.id_number,
       'MGS' as goal_type,
       4 as quarter,
       g.goal_2 as goal,
       count(distinct(pr.proposal_id)) cnt
  FROM goal g, (SELECT e1.proposal_id
                     , e1.assignment_id_number
                     , e1.initial_contribution_date
               FROM (SELECT e.proposal_id
                       , e.assignment_id_number
                       , e.initial_contribution_date
                       , row_number() over(partition by e.proposal_id, e.assignment_id_number ORDER BY e.info_rank) proposal_rank
                     FROM ( -- 1st priority - Look across all proposal managers on a proposal (inactive OR active).
                         -- If there is ONE proposal manager only, credit that for that proposal ID.
                         SELECT tbl.PROPOSAL_ID
                              , tbl.ASSIGNMENT_ID_NUMBER
                              , tbl.initial_contribution_date
                              , tbl.info_rank
                         FROM (SELECT resolveProposals.PROPOSAL_ID
                                      , resolveProposals.ASSIGNMENT_ID_NUMBER
                                      , resolveProposals.initial_contribution_date
                                      , resolveProposals.proposalManagerCount
                                      , resolveProposals.info_rank
                              FROM (
                                  SELECT p.proposal_id
                                       , a.assignment_id_number
                                       , p.initial_contribution_date
                                       , count(*) over(partition by a.proposal_id) as proposalManagerCount
                                       , 1 as info_rank
                                   FROM proposal p, assignment a
                                  WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA' -- Proposal Manager
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                                 ) resolveProposals
                               WHERE proposalManagerCount = 1 ----- only one proposal manager/ credit that PA
                               ) tbl
                        UNION
                        -- 2nd priority - For #2 if there is more than one active proposal managers on a proposal credit BOTH and exit the process.
                        SELECT tbl.PROPOSAL_ID
                             , tbl.ASSIGNMENT_ID_NUMBER
                             , tbl.initial_contribution_date
                             , tbl.info_rank
                        FROM (SELECT p.proposal_id
                                   , a.assignment_id_number
                                   , p.initial_contribution_date
                                   , 2 as info_rank
                             FROM proposal p, assignment a
                             WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA'      -- Proposal Manager
                                    AND a.active_ind = 'Y'
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                             ) tbl
                        UNION
                        -- 3rd priority - For #3, Credit all inactive proposal managers where proposal stop date and assignment stop date within 24 hours
                        SELECT tbl.PROPOSAL_ID
                             , tbl.ASSIGNMENT_ID_NUMBER
                             , tbl.initial_contribution_date
                             , tbl.info_rank
                        FROM (SELECT p.proposal_id
                                   , a.assignment_id_number
                                   , p.initial_contribution_date
                                   , 3 as info_rank
                             FROM proposal p, assignment a
                             WHERE a.proposal_id = p.proposal_id
                                    AND a.assignment_type = 'PA'      -- Proposal Manager
                                    AND a.assignment_id_number != ' '
                                    AND p.ask_amt >= 100000
                                    AND p.active_ind = 'N'            -- Inactives on the proposal.
                                    AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                                    AND p.stop_date - a.stop_date <= 1
                              ) tbl
                         ORDER BY info_rank)
                       e) e1
         WHERE e1.proposal_rank = 1) pr
 WHERE g.id_number = pr.assignment_id_number
   AND g.year = nu_sys_f_getfiscalyear(pr.initial_contribution_date) -- initial_contribution_date is 'ask_date'
   AND nu_sys_f_getquarter(pr.initial_contribution_date) = 4
 GROUP BY g.year, g.id_number, g.goal_2
UNION
/**** Main query 846-1388 ****/
Select g.year
  , g.id_number
  , 'MGDR' As goal_type
  , to_number(nu_sys_f_getquarter(pd.date_of_record)) As quarter
  , g.goal_3 As goal
  , sum(fr.granted_amt) As cnt
From goal g
Inner Join funded_ranked fr
  On fr.assignment_id_number = g.id_number
Inner Join proposal_dates pd
  On pd.proposal_id = fr.proposal_id
Where g.year = nu_sys_f_getfiscalyear(pd.date_of_record)
Group By g.year
  , g.id_number
  , nu_sys_f_getquarter(pd.date_of_record)
  , g.goal_3
/**** Main query ****/
UNION
SELECT distinct g.year,
       g.id_number,
       'NOV' as goal_type,
       to_number(c.fiscal_qtr) as quarter,
       g.goal_4 as goal,
       count(distinct(c.report_id)) cnt
from  ( select distinct c.author_id_number
       , c.report_id
       , CASE WHEN  to_number(to_char(c.contact_date,'MM')) < 9
              THEN to_number(to_char(c.contact_date, 'YYYY'))
         ELSE      to_number(to_char(c.contact_date, 'YYYY')) + 1
         END  c_year -- fiscal year
       , decode(to_char(c.contact_date, 'MM'), '01', '2', '02',  '2'
                                           , '03', '3', '04', '3', '05', '3'
                                           , '06', '4', '07', '4', '08', '4'
                                           , '09', '1', '10', '1', '11', '1'
                                           , '12', '2', NULL
              )  Fiscal_qtr
         FROM contact_report c
         WHERE c.contact_type = 'V'
        ) c
   , goal g,  contact_rpt_credit cr
WHERE (g.id_number = c.author_id_number OR g.ID_NUMBER = cr.ID_NUMBER)
   AND cr.report_id = c.report_id
   AND cr.contact_credit_type = '1'
   AND g.year = c.c_year
GROUP BY g.year, to_number(c.fiscal_qtr), g.id_number, g.goal_4
UNION
SELECT distinct g.year,
       g.id_number,
       'NOQV' as goal_type,
       to_number(c.fiscal_qtr) as quarter,
       g.goal_4 as goal,
       count(distinct(c.report_id)) cnt
from  ( select distinct c.author_id_number
       , c.report_id
       , CASE WHEN  to_number(to_char(c.contact_date,'MM')) < 9
              THEN to_number(to_char(c.contact_date, 'YYYY'))
         ELSE      to_number(to_char(c.contact_date, 'YYYY')) + 1
         END  c_year -- fiscal year
       , decode(to_char(c.contact_date, 'MM'), '01', '2', '02',  '2'
                                           , '03', '3', '04', '3', '05', '3'
                                           , '06', '4', '07', '4', '08', '4'
                                           , '09', '1', '10', '1', '11', '1'
                                           , '12', '2', NULL
              )  Fiscal_qtr
         FROM contact_report c
         WHERE c.contact_type = 'V'
         AND c.contact_purpose_code = '1'
        ) c
   , goal g,  contact_rpt_credit cr
WHERE (g.id_number = c.author_id_number OR g.ID_NUMBER = cr.ID_NUMBER)
   AND cr.report_id = c.report_id
   AND cr.contact_credit_type = '1'
   AND g.year = c.c_year
GROUP BY g.year, to_number(c.fiscal_qtr), g.id_number, g.goal_4
UNION
SELECT g.year,
       g.id_number,
       'PA' as goal_type,
       1 as quarter,
       g.goal_6 as goal,
       count(distinct(pr.proposal_id)) cnt
  FROM goal g,
       (SELECT e1.proposal_id,
               e1.assignment_id_number,
               e1.initial_contribution_date
          FROM (SELECT e.proposal_id,
                       e.assignment_id_number,
                       e.initial_contribution_date,
                       row_number() over(partition by e.proposal_id, e.assignment_id_number ORDER BY e.info_rank) proposal_rank,
                       e.info_rank
                  FROM ( -- Any active proposals (1st priority)
                        SELECT p.proposal_id,
                                a.assignment_id_number,
                                p.initial_contribution_date,
                                1 as info_rank
                          FROM proposal p, assignment a
                         WHERE a.proposal_id = p.proposal_id
                           AND a.assignment_type = 'AS' -- Proposal Assist
                           AND a.active_ind = 'Y'
                           AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                           AND nu_sys_f_getquarter(p.initial_contribution_date) = 1
                        UNION
                        -- If no active proposals, then any inactive proposals where proposal stop date and assignment stop date within 24 hours  (2nd priority)
                        SELECT p.proposal_id,
                               a.assignment_id_number,
                               p.initial_contribution_date,
                               2 as info_rank
                          FROM proposal p, assignment a
                         WHERE a.proposal_id = p.proposal_id
                           AND a.assignment_type = 'AS' -- Proposal Assist
                           AND a.active_ind = 'N'
                           AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                           AND nu_sys_f_getquarter(p.initial_contribution_date) = 1
                           AND p.stop_date - a.stop_date <= 1
                         ORDER BY info_rank) e) e1
         WHERE e1.proposal_rank = 1) pr
 WHERE g.id_number = pr.assignment_id_number
   AND g.year = nu_sys_f_getfiscalyear(pr.initial_contribution_date) -- initial_contribution_date is 'ask_date'
 GROUP BY g.year, g.id_number, g.goal_6
UNION
SELECT g.year,
       g.id_number,
       'PA' as goal_type,
       2 as quarter,
       g.goal_6 as goal,
       count(distinct(pr.proposal_id)) cnt
  FROM goal g,
       (SELECT e1.proposal_id,
               e1.assignment_id_number,
               e1.initial_contribution_date
          FROM (SELECT e.proposal_id,
                       e.assignment_id_number,
                       e.initial_contribution_date,
                       row_number() over(partition by e.proposal_id, e.assignment_id_number ORDER BY e.info_rank) proposal_rank,
                       e.info_rank
                  FROM ( -- Any active proposals (1st priority)
                        SELECT p.proposal_id,
                                a.assignment_id_number,
                                p.initial_contribution_date,
                                1 as info_rank
                          FROM proposal p, assignment a
                         WHERE a.proposal_id = p.proposal_id
                           AND a.assignment_type = 'AS' -- Proposal Assist
                           AND a.active_ind = 'Y'
                           AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                           AND nu_sys_f_getquarter(p.initial_contribution_date) = 2
                        UNION
                        -- If no active proposals, then any inactive proposals where proposal stop date and assignment stop date within 24 hours  (2nd priority)
                        SELECT p.proposal_id,
                               a.assignment_id_number,
                               p.initial_contribution_date,
                               2 as info_rank
                          FROM proposal p, assignment a
                         WHERE a.proposal_id = p.proposal_id
                           AND a.assignment_type = 'AS' -- Proposal Assist
                           AND a.active_ind = 'N'
                           AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                           AND nu_sys_f_getquarter(p.initial_contribution_date) = 2
                           AND p.stop_date - a.stop_date <= 1
                         ORDER BY info_rank) e) e1
         WHERE e1.proposal_rank = 1) pr
 WHERE g.id_number = pr.assignment_id_number
   AND g.year = nu_sys_f_getfiscalyear(pr.initial_contribution_date) -- initial_contribution_date is 'ask_date'
 GROUP BY g.year, g.id_number, g.goal_6
UNION
SELECT g.year,
       g.id_number,
       'PA' as goal_type,
       3 as quarter,
       g.goal_6 as goal,
       count(distinct(pr.proposal_id)) cnt
  FROM goal g,
       (SELECT e1.proposal_id,
               e1.assignment_id_number,
               e1.initial_contribution_date
          FROM (SELECT e.proposal_id,
                       e.assignment_id_number,
                       e.initial_contribution_date,
                       row_number() over(partition by e.proposal_id, e.assignment_id_number ORDER BY e.info_rank) proposal_rank,
                       e.info_rank
                  FROM ( -- Any active proposals (1st priority)
                        SELECT p.proposal_id,
                                a.assignment_id_number,
                                p.initial_contribution_date,
                                1 as info_rank
                          FROM proposal p, assignment a
                         WHERE a.proposal_id = p.proposal_id
                           AND a.assignment_type = 'AS' -- Proposal Assist
                           AND a.active_ind = 'Y'
                           AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                           AND nu_sys_f_getquarter(p.initial_contribution_date) = 3
                        UNION
                        -- If no active proposals, then any inactive proposals where proposal stop date and assignment stop date within 24 hours  (2nd priority)
                        SELECT p.proposal_id,
                               a.assignment_id_number,
                               p.initial_contribution_date,
                               2 as info_rank
                          FROM proposal p, assignment a
                         WHERE a.proposal_id = p.proposal_id
                           AND a.assignment_type = 'AS' -- Proposal Assist
                           AND a.active_ind = 'N'
                           AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                           AND nu_sys_f_getquarter(p.initial_contribution_date) = 3
                           AND p.stop_date - a.stop_date <= 1
                         ORDER BY info_rank) e) e1
         WHERE e1.proposal_rank = 1) pr
 WHERE g.id_number = pr.assignment_id_number
   AND g.year = nu_sys_f_getfiscalyear(pr.initial_contribution_date) -- initial_contribution_date is 'ask_date'
 GROUP BY g.year, g.id_number, g.goal_6
UNION
SELECT g.year,
       g.id_number,
       'PA' as goal_type,
       4 as quarter,
       g.goal_6 as goal,
       count(distinct(pr.proposal_id)) cnt
  FROM goal g,
       (SELECT e1.proposal_id,
               e1.assignment_id_number,
               e1.initial_contribution_date
          FROM (SELECT e.proposal_id,
                       e.assignment_id_number,
                       e.initial_contribution_date,
                       row_number() over(partition by e.proposal_id, e.assignment_id_number ORDER BY e.info_rank) proposal_rank,
                       e.info_rank
                  FROM ( -- Any active proposals (1st priority)
                        SELECT p.proposal_id,
                                a.assignment_id_number,
                                p.initial_contribution_date,
                                1 as info_rank
                          FROM proposal p, assignment a
                         WHERE a.proposal_id = p.proposal_id
                           AND a.assignment_type = 'AS' -- Proposal Assist
                           AND a.active_ind = 'Y'
                           AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                           AND nu_sys_f_getquarter(p.initial_contribution_date) = 4
                        UNION
                        -- If no active proposals, then any inactive proposals where proposal stop date and assignment stop date are within 24 hours  (2nd priority)
                        SELECT p.proposal_id,
                               a.assignment_id_number,
                               p.initial_contribution_date,
                               2 as info_rank
                          FROM proposal p, assignment a
                         WHERE a.proposal_id = p.proposal_id
                           AND a.assignment_type = 'AS' -- Proposal Assist
                           AND a.active_ind = 'N'
                           AND p.proposal_status_code IN ('C', '5', '7', '8') --submitted/approved/declined/funded
                           AND nu_sys_f_getquarter(p.initial_contribution_date) = 4
                           AND p.stop_date - a.stop_date <= 1
                         ORDER BY info_rank) e) e1
         WHERE e1.proposal_rank = 1) pr
 WHERE g.id_number = pr.assignment_id_number
   AND g.year = nu_sys_f_getfiscalyear(pr.initial_contribution_date) -- initial_contribution_date is 'ask_date'
 GROUP BY g.year, g.id_number, g.goal_6


Order By id_number, year, quarter, goal_type
