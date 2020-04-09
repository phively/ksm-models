### Function to load Excel data into an R dataframe
fileloader <- function(filename, sheetnum) {
  read_xlsx(
    path = paste0('data/', filename)
    , sheet = sheetnum
    , guess_max = 1E7
  )
}

### Load all data into a list

catracks <- list(

  # Base table
  households = fileloader(paste(data_dt, 'Engagement data.xlsx'), 1) %>%
    # Factors
    mutate(
      RECORD_STATUS_CODE = factor(RECORD_STATUS_CODE)
      , HOUSEHOLD_PROGRAM = factor(HOUSEHOLD_PROGRAM)
      , HOUSEHOLD_PROGRAM_GROUP = factor(HOUSEHOLD_PROGRAM_GROUP)
    ) %>%
    # Numeric
    mutate_at(
      vars(ends_with('_YEAR'))
      , list(as.numeric)
    )
  
  # Biodata tables
  , bio_phone = fileloader(paste(data_dt, 'Phone data.xlsx'), 1) %>%
    mutate(
      TELEPHONE_TYPE_CODE = factor(TELEPHONE_TYPE_CODE)
      , TELEPHONE_TYPE = factor(TELEPHONE_TYPE)
      , BUSINESS_IND = BUSINESS_IND == 'Y'
      , CURRENT_IND = CURRENT_IND == 'Y'
      , TELEPHONE_STATUS_CODE = factor(TELEPHONE_STATUS_CODE)
    )
  
  , bio_address = fileloader(paste(data_dt, 'Address data.xlsx'), 1) %>%
    mutate(
      ADDR_TYPE_CODE = factor(ADDR_TYPE_CODE)
      , ADDR_TYPE = factor(ADDR_TYPE)
      , BUSINESS_IND = BUSINESS_IND == 'Y'
      , HBS_CODE = factor(HBS_CODE)
      , ADDR_STATUS_CODE = factor(ADDR_STATUS_CODE)
    )
  
  , bio_employment = fileloader(paste(data_dt, 'employment email.xlsx'), 1) %>%
    mutate(
      JOB_STATUS_CODE = factor(JOB_STATUS_CODE)
      , SELF_EMPLOY_IND = SELF_EMPLOY_IND == 'Y'
      , MATCHING_STATUS_IND = MATCHING_STATUS_IND == 'Y'
    )
  
  , bio_email = fileloader(paste(data_dt, 'employment email.xlsx'), 2) %>%
    mutate(
      EMAIL_TYPE_CODE = factor(EMAIL_TYPE_CODE)
      , EMAIL_TYPE = factor(EMAIL_TYPE)
      , EMAIL_STATUS_CODE = factor(EMAIL_STATUS_CODE)
    )
  
  # Engagement tables
  , eng_committee = fileloader(paste(data_dt, 'Engagement data.xlsx'), 2) %>%
    mutate(
      COMMITTEE_CODE = factor(COMMITTEE_CODE)
      , COMMITTEE_DESC = factor(COMMITTEE_DESC)
      , COMMITTEE_ROLE_CODE = factor(COMMITTEE_ROLE_CODE)
      , COMMITTEE_ROLE = factor(COMMITTEE_ROLE)
      , KSM_COMMITTEE = !is.na(KSM_COMMITTEE)
      , COMMITTEE_STATUS = factor(COMMITTEE_STATUS)
    )
  
  , eng_event = fileloader(paste(data_dt, 'Engagement data.xlsx'), 3) %>%
    mutate(
      EVENT_NAME = factor(EVENT_NAME)
      , KSM_EVENT = !is.na(KSM_EVENT)
      , EVENT_TYPE = factor(EVENT_TYPE)
    )
  
  , eng_activity = fileloader(paste(data_dt, 'Engagement data.xlsx'), 4) %>%
    mutate(
      ACTIVITY_DESC = factor(ACTIVITY_DESC)
      , KSM_ACTIVITY = !is.na(KSM_ACTIVITY)
      , ACTIVITY_PARTICIPATION_CODE = factor(ACTIVITY_PARTICIPATION_CODE)
    )
  
  # Giving tables
  , giv_transactions = fileloader(paste(data_dt, 'Gift transactions.xlsx'), 1) %>%
    mutate(
      TRANSACTION_TYPE = factor(TRANSACTION_TYPE)
      , TX_GYPM_IND = factor(TX_GYPM_IND)
      , ASSOCIATED_DESC = factor(ASSOCIATED_DESC)
      , PAYMENT_TYPE = factor(PAYMENT_TYPE)
      , ALLOC_SHORT_NAME = factor(ALLOC_SHORT_NAME)
      , AF_FLAG = !is.na(AF_FLAG)
      , CRU_FLAG = !is.na(CRU_FLAG)
      , PROPOSAL_ID = factor(PROPOSAL_ID)
    )
  
  , giv_giftclub = fileloader(paste(data_dt, 'Gift data.xlsx'), 2)  %>%
    mutate(
      GIFT_CLUB = factor(GIFT_CLUB)
      , GIFT_CLUB_CODE = factor(GIFT_CLUB_CODE)
      , GC_CATEGORY = factor(GC_CATEGORY)
    )
  
  # Prospect tables
  , prs_evaluation = fileloader(paste(data_dt, 'Prospect data.xlsx'), 1) %>%
    mutate(
      EVALUATION_TYPE = factor(EVALUATION_TYPE)
      , EVALUATION_DESC = factor(EVALUATION_DESC)
      , RATING_CODE = factor(RATING_CODE)
      , RATING_DESC = factor(RATING_DESC)
    )
  
  , prs_contact = fileloader(paste(data_dt, 'Prospect data.xlsx'), 2) %>%
    mutate(
      CONTACT_CREDIT_TYPE = factor(CONTACT_CREDIT_TYPE)
      , CONTACT_CREDIT_DESC = factor(CONTACT_CREDIT_DESC)
      , ARD_STAFF = !is.na(ARD_STAFF)
      , FRONTLINE_KSM_STAFF = !is.na(FRONTLINE_KSM_STAFF)
      , CONTACT_TYPE_CATEGORY = factor(CONTACT_TYPE_CATEGORY)
      , VISIT_TYPE = factor(VISIT_TYPE)
    )
  
  , prs_program = fileloader(paste(data_dt, 'Prospect data.xlsx'), 3) %>%
    mutate(
      PROGRAM_CODE = factor(PROGRAM_CODE)
      , PROGRAM = factor(PROGRAM)
    )
  
  , prs_assignment = fileloader(paste(data_dt, 'Prospect data.xlsx'), 4) %>%
    mutate(
      ASSIGNMENT_TYPE = factor(ASSIGNMENT_TYPE)
      , ASSIGNMENT_TYPE_DESC = factor(ASSIGNMENT_TYPE_DESC)
      , ASSIGNMENT_REPORT_NAME = factor(ASSIGNMENT_REPORT_NAME)
      , COMMITTEE_DESC = factor(COMMITTEE_DESC)
    )
  )

##### Set attributes for each data frame
attr(catracks$households, 'time_index') <- 'DATE_ADDED'
attr(catracks$bio_phone, 'time_index') <- 'DATE_ADDED'
attr(catracks$bio_address, 'time_index') <- 'DATE_ADDED'
attr(catracks$bio_employment, 'time_index') <- 'DATE_ADDED'
attr(catracks$bio_email, 'time_index') <- 'DATE_ADDED'
attr(catracks$eng_committee, 'time_index') <- 'START_DT_CALC'
attr(catracks$eng_event, 'time_index') <- 'START_DT_CALC'
attr(catracks$eng_activity, 'time_index') <- 'DATE_ADDED'
attr(catracks$giv_transactions, 'time_index') <- 'DATE_OF_RECORD'
attr(catracks$giv_giftclub, 'time_index') <- 'START_DT'
attr(catracks$prs_evaluation, 'time_index') <- 'EVAL_DT'
attr(catracks$prs_contact, 'time_index') <- 'CONTACT_DATE'
attr(catracks$prs_program, 'time_index') <- 'DATE_ADDED'
attr(catracks$prs_assignment, 'time_index') <- 'START_DT_CALC'