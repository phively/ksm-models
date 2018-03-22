/* Copied from advance_nu_rpt.v_officer_metrics_perf_year_km
Tons of duplicated code; if used in production could shunt most into its own WITH subquery (likely speed-up too) */

WITH
    inline_goals AS
    (
    SELECT
        id_number,
        year,
        goal_1/4 goal_1,
        goal_2/4 goal_2,
        goal_3/4 goal_3,
        goal_4/4 goal_4,
        goal_5/4 goal_5,
        goal_6/4 goal_6,
        goal_7/4 goal_7,
        goal_8/4 goal_8,
        goal_9/4 goal_9,
        goal_10/4 goal_10,
        goal_11/4 goal_11,
        goal_12/4 goal_12,
        goal_total,
        sysdate date_added,
        sysdate date_modified,
        ' ' operator_name,
        ' ' user_group,
        ' ' location_id
    FROM
        GOAL
    WHERE
        year = advance_nu_rpt.performance_year(SYSDATE) /* Function call; adds 1 to year if month > 4 (May to Apr performance year) */
    ) ,

    inline_om AS
    (
    SELECT g.year fiscal_year,
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
                                        AND p.stop_date - a.stop_date < = 1
                                  ) tbl
                             ORDER BY info_rank)
                           e) e1
             WHERE e1.proposal_rank = 1) pr,
           (SELECT proposal_id, min(date_of_record) as date_of_record
              FROM (SELECT PROPOSAL_ID,
                           MIN(PRIM_GIFT_DATE_OF_RECORD) as DATE_OF_RECORD --- gifts
                      FROM primary_gift
                     WHERE (PROPOSAL_ID IS NOT NULL)
                       AND PROPOSAL_ID != 0
                     GROUP BY proposal_id
                    UNION
                    SELECT proposal_id,
                           MIN(prim_pledge_date_of_record) as DATE_OF_RECORD --- pledges
                      from primary_pledge
                     WHERE (PROPOSAL_ID IS NOT NULL)
                       AND PROPOSAL_ID != 0
                     GROUP BY proposal_id)
             GROUP BY proposal_id) fprop
     WHERE g.id_number       = pr.assignment_id_number
       AND fprop.proposal_id = pr.proposal_id
       AND advance_nu_rpt.performance_quarter(fprop.date_of_record) = 1
       AND g.year = advance_nu_rpt.performance_year(fprop.date_of_record)
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
                                        AND p.stop_date - a.stop_date < = 1
                                  ) tbl
                             ORDER BY info_rank)
                           e) e1
             WHERE e1.proposal_rank = 1) pr,
           (SELECT proposal_id, min(date_of_record) as date_of_record
              FROM (SELECT PROPOSAL_ID,
                           MIN(PRIM_GIFT_DATE_OF_RECORD) as DATE_OF_RECORD --- gifts
                      FROM primary_gift
                     WHERE (PROPOSAL_ID IS NOT NULL)
                       AND PROPOSAL_ID != 0
                     GROUP BY proposal_id
                    UNION
                    SELECT proposal_id,
                           MIN(prim_pledge_date_of_record) as DATE_OF_RECORD --- pledges
                      from primary_pledge
                     WHERE (PROPOSAL_ID IS NOT NULL)
                       AND PROPOSAL_ID != 0
                     GROUP BY proposal_id)
             GROUP BY proposal_id) fprop
     WHERE g.id_number       = pr.assignment_id_number
       AND fprop.proposal_id = pr.proposal_id
       AND advance_nu_rpt.performance_quarter(fprop.date_of_record) = 2
       AND g.year = advance_nu_rpt.performance_year(fprop.date_of_record)
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
                                        AND p.stop_date - a.stop_date < = 1
                                  ) tbl
                             ORDER BY info_rank)
                           e) e1
             WHERE e1.proposal_rank = 1) pr,
           (SELECT proposal_id, min(date_of_record) as date_of_record
              FROM (SELECT PROPOSAL_ID,
                           MIN(PRIM_GIFT_DATE_OF_RECORD) as DATE_OF_RECORD --- gifts
                      FROM primary_gift
                     WHERE (PROPOSAL_ID IS NOT NULL)
                       AND PROPOSAL_ID != 0
                     GROUP BY proposal_id
                    UNION
                    SELECT proposal_id,
                           MIN(prim_pledge_date_of_record) as DATE_OF_RECORD --- pledges
                      from primary_pledge
                     WHERE (PROPOSAL_ID IS NOT NULL)
                       AND PROPOSAL_ID != 0
                     GROUP BY proposal_id)
             GROUP BY proposal_id) fprop
     WHERE g.id_number       = pr.assignment_id_number
       AND fprop.proposal_id = pr.proposal_id
       AND advance_nu_rpt.performance_quarter(fprop.date_of_record) = 3
       AND g.year = advance_nu_rpt.performance_year(fprop.date_of_record)
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
                                        AND p.stop_date - a.stop_date < = 1
                                  ) tbl
                             ORDER BY info_rank)
                           e) e1
             WHERE e1.proposal_rank = 1) pr,
           (SELECT proposal_id, min(date_of_record) as date_of_record
              FROM (SELECT PROPOSAL_ID,
                           MIN(PRIM_GIFT_DATE_OF_RECORD) as DATE_OF_RECORD --- gifts
                      FROM primary_gift
                     WHERE (PROPOSAL_ID IS NOT NULL)
                       AND PROPOSAL_ID != 0
                     GROUP BY proposal_id
                    UNION
                    SELECT proposal_id,
                           MIN(prim_pledge_date_of_record) as DATE_OF_RECORD --- pledges
                      from primary_pledge
                     WHERE (PROPOSAL_ID IS NOT NULL)
                       AND PROPOSAL_ID != 0
                     GROUP BY proposal_id)
             GROUP BY proposal_id) fprop
     WHERE g.id_number       = pr.assignment_id_number
       AND fprop.proposal_id = pr.proposal_id
       AND advance_nu_rpt.performance_quarter(fprop.date_of_record) = 4
       AND g.year = advance_nu_rpt.performance_year(fprop.date_of_record)
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
                                        AND p.stop_date - a.stop_date < = 1
                                  ) tbl
                             ORDER BY info_rank)
                           e) e1
             WHERE e1.proposal_rank = 1) pr
     WHERE g.id_number = pr.assignment_id_number
       AND g.year = advance_nu_rpt.performance_year(pr.initial_contribution_date) -- initial_contribution_date is 'ask_date'
       AND advance_nu_rpt.performance_quarter(pr.initial_contribution_date) = 1
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
                                        AND p.stop_date - a.stop_date < = 1
                                  ) tbl
                             ORDER BY info_rank)
                           e) e1
             WHERE e1.proposal_rank = 1) pr
     WHERE g.id_number = pr.assignment_id_number
       AND g.year = advance_nu_rpt.performance_year(pr.initial_contribution_date) -- initial_contribution_date is 'ask_date'
       AND advance_nu_rpt.performance_quarter(pr.initial_contribution_date) = 2
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
                                        AND p.stop_date - a.stop_date < = 1
                                  ) tbl
                             ORDER BY info_rank)
                           e) e1
             WHERE e1.proposal_rank = 1) pr
     WHERE g.id_number = pr.assignment_id_number
       AND g.year = advance_nu_rpt.performance_year(pr.initial_contribution_date) -- initial_contribution_date is 'ask_date'
       AND advance_nu_rpt.performance_quarter(pr.initial_contribution_date) = 3
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
                                        AND p.stop_date - a.stop_date < = 1
                                  ) tbl
                             ORDER BY info_rank)
                           e) e1
             WHERE e1.proposal_rank = 1) pr
     WHERE g.id_number = pr.assignment_id_number
       AND g.year = advance_nu_rpt.performance_year(pr.initial_contribution_date) -- initial_contribution_date is 'ask_date'
       AND advance_nu_rpt.performance_quarter(pr.initial_contribution_date) = 4
     GROUP BY g.year, g.id_number, g.goal_2
    UNION
    SELECT g.year,
           g.id_number,
           'MGDR' goal_type,
           1 as quarter,
           g.goal_3 as goal,
           sum(pr.granted_amt) cnt
      FROM goal g,
           (SELECT tbl.proposal_id, min(tbl.date_of_record) as date_of_record
              FROM (SELECT PROPOSAL_ID,
                           MIN(PRIM_GIFT_DATE_OF_RECORD) as DATE_OF_RECORD --- gifts
                      FROM primary_gift
                     WHERE (PROPOSAL_ID IS NOT NULL)
                       AND PROPOSAL_ID != 0
                     GROUP BY proposal_id
                    UNION
                    SELECT proposal_id,
                           MIN(prim_pledge_date_of_record) as DATE_OF_RECORD --- pledges
                      from primary_pledge
                     WHERE (PROPOSAL_ID IS NOT NULL)
                       AND PROPOSAL_ID != 0
                     GROUP BY proposal_id) tbl
             GROUP BY tbl.proposal_id) fprop,
           (SELECT e1.proposal_id
                   , e1.assignment_id_number
                   , e1.granted_amt
              FROM (SELECT e.proposal_id
                           , e.assignment_id_number
                           , e.granted_amt
                           , row_number() over(partition by e.proposal_id, e.assignment_id_number ORDER BY e.info_rank) proposal_rank
                      FROM ( -- 1st priority - Look across all proposal managers on a proposal (inactive OR active).
                             -- If there is ONE proposal manager only, credit that for that proposal ID.
                             SELECT tbl.PROPOSAL_ID
                                  , tbl.ASSIGNMENT_ID_NUMBER
                                  , tbl.granted_amt
                                  , tbl.info_rank
                             FROM (SELECT resolveProposals.PROPOSAL_ID
                                          , resolveProposals.ASSIGNMENT_ID_NUMBER
                                          , resolveProposals.proposalManagerCount
                                          , resolveProposals.granted_amt
                                          , resolveProposals.info_rank
                                  FROM (
                                      SELECT p.proposal_id
                                           , a.assignment_id_number
                                           , count(*) over(partition by a.proposal_id) as proposalManagerCount
                                           , p.granted_amt
                                           , 1 as info_rank
                                       FROM proposal p, assignment a
                                      WHERE a.proposal_id = p.proposal_id
                                        AND a.assignment_type = 'PA' -- Proposal Manager
                                        AND a.assignment_id_number != ' '
                                        AND p.ask_amt >= 100000
                                        AND p.granted_amt >= 48000
                                        AND p.proposal_status_code = '7' -- Only funded
                                     ) resolveProposals
                                   WHERE proposalManagerCount = 1 ----- only one proposal manager/ credit that PA
                                   ) tbl
                            UNION
                            -- 2nd priority - For #2 if there is more than one active proposal managers on a proposal credit BOTH and exit the process.
                            SELECT tbl.PROPOSAL_ID
                                 , tbl.ASSIGNMENT_ID_NUMBER
                                 , tbl.granted_amt
                                 , tbl.info_rank
                            FROM (SELECT p.proposal_id
                                       , a.assignment_id_number
                                       , p.granted_amt
                                       , 2 as info_rank
                                 FROM proposal p, assignment a
                                 WHERE a.proposal_id = p.proposal_id
                                        AND a.assignment_type = 'PA'      -- Proposal Manager
                                        AND a.active_ind = 'Y'
                                        AND a.assignment_id_number != ' '
                                        AND p.ask_amt >= 100000
                                        AND p.granted_amt >= 48000
                                        AND p.proposal_status_code = '7'  -- Only funded
                                 ) tbl
                            UNION
                            -- 3rd priority - For #3, Credit all inactive proposal managers where proposal stop date and assignment stop date within 24 hours
                            SELECT tbl.PROPOSAL_ID
                                 , tbl.ASSIGNMENT_ID_NUMBER
                                 , tbl.granted_amt
                                 , tbl.info_rank
                            FROM (SELECT p.proposal_id
                                       , a.assignment_id_number
                                       , p.granted_amt
                                       , 3 as info_rank
                                 FROM proposal p, assignment a
                                 WHERE a.proposal_id = p.proposal_id
                                        AND a.assignment_type = 'PA'      -- Proposal Manager
                                        AND a.assignment_id_number != ' '
                                        AND p.ask_amt >= 100000
                                        AND p.granted_amt >= 48000
                                        AND p.active_ind = 'N'            -- Inactives on the proposal.
                                        AND p.proposal_status_code = '7'  -- Only funded
                                        AND p.stop_date - a.stop_date < = 1
                                  ) tbl
                             ORDER BY info_rank)
                           e) e1
             WHERE e1.proposal_rank = 1) pr
     WHERE g.id_number = pr.assignment_id_number
       AND (fprop.proposal_id = pr.proposal_id)
       AND advance_nu_rpt.performance_quarter(fprop.date_of_record) = 1
       AND g.year = advance_nu_rpt.performance_year(fprop.date_of_record)
     GROUP BY g.year, g.id_number, g.goal_3
    UNION
    SELECT g.year,
           g.id_number,
           'MGDR' goal_type,
           2 as quarter,
           g.goal_3 as goal,
           sum(pr.granted_amt) cnt
      FROM goal g,
             (SELECT tbl.proposal_id, min(tbl.date_of_record) as date_of_record
              FROM (SELECT PROPOSAL_ID,
                           MIN(PRIM_GIFT_DATE_OF_RECORD) as DATE_OF_RECORD --- gifts
                      FROM primary_gift
                     WHERE (PROPOSAL_ID IS NOT NULL)
                       AND PROPOSAL_ID != 0
                     GROUP BY proposal_id
                    UNION
                    SELECT proposal_id,
                           MIN(prim_pledge_date_of_record) as DATE_OF_RECORD --- pledges
                      from primary_pledge
                     WHERE (PROPOSAL_ID IS NOT NULL)
                       AND PROPOSAL_ID != 0
                     GROUP BY proposal_id) tbl
             GROUP BY tbl.proposal_id) fprop,
           (SELECT e1.proposal_id
                   , e1.assignment_id_number
                   , e1.granted_amt
              FROM (SELECT e.proposal_id
                           , e.assignment_id_number
                           , e.granted_amt
                           , row_number() over(partition by e.proposal_id, e.assignment_id_number ORDER BY e.info_rank) proposal_rank
                      FROM ( -- 1st priority - Look across all proposal managers on a proposal (inactive OR active).
                             -- If there is ONE proposal manager only, credit that for that proposal ID.
                             SELECT tbl.PROPOSAL_ID
                                  , tbl.ASSIGNMENT_ID_NUMBER
                                  , tbl.granted_amt
                                  , tbl.info_rank
                             FROM (SELECT resolveProposals.PROPOSAL_ID
                                          , resolveProposals.ASSIGNMENT_ID_NUMBER
                                          , resolveProposals.proposalManagerCount
                                          , resolveProposals.granted_amt
                                          , resolveProposals.info_rank
                                  FROM (
                                      SELECT p.proposal_id
                                           , a.assignment_id_number
                                           , count(*) over(partition by a.proposal_id) as proposalManagerCount
                                           , p.granted_amt
                                           , 1 as info_rank
                                       FROM proposal p, assignment a
                                      WHERE a.proposal_id = p.proposal_id
                                        AND a.assignment_type = 'PA' -- Proposal Manager
                                        AND a.assignment_id_number != ' '
                                        AND p.ask_amt >= 100000
                                        AND p.granted_amt >= 48000
                                        AND p.proposal_status_code = '7' -- Only funded
                                     ) resolveProposals
                                   WHERE proposalManagerCount = 1 ----- only one proposal manager/ credit that PA
                                   ) tbl
                            UNION
                            -- 2nd priority - For #2 if there is more than one active proposal managers on a proposal credit BOTH and exit the process.
                            SELECT tbl.PROPOSAL_ID
                                 , tbl.ASSIGNMENT_ID_NUMBER
                                 , tbl.granted_amt
                                 , tbl.info_rank
                            FROM (SELECT p.proposal_id
                                       , a.assignment_id_number
                                       , p.granted_amt
                                       , 2 as info_rank
                                 FROM proposal p, assignment a
                                 WHERE a.proposal_id = p.proposal_id
                                        AND a.assignment_type = 'PA'      -- Proposal Manager
                                        AND a.active_ind = 'Y'
                                        AND a.assignment_id_number != ' '
                                        AND p.ask_amt >= 100000
                                        AND p.granted_amt >= 48000
                                        AND p.proposal_status_code = '7'  -- Only funded
                                 ) tbl
                            UNION
                            -- 3rd priority - For #3, Credit all inactive proposal managers where proposal stop date and assignment stop date within 24 hours
                            SELECT tbl.PROPOSAL_ID
                                 , tbl.ASSIGNMENT_ID_NUMBER
                                 , tbl.granted_amt
                                 , tbl.info_rank
                            FROM (SELECT p.proposal_id
                                       , a.assignment_id_number
                                       , p.granted_amt
                                       , 3 as info_rank
                                 FROM proposal p, assignment a
                                 WHERE a.proposal_id = p.proposal_id
                                        AND a.assignment_type = 'PA'      -- Proposal Manager
                                        AND a.assignment_id_number != ' '
                                        AND p.ask_amt >= 100000
                                        AND p.granted_amt >= 48000
                                        AND p.active_ind = 'N'            -- Inactives on the proposal.
                                        AND p.proposal_status_code = '7'  -- Only funded
                                        AND p.stop_date - a.stop_date < = 1
                                  ) tbl
                             ORDER BY info_rank)
                           e) e1
             WHERE e1.proposal_rank = 1) pr
     WHERE g.id_number = pr.assignment_id_number
       AND (fprop.proposal_id = pr.proposal_id)
       AND advance_nu_rpt.performance_quarter(fprop.date_of_record) = 2
       AND g.year = advance_nu_rpt.performance_year(fprop.date_of_record)
     GROUP BY g.year, g.id_number, g.goal_3
    UNION
    SELECT g.year,
           g.id_number,
           'MGDR' goal_type,
           3 as quarter,
           g.goal_3 as goal,
           sum(pr.granted_amt) cnt
      FROM goal g,
             (SELECT tbl.proposal_id, min(tbl.date_of_record) as date_of_record
              FROM (SELECT PROPOSAL_ID,
                           MIN(PRIM_GIFT_DATE_OF_RECORD) as DATE_OF_RECORD --- gifts
                      FROM primary_gift
                     WHERE (PROPOSAL_ID IS NOT NULL)
                       AND PROPOSAL_ID != 0
                     GROUP BY proposal_id
                    UNION
                    SELECT proposal_id,
                           MIN(prim_pledge_date_of_record) as DATE_OF_RECORD --- pledges
                      from primary_pledge
                     WHERE (PROPOSAL_ID IS NOT NULL)
                       AND PROPOSAL_ID != 0
                     GROUP BY proposal_id) tbl
             GROUP BY tbl.proposal_id) fprop,
           (SELECT e1.proposal_id
                   , e1.assignment_id_number
                   , e1.granted_amt
              FROM (SELECT e.proposal_id
                           , e.assignment_id_number
                           , e.granted_amt
                           , row_number() over(partition by e.proposal_id, e.assignment_id_number ORDER BY e.info_rank) proposal_rank
                      FROM ( -- 1st priority - Look across all proposal managers on a proposal (inactive OR active).
                             -- If there is ONE proposal manager only, credit that for that proposal ID.
                             SELECT tbl.PROPOSAL_ID
                                  , tbl.ASSIGNMENT_ID_NUMBER
                                  , tbl.granted_amt
                                  , tbl.info_rank
                             FROM (SELECT resolveProposals.PROPOSAL_ID
                                          , resolveProposals.ASSIGNMENT_ID_NUMBER
                                          , resolveProposals.proposalManagerCount
                                          , resolveProposals.granted_amt
                                          , resolveProposals.info_rank
                                  FROM (
                                      SELECT p.proposal_id
                                           , a.assignment_id_number
                                           , count(*) over(partition by a.proposal_id) as proposalManagerCount
                                           , p.granted_amt
                                           , 1 as info_rank
                                       FROM proposal p, assignment a
                                      WHERE a.proposal_id = p.proposal_id
                                        AND a.assignment_type = 'PA' -- Proposal Manager
                                        AND a.assignment_id_number != ' '
                                        AND p.ask_amt >= 100000
                                        AND p.granted_amt >= 48000
                                        AND p.proposal_status_code = '7' -- Only funded
                                     ) resolveProposals
                                   WHERE proposalManagerCount = 1 ----- only one proposal manager/ credit that PA
                                   ) tbl
                            UNION
                            -- 2nd priority - For #2 if there is more than one active proposal managers on a proposal credit BOTH and exit the process.
                            SELECT tbl.PROPOSAL_ID
                                 , tbl.ASSIGNMENT_ID_NUMBER
                                 , tbl.granted_amt
                                 , tbl.info_rank
                            FROM (SELECT p.proposal_id
                                       , a.assignment_id_number
                                       , p.granted_amt
                                       , 2 as info_rank
                                 FROM proposal p, assignment a
                                 WHERE a.proposal_id = p.proposal_id
                                        AND a.assignment_type = 'PA'      -- Proposal Manager
                                        AND a.active_ind = 'Y'
                                        AND a.assignment_id_number != ' '
                                        AND p.ask_amt >= 100000
                                        AND p.granted_amt >= 48000
                                        AND p.proposal_status_code = '7'  -- Only funded
                                 ) tbl
                            UNION
                            -- 3rd priority - For #3, Credit all inactive proposal managers where proposal stop date and assignment stop date within 24 hours
                            SELECT tbl.PROPOSAL_ID
                                 , tbl.ASSIGNMENT_ID_NUMBER
                                 , tbl.granted_amt
                                 , tbl.info_rank
                            FROM (SELECT p.proposal_id
                                       , a.assignment_id_number
                                       , p.granted_amt
                                       , 3 as info_rank
                                 FROM proposal p, assignment a
                                 WHERE a.proposal_id = p.proposal_id
                                        AND a.assignment_type = 'PA'      -- Proposal Manager
                                        AND a.assignment_id_number != ' '
                                        AND p.ask_amt >= 100000
                                        AND p.granted_amt >= 48000
                                        AND p.active_ind = 'N'            -- Inactives on the proposal.
                                        AND p.proposal_status_code = '7'  -- Only funded
                                        AND p.stop_date - a.stop_date < = 1
                                  ) tbl
                             ORDER BY info_rank)
                           e) e1
             WHERE e1.proposal_rank = 1) pr
     WHERE g.id_number = pr.assignment_id_number
       AND (fprop.proposal_id = pr.proposal_id)
       AND advance_nu_rpt.performance_quarter(fprop.date_of_record) = 3
       AND g.year = advance_nu_rpt.performance_year(fprop.date_of_record)
     GROUP BY g.year, g.id_number, g.goal_3
    UNION
    SELECT g.year,
           g.id_number,
           'MGDR' goal_type,
           4 as quarter,
           g.goal_3 as goal,
           sum(pr.granted_amt) cnt
      FROM goal g,
             (SELECT tbl.proposal_id, min(tbl.date_of_record) as date_of_record
              FROM (SELECT PROPOSAL_ID,
                           MIN(PRIM_GIFT_DATE_OF_RECORD) as DATE_OF_RECORD --- gifts
                      FROM primary_gift
                     WHERE (PROPOSAL_ID IS NOT NULL)
                       AND PROPOSAL_ID != 0
                     GROUP BY proposal_id
                    UNION
                    SELECT proposal_id,
                           MIN(prim_pledge_date_of_record) as DATE_OF_RECORD --- pledges
                      from primary_pledge
                     WHERE (PROPOSAL_ID IS NOT NULL)
                       AND PROPOSAL_ID != 0
                     GROUP BY proposal_id) tbl
             GROUP BY tbl.proposal_id) fprop,
           (SELECT e1.proposal_id
                   , e1.assignment_id_number
                   , e1.granted_amt
              FROM (SELECT e.proposal_id
                           , e.assignment_id_number
                           , e.granted_amt
                           , row_number() over(partition by e.proposal_id, e.assignment_id_number ORDER BY e.info_rank) proposal_rank
                      FROM ( -- 1st priority - Look across all proposal managers on a proposal (inactive OR active).
                             -- If there is ONE proposal manager only, credit that for that proposal ID.
                             SELECT tbl.PROPOSAL_ID
                                  , tbl.ASSIGNMENT_ID_NUMBER
                                  , tbl.granted_amt
                                  , tbl.info_rank
                             FROM (SELECT resolveProposals.PROPOSAL_ID
                                          , resolveProposals.ASSIGNMENT_ID_NUMBER
                                          , resolveProposals.proposalManagerCount
                                          , resolveProposals.granted_amt
                                          , resolveProposals.info_rank
                                  FROM (
                                      SELECT p.proposal_id
                                           , a.assignment_id_number
                                           , count(*) over(partition by a.proposal_id) as proposalManagerCount
                                           , p.granted_amt
                                           , 1 as info_rank
                                       FROM proposal p, assignment a
                                      WHERE a.proposal_id = p.proposal_id
                                        AND a.assignment_type = 'PA' -- Proposal Manager
                                        AND a.assignment_id_number != ' '
                                        AND p.ask_amt >= 100000
                                        AND p.granted_amt >= 48000
                                        AND p.proposal_status_code = '7' -- Only funded
                                     ) resolveProposals
                                   WHERE proposalManagerCount = 1 ----- only one proposal manager/ credit that PA
                                   ) tbl
                            UNION
                            -- 2nd priority - For #2 if there is more than one active proposal managers on a proposal credit BOTH and exit the process.
                            SELECT tbl.PROPOSAL_ID
                                 , tbl.ASSIGNMENT_ID_NUMBER
                                 , tbl.granted_amt
                                 , tbl.info_rank
                            FROM (SELECT p.proposal_id
                                       , a.assignment_id_number
                                       , p.granted_amt
                                       , 2 as info_rank
                                 FROM proposal p, assignment a
                                 WHERE a.proposal_id = p.proposal_id
                                        AND a.assignment_type = 'PA'      -- Proposal Manager
                                        AND a.active_ind = 'Y'
                                        AND a.assignment_id_number != ' '
                                        AND p.ask_amt >= 100000
                                        AND p.granted_amt >= 48000
                                        AND p.proposal_status_code = '7'  -- Only funded
                                 ) tbl
                            UNION
                            -- 3rd priority - For #3, Credit all inactive proposal managers where proposal stop date and assignment stop date within 24 hours
                            SELECT tbl.PROPOSAL_ID
                                 , tbl.ASSIGNMENT_ID_NUMBER
                                 , tbl.granted_amt
                                 , tbl.info_rank
                            FROM (SELECT p.proposal_id
                                       , a.assignment_id_number
                                       , p.granted_amt
                                       , 3 as info_rank
                                 FROM proposal p, assignment a
                                 WHERE a.proposal_id = p.proposal_id
                                        AND a.assignment_type = 'PA'      -- Proposal Manager
                                        AND a.assignment_id_number != ' '
                                        AND p.ask_amt >= 100000
                                        AND p.granted_amt >= 48000
                                        AND p.active_ind = 'N'            -- Inactives on the proposal.
                                        AND p.proposal_status_code = '7'  -- Only funded
                                        AND p.stop_date - a.stop_date < = 1
                                  ) tbl
                             ORDER BY info_rank)
                           e) e1
             WHERE e1.proposal_rank = 1) pr
     WHERE g.id_number = pr.assignment_id_number
       AND (fprop.proposal_id = pr.proposal_id)
       AND advance_nu_rpt.performance_quarter(fprop.date_of_record) = 4
       AND g.year = advance_nu_rpt.performance_year(fprop.date_of_record)
     GROUP BY g.year, g.id_number, g.goal_3
    UNION
    SELECT distinct g.year,
           g.id_number,
           'NOV' as goal_type,
           to_number(c.fiscal_qtr) as quarter,
           g.goal_4 as goal,
           count(distinct(c.report_id)) cnt
    from  ( select distinct c.author_id_number
           , c.report_id
           , CASE WHEN  to_number(to_char(c.contact_date,'MM')) < 5
                  THEN to_number(to_char(c.contact_date, 'YYYY'))
             ELSE      to_number(to_char(c.contact_date, 'YYYY')) + 1
             END  c_year -- fiscal year
           , decode(to_char(c.contact_date, 'MM'),
                                                 '01', '3'
                                               , '02', '4'
                                               , '03', '4'
                                               , '04', '4'
                                               , '05', '1'
                                               , '06', '1'
                                               , '07', '1'
                                               , '08', '2'
                                               , '09', '2'
                                               , '10', '2'
                                               , '11', '3'
                                               , '12', '3', NULL
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
           , CASE WHEN  to_number(to_char(c.contact_date,'MM')) < 5
                  THEN to_number(to_char(c.contact_date, 'YYYY'))
             ELSE      to_number(to_char(c.contact_date, 'YYYY')) + 1
             END  c_year -- fiscal year
           , decode(to_char(c.contact_date, 'MM'),
                                                 '01', '3'
                                               , '02', '4'
                                               , '03', '4'
                                               , '04', '4'
                                               , '05', '1'
                                               , '06', '1'
                                               , '07', '1'
                                               , '08', '2'
                                               , '09', '2'
                                               , '10', '2'
                                               , '11', '3'
                                               , '12', '3', NULL
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
                               AND advance_nu_rpt.performance_quarter(p.initial_contribution_date) = 1
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
                               AND advance_nu_rpt.performance_quarter(p.initial_contribution_date) = 1
                               AND p.stop_date - a.stop_date < = 1
                             ORDER BY info_rank) e) e1
             WHERE e1.proposal_rank = 1) pr
     WHERE g.id_number = pr.assignment_id_number
       AND g.year = advance_nu_rpt.performance_year(pr.initial_contribution_date) -- initial_contribution_date is 'ask_date'
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
                               AND advance_nu_rpt.performance_quarter(p.initial_contribution_date) = 2
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
                               AND advance_nu_rpt.performance_quarter(p.initial_contribution_date) = 2
                               AND p.stop_date - a.stop_date < = 1
                             ORDER BY info_rank) e) e1
             WHERE e1.proposal_rank = 1) pr
     WHERE g.id_number = pr.assignment_id_number
       AND g.year = advance_nu_rpt.performance_year(pr.initial_contribution_date) -- initial_contribution_date is 'ask_date'
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
                               AND advance_nu_rpt.performance_quarter(p.initial_contribution_date) = 3
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
                               AND advance_nu_rpt.performance_quarter(p.initial_contribution_date) = 3
                               AND p.stop_date - a.stop_date < = 1
                             ORDER BY info_rank) e) e1
             WHERE e1.proposal_rank = 1) pr
     WHERE g.id_number = pr.assignment_id_number
       AND g.year = advance_nu_rpt.performance_year(pr.initial_contribution_date) -- initial_contribution_date is 'ask_date'
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
                               AND advance_nu_rpt.performance_quarter(p.initial_contribution_date) = 4
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
                               AND advance_nu_rpt.performance_quarter(p.initial_contribution_date) = 4
                               AND p.stop_date - a.stop_date < = 1
                             ORDER BY info_rank) e) e1
             WHERE e1.proposal_rank = 1) pr
     WHERE g.id_number = pr.assignment_id_number
       AND g.year = advance_nu_rpt.performance_year(pr.initial_contribution_date) -- initial_contribution_date is 'ask_date'
     GROUP BY g.year, g.id_number, g.goal_6

    ) ,

    inline_om_2 AS

    (
        SELECT
                 g.id_number,
                 'S' table_type, -- Staff
                 q.fiscal_year,
                 q.quarter,
                 st.office_code,
                 g.goal_1 maj_gft_comm_goal,
                 decode(G1.CNT, null, 0, G1.CNT) maj_gft_comm_cnt,
                 g.goal_2 maj_gft_sol_goal, --maj gift sol goal
                 decode(G2.CNT, null, 0, G2.CNT) maj_gft_sol_cnt,
                 g.goal_3 maj_gft_dol_goal, -- maj gift dol goal
                 decode(G3.CNT, null, 0, G3.CNT) maj_gft_dol_cnt,
                 g.goal_4 visits_goal, -- visits goal
                 decode(G4.CNT, null, 0, G4.CNT) visits_cnt,
                 g.goal_5 qual_visits_goal,
                 decode(G5.CNT, null, 0, G5.CNT) qual_visits_cnt,
                 g.goal_6 prop_assist_goal,
                 decode(G6.CNT, null, 0, G6.CNT) prop_assist_cnt,
                 g.goal_7 prop_ast_dls_goal,
                 decode(G7.CNT, null, 0, G7.CNT) prop_ast_dls_cnt,
                 g.goal_8 prop_ast_com_goal,
                 decode(G8.CNT, null, 0, G8.CNT) prop_ast_com_cnt,
                 g.goal_9 non_vst_con_goal,
                 decode(G9.CNT, null, 0, G9.CNT) non_vst_con_cnt,
                 g.goal_10 gft_plan_con_goal,
                 decode(G10.CNT, null, 0, G10.CNT) gft_plan_con_cnt,
                 '0' com_under_100k_cnt,
                 '0' sol_under_100k_cnt,
                 '0' dlrs_rsd_under_100k_cnt,
                 '0' prop_ast_under_100k_cnt,
                 '0' prop_ast_dlrs_under_100k_cnt
           FROM NU_GFT_V_METRICS_QUARTERS Q,
                 inline_goals G,
                 STAFF ST,
                 (SELECT MGC.ID_NUMBER, MGC.YEAR, SUM(MGC.CNT) CNT, MGC.QUARTER
                  FROM (SELECT Q.Quarter, G.ID_NUMBER, 0 CNT, g.year
                       FROM NU_GFT_V_METRICS_QUARTERS Q, inline_goals G
                       WHERE G.YEAR = Q.fiscal_year
                       UNION
                       SELECT M.quarter, G.ID_NUMBER, nvl(M.CNT, 0) CNT, G.YEAR
                        FROM inline_goals G, inline_om M
                        WHERE GOAL_TYPE = 'MGC'
                             AND G.ID_NUMBER = M.id_number
                             AND m.fiscal_year = g.year
                   ) MGC
                   GROUP BY ID_NUMBER, YEAR, QUARTER
                 ) G1,
                 (SELECT MGS.ID_NUMBER, MGS.YEAR, SUM(MGS.CNT) CNT, MGS.QUARTER
                  FROM (SELECT Q.Quarter, G.ID_NUMBER, 0 CNT, g.year
                       FROM NU_GFT_V_METRICS_QUARTERS Q, inline_goals G
                       WHERE G.YEAR = Q.fiscal_year
                       UNION
                       SELECT M.quarter, G.ID_NUMBER, nvl(M.CNT, 0) CNT, G.YEAR
                        FROM inline_goals G, inline_om M
                        WHERE GOAL_TYPE = 'MGS'
                             AND G.ID_NUMBER = M.id_number
                             AND m.fiscal_year = g.year
                        ) MGS
                   GROUP BY ID_NUMBER, YEAR, QUARTER
                 ) G2,
                 (SELECT MGDR.ID_NUMBER, MGDR.YEAR, SUM(MGDR.CNT) CNT, MGDR.QUARTER
                  FROM (SELECT Q.Quarter, G.ID_NUMBER, 0 CNT, g.year
                       FROM NU_GFT_V_METRICS_QUARTERS Q, inline_goals G
                       WHERE G.YEAR = Q.fiscal_year
                       UNION
                       SELECT M.quarter, G.ID_NUMBER, nvl(M.CNT, 0) CNT, G.YEAR
                        FROM inline_goals G, inline_om M
                        WHERE GOAL_TYPE = 'MGDR'
                             AND G.ID_NUMBER = M.id_number
                             AND m.fiscal_year = g.year
                             ) MGDR
                   GROUP BY ID_NUMBER, YEAR, QUARTER
                 ) G3,
                 (SELECT NOV.ID_NUMBER, NOV.YEAR, SUM(NOV.CNT) CNT, NOV.QUARTER
                  FROM (SELECT Q.Quarter, G.ID_NUMBER, 0 CNT, g.year
                       FROM NU_GFT_V_METRICS_QUARTERS Q, inline_goals G
                       WHERE G.YEAR = Q.fiscal_year
                       UNION
                       SELECT M.quarter, G.ID_NUMBER, nvl(M.CNT, 0) CNT, G.YEAR
                        FROM inline_goals G, inline_om M
                        WHERE GOAL_TYPE = 'NOV'
                             AND G.ID_NUMBER = M.id_number
                             AND m.fiscal_year = g.year
                             ) NOV
                  GROUP BY ID_NUMBER, YEAR, QUARTER
                 ) G4,
                 (SELECT NOQV.ID_NUMBER, NOQV.YEAR, SUM(NOQV.CNT) CNT, NOQV.QUARTER
                  FROM (SELECT Q.Quarter, G.ID_NUMBER, 0 CNT, g.year
                       FROM NU_GFT_V_METRICS_QUARTERS Q, inline_goals G
                       WHERE G.YEAR = Q.fiscal_year
                       UNION
                       SELECT M.quarter, G.ID_NUMBER, nvl(M.CNT, 0) CNT, G.YEAR
                        FROM inline_goals G, inline_om M
                        WHERE GOAL_TYPE = 'NOQV'
                             AND G.ID_NUMBER = M.id_number
                             AND m.fiscal_year = g.year
                             ) NOQV
                   GROUP BY ID_NUMBER, YEAR, QUARTER
                 ) G5,
                 (SELECT PA.ID_NUMBER, PA.YEAR, SUM(PA.CNT) CNT, PA.QUARTER
                  FROM (SELECT Q.Quarter, G.ID_NUMBER, 0 CNT, g.year
                       FROM NU_GFT_V_METRICS_QUARTERS Q, inline_goals G
                       WHERE G.YEAR = Q.fiscal_year
                       UNION
                       SELECT M.quarter, G.ID_NUMBER, nvl(M.CNT, 0) CNT, G.YEAR
                        FROM inline_goals G, inline_om M
                        WHERE GOAL_TYPE = 'PA'
                             AND G.ID_NUMBER = M.id_number
                             AND m.fiscal_year = g.year
                             ) PA
                   GROUP BY ID_NUMBER, YEAR, QUARTER
                 ) G6,
                 (SELECT PADR.ID_NUMBER, PADR.YEAR, SUM(PADR.CNT) CNT, PADR.QUARTER
                  FROM (SELECT Q.Quarter, G.ID_NUMBER, 0 CNT, g.year
                       FROM NU_GFT_V_METRICS_QUARTERS Q, inline_goals G
                       WHERE G.YEAR = Q.fiscal_year
                       UNION
                       SELECT GP.quarter, G.ID_NUMBER, nvl(GP.CNT, 0) CNT, G.YEAR
                        FROM inline_goals G, NU_GFT_V_OFFICER_MET_GIFT_PLAN GP
                        WHERE GOAL_TYPE = 'PADR'
                             AND G.ID_NUMBER = GP.id_number
                             AND GP.fiscal_year = g.year
                             ) PADR
                   GROUP BY ID_NUMBER, YEAR, QUARTER
                 ) G7,
                 (SELECT PAC.ID_NUMBER, PAC.YEAR, SUM(PAC.CNT) CNT, PAC.QUARTER
                  FROM (SELECT Q.Quarter, G.ID_NUMBER, 0 CNT, g.year
                       FROM NU_GFT_V_METRICS_QUARTERS Q, inline_goals G
                       WHERE G.YEAR = Q.fiscal_year
                       UNION
                       SELECT GP.quarter, G.ID_NUMBER, nvl(GP.CNT, 0) CNT, G.YEAR
                        FROM inline_goals G, NU_GFT_V_OFFICER_MET_GIFT_PLAN GP
                        WHERE GOAL_TYPE = 'PAC'
                             AND G.ID_NUMBER = GP.id_number
                             AND GP.fiscal_year = g.year
                             )PAC
                    GROUP BY ID_NUMBER, YEAR, QUARTER
                 ) G8,
                 (SELECT NVC.ID_NUMBER, NVC.YEAR, SUM(NVC.CNT) CNT, NVC.QUARTER
                  FROM (SELECT Q.Quarter, G.ID_NUMBER, 0 CNT, g.year
                       FROM NU_GFT_V_METRICS_QUARTERS Q, inline_goals G
                       WHERE G.YEAR = Q.fiscal_year
                       UNION
                       SELECT GP.quarter, G.ID_NUMBER, nvl(GP.CNT, 0) CNT, G.YEAR
                        FROM inline_goals G, NU_GFT_V_OFFICER_MET_GIFT_PLAN GP
                        WHERE GOAL_TYPE = 'NVC'
                             AND G.ID_NUMBER = GP.id_number
                             AND GP.fiscal_year = g.year
                             ) NVC
                  GROUP BY ID_NUMBER, YEAR, QUARTER
                 ) G9,
                 (SELECT GPC.ID_NUMBER, GPC.YEAR, SUM(GPC.CNT) CNT, GPC.QUARTER
                  FROM (SELECT Q.Quarter, G.ID_NUMBER, 0 CNT, g.year
                       FROM NU_GFT_V_METRICS_QUARTERS Q, inline_goals G
                       WHERE G.YEAR = Q.fiscal_year
                       UNION
                       SELECT GP.quarter, G.ID_NUMBER, nvl(GP.CNT, 0) CNT, G.YEAR
                        FROM inline_goals G, NU_GFT_V_OFFICER_MET_GIFT_PLAN GP
                        WHERE GOAL_TYPE = 'GPC'
                             AND G.ID_NUMBER = GP.id_number
                             AND GP.fiscal_year = g.year
                             ) GPC
                   GROUP BY ID_NUMBER, YEAR, QUARTER
                 ) G10
           WHERE g.year = q.fiscal_year
             AND g.id_number = st.id_number
             AND q.quarter = g1.quarter
             AND g.id_number = g1.id_number
             AND g.year = g1.year
             AND q.quarter = g2.quarter
             AND g.id_number = g2.id_number
             AND g.year = g2.year
             AND q.quarter = g3.quarter
             AND g.id_number = g3.id_number
             AND g.year = g3.year
             AND q.quarter = g4.quarter
             AND g.id_number = g4.id_number
             AND g.year = g4.year
             AND q.quarter = g5.quarter
             AND g.id_number = g5.id_number
             AND g.year = g5.year
             AND q.quarter = g6.quarter
             AND g.id_number = g6.id_number
             AND g.year = g6.year
             AND q.quarter = g7.quarter
             AND g.id_number = g7.id_number
             AND g.year = g7.year
             AND q.quarter = g8.quarter
             AND g.id_number = g8.id_number
             AND g.year = g8.year
             AND q.quarter = g9.quarter
             AND g.id_number = g9.id_number
             AND g.year = g9.year
             AND q.quarter = g10.quarter
             AND g.id_number = g10.id_number
             AND g.year = g10.year
    )

SELECT
    m.id_number as id_number,
    e.first_name || ' ' || e.last_name as full_name_title,
    e.last_name as last_name,
    e.last_name || ' ' || m.id_number as last_name_title,
    to_char(fiscal_year) as FY,
    quarter as quarter,
    nvl(maj_gft_comm_goal, 0) as major_gifts_committments_goal,
    nvl(maj_gft_comm_cnt, 0) as major_gifts_committments_cnt,
    nvl(maj_gft_sol_goal, 0) as major_gifts_solicitations_goal,
    nvl(maj_gft_sol_cnt, 0) as major_gifts_solicitations_cnt,
    CASE WHEN maj_gft_dol_goal != 0 THEN to_char(maj_gft_dol_goal, '999,999,999') ELSE to_char(maj_gft_dol_goal) END as major_gift_dollars_raised_goal,
    CASE WHEN maj_gft_dol_cnt != 0 THEN to_char(maj_gft_dol_cnt, '999,999,999') ELSE to_char(maj_gft_dol_cnt) END as major_gift_dollars_raised_cnt,
    nvl(visits_goal, 0) as visits_goal,
    nvl(visits_cnt, 0) as visits_cnt,
    nvl(qual_visits_goal, 0) as qualification_visits_goal,
    nvl(qual_visits_cnt, 0) as qualification_visits_cnt,
    nvl(prop_assist_goal, 0) as proposal_assists_goal,
    nvl(prop_assist_cnt, 0) as proposal_assists_cnt,
    ' ' as v_gift_plan_display,
    ' ' as v_gift_plan,
    ' ' as v_username,
    maj_gft_dol_goal as major_gft_dollars_raise_g_num,
    maj_gft_dol_cnt as major_gft_dollars_raise_g_cnt,
    CASE WHEN prop_ast_dls_goal != 0 THEN to_char(prop_ast_dls_goal, '999,999,999') ELSE to_char(prop_ast_dls_goal) END as proposal_ast_dls_raised_goal,
    CASE WHEN prop_ast_dls_cnt != 0 THEN to_char(prop_ast_dls_cnt, '999,999,999') ELSE to_char(prop_ast_dls_cnt) END as proposal_ast_dls_raised_count,
    nvl(prop_ast_com_goal, 0) as proposal_ast_num_com_goal,
    nvl(prop_ast_com_cnt, 0) as proposal_ast_nun_com_cnt,
    nvl(non_vst_con_goal, 0) as non_visit_contact_goal,
    nvl(non_vst_con_cnt, 0) as non_visit_contact_cnt,
    nvl(gft_plan_con_goal, 0) as gift_planning_consul_goal,
    nvl(gft_plan_con_cnt, 0) as gift_planning_consul_cnt,
    nvl(com_under_100K_cnt, 0) as comittments_under_100K,
    nvl(sol_under_100K_cnt, 0) as solicitations_under_100K,
    nvl(dlrs_rsd_under_100K_cnt, 0) as dollars_raised,
    nvl(prop_ast_under_100K_cnt, 0) as prop_ast_com_under_100K,
    nvl(prop_ast_dlrs_under_100K_cnt, 0) as prop_ast_dlrs_rsd_under_100K
FROM
    inline_om_2 m,
    entity e
WHERE
    e.id_number = m.id_number
AND
    m.table_type = 'S'
AND
    m.office_code = 'KM'
ORDER BY
    e.last_name asc,
    m.id_number,
    m.quarter asc
;
