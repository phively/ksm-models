mdat <- mdat %>%
  
  # Derived variables
  mutate(
    
    # Ever made a pledge
      GIVING_PLEDGE_ANY = {GIVING_MAX_PLEDGE_AMT > 0} %>% factor()
      
    # Made a pledge when graduating
    , GIVING_PLEDGE_FIRST_YR = {GIVING_FIRST_YEAR_PLEDGE_AMT > 0} %>% factor()
  ) %>%
  
  # Keep variables from mdat deemed interesting
  select(
      GAVE_10K
    , RECORD_STATUS_CODE
    , RECORD_YR
    , PROGRAM_GROUP
    , PREF_ADDR_TYPE_CODE
    , HOUSEHOLD_CONTINENT
    , BUS_IS_EMPLOYED
    , HAS_HOME_ADDR
    , HAS_HOME_PHONE
    , HAS_HOME_EMAIL
    , GIVING_PLEDGE_ANY
    , GIVING_PLEDGE_FIRST_YR
    , GIFTS_ALLOCS_SUPPORTED
    , GIFTS_FYS_SUPPORTED
    , GIVING_MAX_CASH_YR
    , GIFTS_CASH
    , GIFTS_CREDIT_CARD
    , GIFTS_STOCK
    , GIFT_CLUB_KLC_YRS
    , GIFT_CLUB_NU_LDR_YRS
    , GIFT_CLUB_LOYAL_YRS
    , VELOCITY3
    , VELOCITY_BINS
    , VELOCITY3_LIN
  )