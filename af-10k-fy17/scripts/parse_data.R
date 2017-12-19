parse_data <- function(filepath) {

  # Filepath argument is from the working folder, e.g. 'data/2017-12-01.csv', not from root
  
  ### Import the data
  full.data <- read.csv(
    'filepath'
    , stringsAsFactors = FALSE
    , strip.white = TRUE
    , colClasses = c(
        'ID_NUMBER' = 'character'
        , 'HOUSEHOLD_ID' = 'character'
        , 'BIRTH_DT' = 'character'
        , 'GIVING_MAX_CASH_DT' = 'character'
        , 'GIVING_MAX_PLEDGE_DT' = 'character'
      )
    ) %>%
    # Drop any null rows
    filter(!is.na(RN)) %>%
    # Drop row numbers
    select(-RN)
  
  ### Set column types
  full.data <- full.data %>%
    # Convert NA to 0
    mutate_all(
      funs(
        ifelse(is.na(.), 0, .)
      )
    ) %>%
    # Convert to date
    mutate(
      DOB = ToDate(BIRTH_DT, method = 'ymd')
      , GIVING_MAX_CASH_DT = ToDate(GIVING_MAX_CASH_DT, method = 'mdy')
      , GIVING_MAX_PLEDGE_DT = ToDate(GIVING_MAX_CASH_DT, method = 'mdy')
    ) %>%
    # Extract dates
    mutate(
      GIVING_MAX_CASH_YR = year(GIVING_MAX_CASH_DT)
      , GIVING_MAX_CASH_MO = month(GIVING_MAX_CASH_DT) %>% factor()
    ) %>%
    # Convert certain character to factor
    mutate(
      # Factors
      RECORD_STATUS_CODE = factor(RECORD_STATUS_CODE) %>% relevel(ref = 'A') # Active
      , HOUSEHOLD_RECORD = factor(HOUSEHOLD_RECORD) %>% relevel(ref = 'AL') # Alumni
      , PROGRAM_GROUP = factor(PROGRAM_GROUP) %>% relevel(ref = 'FT') # Full-Time
      , PREF_ADDR_TYPE_CODE = factor(PREF_ADDR_TYPE_CODE) %>% relevel(ref = 'H') # Home
      , HOUSEHOLD_STATE = factor(HOUSEHOLD_STATE) %>% relevel(ref = 'IL') # Illinois
      , HOUSEHOLD_COUNTRY = factor(HOUSEHOLD_COUNTRY) %>% relevel(ref = 'United States')
      , HOUSEHOLD_CONTINENT = factor(HOUSEHOLD_CONTINENT) %>% relevel(ref = 'North America')
      , EVALUATION_RATING = factor(EVALUATION_RATING) %>% relevel(ref = '') # Unrated
      # Indicators
      , BUS_IS_EMPLOYED = factor(BUS_IS_EMPLOYED == 'Y')
      , BUS_HIGH_LVL_JOB_TITLE = factor(BUS_HIGH_LVL_JOB_TITLE != '')
      , BUS_CAREER_SPEC_FINANCE = factor(BUS_CAREER_SPEC_FINANCE != '')
      , BUS_GIFT_MATCH = factor(BUS_GIFT_MATCH == 'Y')
      , HAS_HOME_ADDR = factor(HAS_HOME_ADDR == 'Y')
      , HAS_ALT_HOME_ADDR = factor(HAS_ALT_HOME_ADDR == 'Y')
      , HAS_BUS_ADDR = factor(HAS_BUS_ADDR == 'Y')
      , HAS_SEASONAL_ADDR = factor(HAS_SEASONAL_ADDR == 'Y')
      , HAS_HOME_PHONE = factor(HAS_HOME_PHONE == 'Y')
      , HAS_BUS_PHONE = factor(HAS_BUS_PHONE == 'Y')
      , HAS_MOBILE_PHONE = factor(HAS_MOBILE_PHONE == 'Y')
      , HAS_HOME_EMAIL = factor(HAS_HOME_EMAIL == 'Y')
      , HAS_BUS_EMAIL = factor(HAS_BUS_EMAIL == 'Y')
      , KSM_PROSPECT_ACTIVE = factor(KSM_PROSPECT_ACTIVE == 'Y')
      , KSM_PROSPECT_ANY = factor(KSM_PROSPECT_ANY == 'Y')
    )

  ### Filter out HH_PRIMARY = 'N'
  
  ### Drop fields with unhelpful or very limited data
  # HH_PRIMARY
  # BUS_GIFT_MATCH
  # GIVING_CASH_TOTAL
  # GIVING_PLEDGE_TOTAL
  # GIVING_NGC_TOTAL
  # COMMITTEE_NU_ACTIVE
  # COMMITTEE_KSM_ACTIVE
  # COMMITTEE_KSM_LDR_ACTIVE
  # KSM_FEATURED_COMM_TIMES
  # KSM_CORP_RECRUITER_TIMES
  
  ### Transformed response variable GIVING_MAX_CASH_AMT
  # log10()
    
  ### Derived age from DOB or class year
  
  ### Combine AL(umni) and ST(udent) HOUSEHOLD_RECORD
  
  ### Treat UNK as NULL (PROGRAM_GROUP)
  
  ### For PREF_ADDR_TYPE_CODE combine:
  # H, UH into home (home, unverified home)
  # A, AH, S, UX into alternate home (alternate, alternate home, seasonal, unverified alt home)
  # AB, B, C, UB into business (alternate business, business, business 2, unverified business)
  # Drop P, R, X, Z (past home, past alternate, email, telephone)
  
  # Also: indicator combining HAS_SEASONAL_ADDR with HAS_ALT_HOME_ADDR
  
  ### Drop international HOUSEHOLD_STATE
  # AB, ACT, AE, AP, BC, MB, MP, NL, NS, NSW, ON, QC, QLD, SA, SK, TAS, VIC, WAU
  
  # Also: derived regions? E.g. census area for smaller states?
  
  ### Combine KSM_PROSPECT_ACTIVE and KSM_PROSPECT_ANY
  full.data <- full.data %>%
    mutate(
      KSM_PROSPECT = case_when(
        KSM_PROSPECT_ACTIVE == TRUE ~ 'Current'
        , KSM_PROSPECT_ANY == TRUE ~ 'Past'
        , TRUE ~ 'No') %>% factor()
  ) %>%
  # Drop fields that were transformed above
  select(
    -KSM_PROSPECT_ACTIVE
    , -KSM_PROSPECT_ANY
  )
  
  ### Binary indicators
  # KSM_CORP_RECRUITER_YEARS
  
}
