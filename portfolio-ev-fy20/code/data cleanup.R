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