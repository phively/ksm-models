pool <- readxl::read_xlsx(
  path = 'data/2018-07-19 PG scores for all active prospects.xlsx'
  , sheet = 'With'
) %>% mutate(
  # Create factors
  QUAL_LEVEL = factor(QUAL_LEVEL)
  , PREF_ADDR = factor(PREF_ADDR)
  , PROSPECT_MGR = factor(PROSPECT_MGR)
  , MULTI_OR_SINGLE_INTEREST = factor(MULTI_OR_SINGLE_INTEREST)
  , MG_ID_MODEL_DESC = MG_ID_MODEL_DESC %>% str_remove('Major Gifts Identification ') %>% factor()
  , MG_PR_MODEL_DESC = MG_PR_MODEL_DESC %>% str_remove('Major Gifts Prioritization ') %>% factor()
  # Create booleans
  , PG_PROSPECT_FLAG = !is.na(PG_PROSPECT_FLAG)
  # Create numeric
  , MG_ID_MODEL_SCORE = as.numeric(MG_ID_MODEL_SCORE)
  , MG_ID_MODEL_YEAR = as.numeric(MG_ID_MODEL_YEAR)
  , MG_PR_MODEL_SCORE = as.numeric(MG_PR_MODEL_SCORE)
  , MG_PR_MODEL_YEAR = as.numeric(MG_PR_MODEL_YEAR)
)