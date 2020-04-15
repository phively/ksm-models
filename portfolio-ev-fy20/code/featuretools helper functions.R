# Print feature names from a large dfs features list
print_features <- function(fs) {
  foreach(
    i = 1:length(fs[[2]]) # Iterate through each feature
    , .combine = c # Use c() to combine the results below
  ) %do% {
    # Convert each list element to a string
    fs[[2]][[i]] %>% as.character()
  } %>%
    # Print features as data frame rows
    data.frame(feature = ., stringsAsFactors = FALSE)
}

# Filter anything after a certain date from the passed dataset
filter_by_date <- function(data, cutoff_dt) {
  time_index <- attr(data, 'time_index')
  ti <- ensym(time_index)
  return(
    data %>% filter(!!ti <= cutoff_dt)
  )
}

# Make an entity set from a list of dataframes

entityset_create_entities <- function(df, df_name, debug = FALSE) {
  if (debug) {print(paste('Adding', df_name))}
  r_entityset %>%
    add_entity(
      df
      , entity_id = df_name
      , make_index = TRUE
      , index = paste0(df_name, '_idx')
      , time_index = attr(df, 'time_index')
    )
}

entityset_create_relationships <- function(df_name, debug = FALSE) {
  if (debug) {print(df_name)}
  r_entityset %>%
    add_relationship(
      parent_set = 'households'
      , child_set = df_name
      , parent_idx = 'HOUSEHOLD_ID'
      , child_idx = 'HOUSEHOLD_ID'
    )
}

entityset_create <- function(entityset, datalist, cutoff_dt = NULL) {
  if (is.null(cutoff_dt)) {cutoff_dt <- lubridate::ymd('99991231')}
  datalist <- datalist %>% filter_by_date (cutoff_dt)
  entityset <- mapply(
    entityset_create_entities
    , df = datalist
    , df_name = names(datalist)
  )[[1]]
  entityset <- sapply(
    datalist %>% names()
    , FUN = make_relationships
  )[[1]]
  return(entityset)
}