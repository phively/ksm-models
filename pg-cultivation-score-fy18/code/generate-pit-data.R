generate_pit_data <- function(filepath, sheetname) {

  # filepath argument is from the working folder, e.g. 'data/2017-12-01.csv', not from root
  # sheetname argument is the name of the Excel sheet to be imported

  ### Numeric discretizer helper function
  discretizer <- function(variable, n) {
    case_when(
      # Every entry >= n is replaced by string 'n+'
      variable >= n ~ paste(n, '+', sep = '')
      # Every other entry is converted to string
      , TRUE ~ paste(variable)
    )
  }
  
  ### Import the data
  
  full.data <- readxl::read_xlsx(
      path = filepath
    , sheet = sheetname
    , guess_max = 10000
    ) %>%
    
    # Drop any null rows
    filter(!is.na(RN)) %>%
    
    # Drop row numbers and date fields
    select(-RN, -TRAINING_FY, -TARGET_FY1, -TARGET_FY2, -DATA_AS_OF)
  
  ### Set column types
  
  full.data <- full.data %>%
    
    # Convert to numeric
    mutate(
      FIRST_KSM_YEAR = as.numeric(FIRST_KSM_YEAR)
      , SPOUSE_FIRST_KSM_YEAR = as.numeric(SPOUSE_FIRST_KSM_YEAR)
    ) %>%
    
    # Convert numeric NA to 0
    mutate_if(is.numeric, replace_na, replace = 0) %>%
    
    # Convert string NA to ''
    mutate_if(is.character, replace_na, replace = '') %>%
    
    # Convert to date
    mutate(
        # Text to date
        DOB = ToDate(BIRTH_DT, method = 'ymd')
    ) %>%
    
    # Convert certain character to factor
    mutate(
      
      # Factors
        RECORD_STATUS_CODE = factor(RECORD_STATUS_CODE) %>% relevel(ref = 'A') # Active
      , HOUSEHOLD_RECORD = factor(HOUSEHOLD_RECORD) %>% relevel(ref = 'AL') # Alumni
      , PROGRAM_GROUP = factor(PROGRAM_GROUP) %>% relevel(ref = 'FT') # Full-Time
      , PREF_ADDR_TYPE_CODE = factor(PREF_ADDR_TYPE_CODE) %>% relevel(ref = 'H') # Home
      , HOUSEHOLD_CITY = factor(HOUSEHOLD_CITY) %>% relevel(ref = 'Chicago')
      , HOUSEHOLD_STATE = factor(HOUSEHOLD_STATE) %>% relevel(ref = 'IL') # Illinois
      , HOUSEHOLD_COUNTRY = factor(HOUSEHOLD_COUNTRY) %>% relevel(ref = 'United States')
      , HOUSEHOLD_CONTINENT = factor(HOUSEHOLD_CONTINENT) %>% relevel(ref = 'North America')
      , CRU_STATUS = factor(CRU_STATUS) %>% relevel(ref = 'Never') # Never given to KSM
      , CRU_GIVING_SEGMENT = factor(CRU_GIVING_SEGMENT) %>% relevel(ref = 'Never') # Never given to KSM
      
      # Indicators
      , BUS_IS_EMPLOYED = factor(BUS_IS_EMPLOYED == 'Y')
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
      , KSM_GOS_FLAG = factor(KSM_GOS_FLAG == 'Y')
    )
  
  ### Modeling data
  
  mdata <- full.data %>%
    
    ## Filter out HH_PRIMARY = 'N'
    filter(HH_PRIMARY == 'Y') %>%
    
    ## Drop fields with unhelpful or very limited data
    select(
        -HH_PRIMARY
      , -KSM_FEATURED_COMM_TIMES
      , -KSM_CORP_RECRUITER_TIMES
      , -KSM_SPEAKER_TIMES
    ) %>%
    
    ## Derived variables
    mutate(
      
      # Record year based on class year, giving year, or record year
        RECORD_YR = case_when(
            FIRST_KSM_YEAR == 0 ~ ifelse(GIVING_FIRST_YEAR > 0, GIVING_FIRST_YEAR, year(ENTITY_DT_ADDED))
          , FIRST_KSM_YEAR < 1908 ~ 1908
          , TRUE ~ FIRST_KSM_YEAR
        )
      
      # Extract dates
      , GIVING_MAX_CASH_YR = ifelse(is.na(GIVING_MAX_CASH_DT), RECORD_YR, year(GIVING_MAX_CASH_DT))
      , GIVING_MAX_CASH_MO = ifelse(is.na(GIVING_MAX_CASH_DT), month(ENTITY_DT_ADDED), month(GIVING_MAX_CASH_DT))
          %>% factor()
      , GIVING_MAX_PLEDGE_YR = ifelse(is.na(GIVING_MAX_PLEDGE_DT), RECORD_YR, year(GIVING_MAX_PLEDGE_DT))
      , GIVING_MAX_PLEDGE_MO = ifelse(is.na(GIVING_MAX_PLEDGE_DT), month(ENTITY_DT_ADDED), month(GIVING_MAX_PLEDGE_DT))
          %>% factor()

      # HOUSEHOLD_RECORD: combine AL(umni) and ST(udent) levels
      , HOUSEHOLD_RECORD = fct_collapse(HOUSEHOLD_RECORD, AL = c('AL', 'ST'))

      # PROGRAM_GROUP: treat UNK as NULL
      , PROGRAM_GROUP = fct_collapse(PROGRAM_GROUP, NONE = c('UNK', ''))

      # For PREF_ADDR_TYPE_CODE combine:
      # H, UH into home (home, unverified home)
      # A, AH, S, UX into alternate home (alternate, alternate home, seasonal, unverified alt home)
      # AB, B, C, UB into business (alternate business, business, business 2, unverified business)
      # Ignore P, R, X, Z (past home, past alternate, email, telephone)
      , PREF_ADDR_TYPE_CODE = fct_collapse(PREF_ADDR_TYPE_CODE
          , HOM = c('H', 'UH',
                    'P', 'R', 'X', 'Z') # Unknown defaults to Home
          , ALT = c('A', 'AH', 'S', 'UX')
          , BUS = c('AB', 'B', 'C', 'UB')
      )

      # Combine KSM_PROSPECT_ACTIVE and KSM_PROSPECT_ANY
      , KSM_PROSPECT = case_when(
            KSM_PROSPECT_ACTIVE == TRUE ~ 'Current'
          , KSM_PROSPECT_ANY == TRUE ~ 'Past'
          , TRUE ~ 'No') %>% factor()

      # Indicator combining HAS_SEASONAL_ADDR with HAS_ALT_HOME_ADDR
      , HAS_ALT_HOME_OR_SEASONAL_ADDR = case_when(
            HAS_ALT_HOME_ADDR == 'TRUE' ~ 'TRUE'
          , HAS_SEASONAL_ADDR == 'TRUE' ~ 'TRUE'
          , TRUE ~ 'FALSE') %>% factor()

      # Drop international HOUSEHOLD_STATE values
      , HOUSEHOLD_STATE = fct_collapse(HOUSEHOLD_STATE
          , INTL = c(
              'AB', 'ACT', 'AE', 'AP', 'BC', 'MB', 'MP', 'NL', 'NS', 'NSW', 'ON', 'QC',
              'QLD', 'SA', 'SK', 'TAS', 'VIC', 'WAU'
            )
      )

      # Group U.S. states into Census regions
      , HOUSEHOLD_REGION = fct_collapse(HOUSEHOLD_STATE
          , NEWENG = c('CT', 'ME', 'MA', 'NH', 'RI', 'VT')
          , MIDATL = c('NJ', 'NY', 'PA')
          , MIDENC = c('IL', 'IN', 'MI', 'OH', 'WI')
          , MIDWNC = c('IA', 'KS', 'MN', 'MO', 'NE', 'ND', 'SD')
          , SOUATL = c('DE', 'DC', 'FL', 'GA', 'MD', 'NC', 'SC', 'VA', 'WV')
          , SOUESC = c('AL', 'KY', 'MS', 'TN')
          , SOUWSC = c('AR', 'LA', 'OK', 'TX')
          , WSTMNT = c('AZ', 'CO', 'ID', 'MT', 'NV', 'NM', 'UT', 'WY')
          , WSTPAC = c('AK', 'CA', 'HI', 'OR', 'WA')
          , INTL = c('INTL', 'PR', 'VI')
      )

      # KSM_CORP_RECRUITER_YEARS treated as binary
      , KSM_CORP_RECRUITER_YEARS = discretizer(KSM_CORP_RECRUITER_YEARS, 1)
          %>% factor()

      # Discretize GIFTS_CREDIT_CARD into 0, 1, 2+
      , GIFTS_CREDIT_CARD = discretizer(GIFTS_CREDIT_CARD, 2)
          %>% factor()

      # GIFTS_STOCK treated as binary
      , GIFTS_STOCK = discretizer(GIFTS_STOCK, 1)
          %>% factor()

      # GIFT_CLUB_BEQUEST_YRS treated as binary
      , GIFT_CLUB_BEQUEST_YRS = discretizer(GIFT_CLUB_BEQUEST_YRS, 1)
          %>% factor()

      # KSM_SPEAKER_YEARS treated as binary
      , KSM_SPEAKER_YEARS = discretizer(KSM_SPEAKER_YEARS, 1)
          %>% factor()

      # Discretize KSM_EVENTS_REUNIONS into 0, 1, 2, 3+
      , KSM_EVENTS_REUNIONS = discretizer(KSM_EVENTS_REUNIONS, 3)
          %>% factor()

      # KSM_FEATURED_COMM_YEARS treated as binary
      , KSM_FEATURED_COMM_YEARS = discretizer(KSM_FEATURED_COMM_YEARS, 1)
          %>% factor()

      # GIFT_CLUB_NU_LDR_YRS treated as binary
      , GIFT_CLUB_NU_LDR_YRS = discretizer(GIFT_CLUB_NU_LDR_YRS, 1)
          %>% factor()

      # Total visits
      , VISITS_5FY = VISITS_CFY + VISITS_PFY1 + VISITS_PFY2 + VISITS_PFY3 + VISITS_PFY4

      # Total visitors
      , VISITORS_5FY = VISITORS_CFY + VISITORS_PFY1 + VISITORS_PFY2 + VISITORS_PFY3 + VISITORS_PFY4

      # X-out-of-5 loyalty
      # 1/5 * [1{CASH_PFY1 > 0} + 1{CASH_PFY2 > 0} + 1{CASH_PFY3 > 0} + 1{CASH_PFY4 > 0} + 1{CASH_PFY5 > 0}]
      , LOYAL_5_PCT_CASH = 1/5 * {
          ifelse(CASH_PFY1 > 0, 1, 0)
        + ifelse(CASH_PFY2 > 0, 1, 0)
        + ifelse(CASH_PFY3 > 0, 1, 0)
        + ifelse(CASH_PFY4 > 0, 1, 0)
        + ifelse(CASH_PFY5 > 0, 1, 0)
      }
      
      # X-out-of-5 loyalty for cash gifts or pledges
      , LOYAL_5_PCT_ANY = 1/5 * {
          ifelse(CASH_PFY1 + NGC_PFY1 > 0, 1, 0)
        + ifelse(CASH_PFY2 + NGC_PFY2 > 0, 1, 0)
        + ifelse(CASH_PFY3 + NGC_PFY3 > 0, 1, 0)
        + ifelse(CASH_PFY4 + NGC_PFY4 > 0, 1, 0)
        + ifelse(CASH_PFY5 + NGC_PFY5 > 0, 1, 0)
      }
      
      # UPGRADE3: net upgrades/downgrades in FY-1, FY-2, FY-3 (+2 to -2)
      # sign(FY1 - FY2)  + sign(FY2 - FY1)
      # 2 downgrades in a row would be -2, a downgrade followed by steady or steady then downgrade is -1,
      # no change or a downgrade followed by an upgrade or upgrade then downgrade is 0, etc.
      , UPGRADE3_CASH = {
          sign(CASH_PFY1 - CASH_PFY2) + sign(CASH_PFY2 - CASH_PFY3)
      } %>% factor()
      , UPGRADE3_NGC = {
          sign(NGC_PFY1 - NGC_PFY2) + sign(NGC_PFY2 - NGC_PFY3)
      } %>% factor()

      # Giving velocity definitions

      # VELOCITY3 is the Blackbaud definition
      , vdenom = 1/3 * (CASH_PFY2 + CASH_PFY3 + CASH_PFY4)
      , VELOCITY3_CASH = CASH_PFY1 / ifelse(vdenom == 0, max(CASH_PFY1, 1E-99), vdenom)
      
      , vdenomngc = 1/3 * (NGC_PFY2 + NGC_PFY3 + NGC_PFY4)
      , VELOCITY3_NGC = NGC_PFY1 / ifelse(vdenomngc == 0, max(NGC_PFY1, 1E-99), vdenomngc)
      
      # VELOCITY3 discretized based on data exploration
      , VELOCITY_BINS_CASH = case_when(
          CASH_PFY1 == 0 & vdenom == 0 ~ 'A. Non'
        , VELOCITY3_CASH < 1E-8 ~ 'B. Way down'
        , VELOCITY3_CASH < 1E-2 ~ 'C. Moderate down'
        , VELOCITY3_CASH < 1 ~ 'D. Slight down'
        , VELOCITY3_CASH == 1 ~ 'E. Unchanged'
        , VELOCITY3_CASH > 1 ~ 'F. Up'
      ) %>% factor()
      
      , VELOCITY_BINS_NGC = case_when(
          NGC_PFY1 == 0 & vdenomngc == 0 ~ 'A. Non'
        , VELOCITY3_NGC < 1E-8 ~ 'B. Way down'
        , VELOCITY3_NGC < 1E-2 ~ 'C. Moderate down'
        , VELOCITY3_NGC < 1 ~ 'D. Slight down'
        , VELOCITY3_NGC == 1 ~ 'E. Unchanged'
        , VELOCITY3_NGC > 1 ~ 'F. Up'
      ) %>% factor()
      
      # Alternate velocity definition: linear signed difference rather than ratio
      , vavg = 1/3 * (CASH_PFY2 + CASH_PFY3 + CASH_PFY4)
      , VELOCITY3_LIN_CASH = CASH_PFY1 - vavg
      , VELOCITY3_LIN_CASH = log10(abs(VELOCITY3_LIN_CASH) + 1) * sign(VELOCITY3_LIN_CASH)
      
      , vavgngc = 1/3 * (NGC_PFY2 + NGC_PFY3 + NGC_PFY4)
      , VELOCITY3_LIN_NGC = NGC_PFY1 - vavgngc
      , VELOCITY3_LIN_NGC = log10(abs(VELOCITY3_LIN_NGC) + 1) * sign(VELOCITY3_LIN_NGC)
      
      # Binary indicator for $10K+ cash donors
      , GAVE_10K = ifelse(GIVING_MAX_CASH_AMT >= 10000, 1, 0)
      
    ) %>%
    
    ## Clean up columns that are no longer needed
    select(
        -DOB
      , -ENTITY_DT_ADDED
      , -KSM_PROSPECT_ACTIVE
      , -KSM_PROSPECT_ANY
      , -HAS_ALT_HOME_ADDR
      , -HAS_SEASONAL_ADDR
      , -GIVING_MAX_CASH_DT
      , -GIVING_MAX_PLEDGE_DT
      , -VISITS_CFY
      , -VISITS_PFY1
      , -VISITS_PFY2
      , -VISITS_PFY3
      , -VISITS_PFY4
      , -VISITORS_CFY
      , -VISITORS_PFY1
      , -VISITORS_PFY2
      , -VISITORS_PFY3
      , -VISITORS_PFY4
      , -vdenom
      , -vavg
      , -vdenomngc
      , -vavgngc
    )
  
  return(mdata)
  
}

generate_additional_predictors <- function(dataframe, future.data = FALSE, giving.threshold = 0) {
  dataframe %>%
  mutate(
    # Create response variables
    # Set to 0 if they are in the future
    rv.amt = case_when(
      future.data == FALSE ~ NGC_TARGET_FY2 + NGC_TARGET_FY1
      , future.data == TRUE ~ 0
    )
    , rv.gave = rv.amt > giving.threshold
  ) %>% select(
    # Drop future data
    -NGC_TARGET_FY2
    , -NGC_TARGET_FY1
    , -CASH_TARGET_FY2
    , -CASH_TARGET_FY1
    , -PLEDGE_TARGET_FY2
    , -PLEDGE_TARGET_FY1
    , -AF_TARGET_FY2
    , -AF_TARGET_FY1
    , -CRU_TARGET_FY2
    , -CRU_TARGET_FY1
  ) %>% filter(
    # Drop entities whose RECORD_YR is after the training year
    RECORD_YR <= train_fy
  ) %>%
    mutate(
      # Create spouse flag
      SPOUSE_ALUM = ifelse(SPOUSE_FIRST_KSM_YEAR > 0, 'TRUE', 'FALSE') %>% factor()
      # Lump together little-used continents
      , HOUSEHOLD_CONTINENT = fct_lump(HOUSEHOLD_CONTINENT, prop = .02)
      # Lump together little-used regions
      , HOUSEHOLD_REGION = fct_collapse(
        HOUSEHOLD_REGION
        , 'NB' = 'INTL'
      )
    ) %>% mutate_if(
      # Numeric variables over 1E4 get a log10 transformation
      function(x) {
        ifelse(is.numeric(x), max(x) >= 1E4, FALSE)
      }
      , log10plus1
    ) %>% mutate(
      YEARS_SINCE_FIRST_GIFT = train_fy - ifelse(GIVING_FIRST_YEAR > 0, GIVING_FIRST_YEAR, train_fy + 1)
      , YEARS_SINCE_ATHLETICS_TICKETS = train_fy - ifelse(ATHLETICS_TICKET_LAST > 0, ATHLETICS_TICKET_LAST, train_fy + 1)
      , YEARS_SINCE_MAX_CASH_YR = train_fy - ifelse(GIVING_MAX_CASH_YR > 0, GIVING_MAX_CASH_YR, train_fy + 1)
    )
}
