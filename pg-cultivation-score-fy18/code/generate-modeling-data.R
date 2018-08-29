mdat <- pool %>% mutate(
  # Impute missing ages as mean age
  NUMERIC_AGE = case_when(
    !is.na(NUMERIC_AGE) ~ NUMERIC_AGE
    , TRUE ~ mean(NUMERIC_AGE, na.rm = TRUE)
  )
  # Impute missing affinity scores as mean affinity score
  , AFFINITY_SCORE = case_when(
    !is.na(AFFINITY_SCORE) ~ AFFINITY_SCORE
    , TRUE ~ mean(AFFINITY_SCORE, na.rm = TRUE)
  )
  # Create null factor levels for the MG_ID and MG_PR models
  , MG_ID_MODEL_DESC = fct_explicit_na(MG_ID_MODEL_DESC, 'Unscored') %>% fct_relevel('Unscored')
  , MG_PR_MODEL_DESC = fct_explicit_na(MG_PR_MODEL_DESC, 'Unscored') %>% fct_relevel('Unscored')
  # Create row numbers
  , rownum = 1:nrow(pool)
) %>% select(
  # Drop unhelpful fields
  -ID_NUMBER, -PROSPECT_ID, -PROSPECT_NAME, -NU_DEG, -NU_DEG_SPOUSE, -POTENTIAL_INTEREST_AREAS
  , -PREF_NAME_SORT, -MG_ID_MODEL_YEAR, -MG_ID_MODEL_SCORE, -MG_PR_MODEL_YEAR, -MG_PR_MODEL_SCORE
)