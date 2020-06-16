With

params As (
  Select
    2018 As prev_year
    , 2010 As committee_year
    , 2015 As giving_year
  From DUAL
)

, profiles As (
  Select
    id_number
    , Case
        When id_number In ('0000289909', '0000328657', '0000422285', '0000442251', '0000472484', '0000468514', '0000500947', '0000501039', '0000532191', '0000609747')
          Then 'Career'
        When id_number In ('0000288051', '0000289872', '0000288836', '0000301415', '0000349552', '0000469048')
          Then 'Connector'
        When id_number In ('0000285633', '0000282370', '0000306070', '0000334687', '0000386791', '0000368381', '0000391452', '0000442458')
          Then 'Notable'
        When id_number In ('0000292424', '0000336938', '0000403660', '0000441983', '0000484221')
          Then 'Student Supporter'
        End
      As tag
  From entity
  Where id_number In (
    '0000288051'
    , '0000289872'
    , '0000289909'
    , '0000285633'
    , '0000288836'
    , '0000282370'
    , '0000306070'
    , '0000301415'
    , '0000292424'
    , '0000328657'
    , '0000336938'
    , '0000334687'
    , '0000349552'
    , '0000386791'
    , '0000368381'
    , '0000403660'
    , '0000422285'
    , '0000391452'
    , '0000442251'
    , '0000441983'
    , '0000442458'
    , '0000472484'
    , '0000469048'
    , '0000468514'
    , '0000484221'
    , '0000500947'
    , '0000501039'
    , '0000532191'
    , '0000609747'
  )
)

, kac As (
  Select
    id_number
    , 'KAC' As kac
  From table(ksm_pkg.tbl_committee_kac)
)

, kalc As (
  Select
    id_number
    , 'KALC' As kalc
  From table(ksm_pkg.tbl_committee_kalc)
)

, club As (
  Select
    id_number
    , club_title
  From rpt_ssh5552.v_ksm_club_leaders
)

, gab As (
  Select
    id_number
    , 'GAB' As gab
  From table(ksm_pkg.tbl_committee_gab)
)

, magazine_and_speaker As (
  Select
    id_number
    , count(Case When activity_code = 'KCF' Then 1 End)
      As comm_feature
    , count(Case When activity_code = 'KSM' Then 1 End)
      As magazine
    , count(Case When activity_code = 'KSP' Then 1 End)
      As speaker
  From activity
  Where activity_code In ('KSM', 'KCF', 'KSP')
  Group By id_number
)

, dean_visits As (
  Select
    id_number
    , count(id_number)
      As dean_visits
  From rpt_pbh634.v_contact_reports_fast
  Where credited = '0000804796'
    And contact_type = 'Visit'
  Group By id_number
)

, all_ids As (
  Select id_number From profiles
  Union
  Select id_number From kac
  Union
  Select id_number From kalc
  Union
  Select id_number From club
  Union
  Select id_number From gab
  Union
  Select id_number From magazine_and_speaker
  Union
  Select id_number From dean_visits
)

-- Current home and business address city/state/country
, addr_raw As (
  Select
    id_number
    , start_dt
    , stop_dt
    , date_added
    , date_modified
    , addr_type_code
    , addr_status_code
    , address.city
    , address.foreign_cityzip
    , address.state_code
    , c.country
    , Case
        When start_dt Is Not Null
          And substr(start_dt, 1, 4) <> '0000'
          And substr(start_dt, 5, 2) <> '00'
            Then rpt_pbh634.ksm_pkg.get_fiscal_year(to_date(substr(start_dt, 1, 6) || '01', 'yyyymmdd'))
        Else rpt_pbh634.ksm_pkg.get_fiscal_year(date_added)
        End
      As start_fy_calc
    , Case
        When stop_dt Is Not Null
          And addr_status_code <> 'A'
          And substr(stop_dt, 1, 4) <> '0000'
          And substr(stop_dt, 5, 2) <> '00'
            Then rpt_pbh634.ksm_pkg.get_fiscal_year(to_date(substr(stop_dt, 1, 6) || '01', 'yyyymmdd'))
        When addr_status_code <> 'A'
          Then rpt_pbh634.ksm_pkg.get_fiscal_year(date_modified)
        Else NULL
        End
      As stop_fy_calc
  From address
  Left Join v_addr_continents c
    On c.country_code = address.country_code
  Where addr_type_code In ('H', 'B', 'AH', 'AB', 'S') -- Home, Bus, Alt Home, Alt Bus, Seasonal
)
, home_addr As (
  Select
    id_number
    , trim(
        trim(city) || trim(foreign_cityzip) || chr(13) ||
        Case
          When country = 'United States'
            Then trim(state_code)
          Else trim(country)
          End
      )
      As home_address
  From addr_raw
  Where addr_type_code = 'H'
    And addr_status_code = 'A'
)
, bus_addr As (
  Select
    id_number
    , trim(
        trim(city) || trim(foreign_cityzip) || chr(13) ||
        Case
          When country = 'United States'
            Then trim(state_code)
          Else trim(country)
          End
      )
      As bus_address
  From addr_raw
  Where addr_type_code = 'B'
    And addr_status_code = 'A'
)

-- Current job/company
, curr_employ As (
  Select
    de.catracks_id
      As id_number
    , de.primary_job_title
      As current_job_title
    , trim(de.primary_employer)
      As current_employer
    , de.primary_job_source
  From v_datamart_entities de
)

-- Other current or recent job/company
, job_history As (
  Select
    catracks_id As id_number
    , employment_start_date
    , employment_stop_date
    , job_title
    , employer
    , fld_of_work_desc
  From v_datamart_employment
  Cross Join params
  Where primary_employer_indicator <> 'Y'
    And employer <> 'Pre-BSR Employment Information'
    And (
      -- Current or recent only
      job_status_code = 'C'
      Or ksm_pkg.get_fiscal_year(employment_stop_date) >= params.prev_year
    )
)
, job_history_concat As (
  Select
    id_number
    , Listagg(job_title || ', ' || employer, chr(13)) Within Group (Order By employment_stop_date Desc Nulls Last)
      As recent_jobs
    , Listagg(fld_of_work_desc, chr(13)) Within Group (Order By employment_stop_date Desc Nulls Last)
      As recent_fields
    , count(job_title || employer)
      As recent_jobs_count
  From job_history
  Group By id_number
)

-- Career interests
, career_interests As (
  Select Distinct
    catracks_id As id_number
    , interest_desc
  From v_datamart_career_interests
)
, career_interests_concat As (
  Select
    id_number
    , Listagg(interest_desc, '; ') Within Group (Order By interest_desc Asc)
      As career_interests
    , count(interest_desc)
      As career_interests_count
  From career_interests intr
  Group By id_number
)

-- Visits last 3 years
, recent_visits As (
  Select
    crf.id_number
    , crf.fiscal_year
    , crf.report_id
    , trunc(crf.contact_date)
      As contact_date
    , crf.credited
      As author_id
    , crf.credited_name
      As author_name
  From v_contact_reports_fast crf
  Cross Join params
  Where crf.fiscal_year >= params.prev_year
    And crf.contact_type_code = 'V'
)
, recent_visits_dedupe As (
  Select
    id_number
    , author_name
    , max(fiscal_year) keep(dense_rank first order by contact_date desc)
      As last_contact_year
    , max(contact_date) keep(dense_rank first order by contact_date desc)
      As last_contact_date
    , count(contact_date)
      As visits
  From recent_visits
  Group By
    id_number
    , author_name
)
, recent_visits_concat As (
  Select
    id_number
    , Listagg(author_name || ' (' || last_contact_year || ')', chr(13)) Within Group (Order By last_contact_date Desc)
      As most_recent_visits
    , sum(visits)
      As total_visits
    , count(author_name)
      As total_visitors
  From recent_visits_dedupe
  Group By id_number
)

-- Committees last several years
, recent_committees As (
  Select
    id_number
    , committee_desc
    , start_dt_calc
    , stop_dt_calc
    , ksm_pkg.get_fiscal_year(stop_dt_calc)
      As fiscal_year
  From v_nu_committees
  Cross Join params
  Where committee_status_code = 'C'
    Or ksm_pkg.get_fiscal_year(stop_dt_calc) >= params.committee_year
)
, committees_dedupe As (
  Select
    id_number
    , committee_desc
    , max(fiscal_year) keep(dense_rank first order by stop_dt_calc desc, start_dt_calc asc)
      As last_committee_year
    , max(stop_dt_calc) keep(dense_rank first order by stop_dt_calc desc, start_dt_calc asc)
      As last_stop_dt
    , count(committee_desc)
      As committees_count
  From recent_committees
  Group By
    id_number
    , committee_desc
)
, committees_concat As (
  Select
    id_number
    , Listagg(committee_desc || ' (' || last_committee_year || ')', chr(13)) Within Group (Order By last_stop_dt Desc Nulls Last)
      As current_and_recent_committees
    , sum(committees_count)
      As total_committees
    , count(committees_count)
      As distinct_committees
  From committees_dedupe
  Group By id_number
)

-- Events last 3 years
, recent_events As (
  Select Distinct
    id_number
    , event_id
    , event_name
    , start_dt_calc
    , start_fy_calc
  From v_nu_event_participants_fast epf
  Cross Join params
  Where epf.start_fy_calc >= params.prev_year
    And ksm_event = 'Y'
)
, recent_events_concat As (
  Select
    id_number
    , Listagg(event_name || ' (' || start_fy_calc || ')', chr(13)) Within Group (Order By start_dt_calc Desc)
      As all_recent_ksm_events
    , count(event_name)
      As total_events
  From recent_events
  Group By id_number
)

-- Activities last several years
, recent_activities As (
  Select
    id_number
    , activity_desc
    , start_fy_calc
  From v_nu_activities_fast vaf
  Cross Join params
  Where start_fy_calc >= params.committee_year
    And vaf.ksm_activity = 'Y'
)
, activities_dedupe As (
  Select
    id_number
    , activity_desc
    , max(start_fy_calc) keep(dense_rank first order by start_fy_calc desc)
      As last_activity_year
    , count(activity_desc)
      As activities_count
  From recent_activities
  Group By
    id_number
    , activity_desc
)
, activities_concat As (
  Select
    id_number
    , Listagg(activity_desc || ' (' || last_activity_year || ')', chr(13)) Within Group (Order By last_activity_year Desc, activity_desc Asc)
      As recent_ksm_activities
    , sum(activities_count)
      As total_activities
  From activities_dedupe
  Group By id_number
)

-- KLC
, klc As (
  Select Distinct
    gc.gift_club_id_number
      As id_number
    , gct.club_description
    , Case
        When substr(gc.gift_club_end_date, 1, 4) <> '0000'
          And substr(gc.gift_club_end_date, 5, 2) <> '00'
            Then to_number(substr(gc.gift_club_end_date, 1, 4)) +
              (Case When to_number(substr(gc.gift_club_end_date, 5, 2)) >= 9 Then 1 Else 0 End)
        When substr(gc.gift_club_end_date, 1, 4) <> '0000'
          Then to_number(substr(gc.gift_club_end_date, 1, 4))
        Else ksm_pkg.get_fiscal_year(gc.date_added)
        End
      As stop_fy_calc
  From gift_clubs gc
  Inner Join gift_club_table gct
    On gct.club_code = gc.gift_club_code
  Cross Join params
  Where gct.club_status = 'A' -- Only currently active gift clubs
    And gift_club_code = 'LKM'
)
, klc_concat As (
  Select
    id_number
    , Listagg('KLC ' || stop_fy_calc, chr(13)) Within Group (Order By stop_fy_calc Desc)
      As klc_last_5_years
    , count(stop_fy_calc)
      As klc_years_count
  From klc
  Cross Join params
  Where stop_fy_calc >= params.giving_year
  Group By id_number
)

-- Campaign priorities supported
, campaign_priority As (
  Select Distinct
    id_number
    , Case
        When alloc_code In ('3303000891301GFT', '3203000854501GFT') -- AF, Dean's Discretionary
          Then 'Annual Fund (Unrestricted)'
        Else ksm_campaign_category
        End
      As priorities_supported
  From vt_ksm_campaign_2008_fast
)
, campaign_concat As (
  Select
    id_number
    , Listagg(priorities_supported, chr(13)) Within Group (Order By priorities_supported Asc)
      As campaign_priorities_supported
    , count(priorities_supported)
      As priorities_supported_count
  From campaign_priority
  Group By id_number
)

-- Main query
Select
  a.id_number
  , entity.report_name
  , entity.institutional_suffix
  , v_random_id.random_id
  , entity.gender_code
  , tms_race.short_desc
    As ethnicity
  , deg.first_ksm_year
  , deg.program_group
  -- Flags and counts
  , profiles.tag
  , kac.kac
  , kalc.kalc
  , club.club_title
  , gab.gab
  , magazine_and_speaker.comm_feature
  , magazine_and_speaker.magazine
  , magazine_and_speaker.speaker
  , dean_visits.dean_visits
  , job_history_concat.recent_jobs_count
  , career_interests_concat.career_interests_count
  , recent_visits_concat.total_visitors
  , recent_visits_concat.total_visits
  , committees_concat.total_committees
  , committees_concat.distinct_committees
  , recent_events_concat.total_events
  , activities_concat.total_activities
  , klc_concat.klc_years_count
  , campaign_concat.priorities_supported_count
  -- Descriptions
  , home_addr.home_address
  , bus_addr.bus_address
  , curr_employ.current_job_title
  , curr_employ.current_employer
  , job_history_concat.recent_jobs
  , job_history_concat.recent_fields
  , career_interests_concat.career_interests
  , recent_visits_concat.most_recent_visits
  , committees_concat.current_and_recent_committees
  , recent_events_concat.all_recent_ksm_events
  , activities_concat.recent_ksm_activities
  , klc_concat.klc_last_5_years
  , campaign_concat.campaign_priorities_supported
From all_ids a
Inner Join entity
  On a.id_number = entity.id_number
Inner Join v_random_id
  On v_random_id.id_number = entity.id_number
Left Join tms_race
  On tms_race.ethnic_code = entity.ethnic_code
Left Join v_entity_ksm_degrees deg
  On deg.id_number = entity.id_number
Left Join home_addr
  On home_addr.id_number = entity.id_number
Left Join bus_addr
  On bus_addr.id_number = entity.id_number
Left Join profiles
  On profiles.id_number = entity.id_number
Left Join kac
  On kac.id_number = entity.id_number
Left Join kalc
  On kalc.id_number = entity.id_number
Left Join club
  On club.id_number = entity.id_number
Left Join gab
  On gab.id_number = entity.id_number
Left Join magazine_and_speaker
  On magazine_and_speaker.id_number = entity.id_number
Left Join dean_visits
  On dean_visits.id_number = entity.id_number
Left Join curr_employ
  On curr_employ.id_number = entity.id_number
Left Join job_history_concat
  On job_history_concat.id_number = entity.id_number
Left Join career_interests_concat
  On career_interests_concat.id_number = entity.id_number
Left Join recent_visits_concat
  On recent_visits_concat.id_number = entity.id_number
Left Join committees_concat
  On committees_concat.id_number = entity.id_number
Left Join recent_events_concat
  On recent_events_concat.id_number = entity.id_number
Left Join activities_concat
  On activities_concat.id_number = entity.id_number
Left Join klc_concat
  On klc_concat.id_number = entity.id_number
Left Join campaign_concat
  On campaign_concat.id_number = entity.id_number
