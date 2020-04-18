# Fill in start dates with either the valid date part (e.g. year only), or the date added
catracks$giv_giftclub <- catracks$giv_giftclub %>%
  mutate(
    START_DT_CALC = case_when(
      !is.na(START_DT) ~ as.Date(START_DT)
      , substr(GIFT_CLUB_START_DATE, 1, 4) == '0000' ~ as.Date(DATE_ADDED)
      , TRUE ~ ToDateCleaner(GIFT_CLUB_START_DATE)
    )
  )


# Set new attributes
attr(catracks$giv_giftclub, 'time_index') <- 'START_DT_CALC'

# Remove eval and contact without a valid date
catracks$prs_evaluation <- catracks$prs_evaluation %>%
  filter(!is.na(EVAL_DT))
catracks$prs_contact <- catracks$prs_contact %>%
  filter(!is.na(CONTACT_DATE))

# Remove unused fields
catracks$households <- catracks$households %>%
  select(-HOUSEHOLD_SPOUSE_ID, -HOUSEHOLD_SPOUSE_RPT_NAME, -DATA_AS_OF)
# Biodata
catracks$bio_address <- catracks$bio_address %>%
  select(-START_DT, -STOP_DT, -DATE_MODIFIED, -ADDR_TYPE_CODE)
catracks$bio_email <- catracks$bio_email %>%
  select(-EMAIL_TYPE_CODE, -START_DT, -STOP_DT)
catracks$bio_employment <- catracks$bio_employment %>%
  select(-START_DT, -STOP_DT, -JOB_TITLE, -EMPLOYER_NAME)
catracks$bio_phone <- catracks$bio_phone %>%
  select(-TELEPHONE_TYPE_CODE)
# Engagement
catracks$eng_activity <- catracks$eng_activity %>%
  select(-ID_NUMBER, -START_DT, -STOP_DT)
catracks$eng_committee <- catracks$eng_committee %>%
  select(-ID_NUMBER, -COMMITTEE_CODE, -COMMITTEE_ROLE_CODE, -COMMITTEE_ROLE_XSEQUENCE)
catracks$eng_event <- catracks$eng_event %>%
  select(-ID_NUMBER, -EVENT_ID)
# Giving
catracks$giv_giftclub <- catracks$giv_giftclub %>%
  select(-GIFT_CLUB_CODE, -GIFT_CLUB_START_DATE, -GIFT_CLUB_END_DATE, -STOP_DT)
catracks$giv_transactions <- catracks$giv_transactions %>%
  select(-TX_NUMBER, -TX_SEQUENCE, -MATCHED_TX_NUMBER, -PLEDGE_NUMBER)
# Prospect
catracks$prs_assignment <- catracks$prs_assignment %>%
  select(-ASSIGNMENT_TYPE, COMMITTEE_DESC)
catracks$prs_contact <- catracks$prs_contact %>%
  select(-CONTACT_CREDIT_TYPE)
catracks$prs_evaluation <- catracks$prs_evaluation %>%
  select(-EVALUATION_TYPE, -RATING_CODE)
catracks$prs_program <- catracks$prs_program %>%
  select(-PROGRAM_CODE, -START_DATE, -STOP_DATE)