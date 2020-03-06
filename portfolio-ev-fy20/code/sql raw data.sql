-- Household snapshot -- run once
/*
Drop Materialized View tmp_mv_hh
;

Create Materialized View tmp_mv_hh As
Select
  hh.*
  , cal.yesterday As data_as_of
From v_entity_ksm_households hh
Cross Join v_current_calendar cal
;
*/

--------------------
---- Base table ----
--------------------

-- Alumni
Select
  hh.household_id
  , hh.household_rpt_name
  , hh.household_spouse_id
  , hh.household_spouse_rpt_name
  , hh.record_status_code
  , hh.household_ksm_year
  , hh.household_masters_year
  , hh.household_last_masters_year
  , hh.household_program
  , hh.household_program_group
  , hh.data_as_of
From tmp_mv_hh hh
Where
  -- Primary only
  hh.household_primary = 'Y'
  -- Alumni only
  And hh.household_program_group Is Not Null
;

--------------------
---- Engagement ----
--------------------

-- Committees
Select
  hh.household_id
  , c.id_number
  , c.committee_code
  , c.committee_desc
  , c.committee_role_code
  , c.committee_role
  , c.committee_role_xsequence
  , c.ksm_committee
  , c.committee_status
  , c.start_dt_calc
  , c.stop_dt_calc
  , Case
      When c.committee_role_code In (
          'B', 'C', 'CC', 'CL', 'DAL', 'E', 'I', 'P', 'PE', 'RGD', 'T', 'TA', 'TC', 'TF', 'TL', 'TN', 'TO', 'V'
        )
        Then 'Y'
      When c.committee_code In (
          'KPH' -- PHS
          , 'UA' -- KAC (historical)
          , 'KACNA' -- KAC
          , 'U' -- GAB
          , 'KCC' -- Campaign Committee
          , 'KGAB' -- GAB (historical)
          , 'KACAS' -- KAC (historical)
          , 'KACEM' -- KAC (historical)
          , 'KACLA' -- KAC (historical)
          , 'KAMP' -- Asset Management
          , 'KCGN' -- Corporate Governance
          , 'CEW' -- Executive Women
          , 'KCDO' -- Diversity
        )
        Then 'Y'
      End
    As ksm_leader
From v_nu_committees c
Inner Join tmp_mv_hh hh
  On hh.id_number = c.id_number
Where c.committee_status_code In ('C', 'F', 'A', 'U') -- Current, Former, Active, Inactive; A/I for historic tracking
    And c.committee_role_code Not In ('EF') -- Our NU Follower
;

-- Events

-- Activities

--------------------
------ Giving ------
--------------------

-- Giving summary

-- NGC/Cash transactions (can include DAF flag)

-- Pledge schedule?

-- Gift clubs

--------------------
----- Prospect -----
--------------------

-- Evaluation

-- Contact

-- Visit

-- Program interest

-- Manager

--------------------
------ Biodata -----
--------------------

-- Employment

-- Have email

-- Have phone

-- Have address
