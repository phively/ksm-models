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

filter_by_date_all <- function(datalist, cutoff_dt) {
  lapply(datalist, FUN = filter_by_date, cutoff_dt = cutoff_dt)
}

# Make an entity set from a list of dataframes

entityset_create_entities <- function(entityset_name, df, df_name, master_entity = 'households', master_idx = 'HOUSEHOLD_ID', debug = FALSE) {
  if (debug) {print(paste('Adding', df_name, 'to', entityset_name))}
  entityset <- get(entityset_name, envir = .GlobalEnv)
  # Do not create an index for the master entity
  if (df_name == master_entity) {
    entityset %>%
      add_entity(
        df
        , entity_id = master_entity
        , index = master_idx
        , time_index = attr(df, 'time_index')
      )
  } else {
    entityset %>%
      add_entity(
        df
        , entity_id = df_name
        , make_index = TRUE
        , index = paste0(df_name, '_idx')
        , time_index = attr(df, 'time_index')
      )
  }
  assign(entityset_name, entityset, envir = .GlobalEnv)
}

entityset_create_relationships <- function(entityset_name, df_name, master_entity = 'households', master_idx = 'HOUSEHOLD_ID', debug = FALSE) {
  if (debug) {paste(df_name, '->', master_entity, 'on', master_idx) %>% print()}
  entityset <- get(entityset_name, envir = .GlobalEnv)
  # Check for self-join
  if (df_name == master_entity) {
    paste('Cannot self-join', master_entity, 'on', master_idx) %>% message()
  } else {
    entityset %>%
      add_relationship(
        parent_set = master_entity
        , child_set = df_name
        , parent_idx = master_idx
        , child_idx = master_idx
      )
  }
  assign(entityset_name, entityset, envir = .GlobalEnv)
}

entityset_create <- function(entityset_name, datalist, master_entity = 'households', master_idx = 'HOUSEHOLD_ID', cutoff_dt = NULL, debug = FALSE) {
  # Create new entityset
  entityset <- create_entityset(id = entityset_name)
  assign(entityset_name, entityset, envir = .GlobalEnv)
  if (debug) {paste('New entity set:', entityset_name) %>% print()}
  # Data cleanup
  if (is.null(cutoff_dt)) {cutoff_dt <- lubridate::ymd('99991231')}
  if (debug) {paste('cutoff date', cutoff_dt) %>% print()}
  datalist <- datalist %>% filter_by_date_all(cutoff_dt)
  if (debug) {paste('datalist size', length(datalist)) %>% print()}
  # Create entities
  mapply(
    entityset_create_entities
    , entityset = entityset_name
    , df = datalist
    , df_name = names(datalist)
    , master_entity = master_entity
    , master_idx = master_idx
    , debug = debug
  )[[1]]
  # Create relationships
  entityset <- sapply(
    datalist %>% names()
    , FUN = entityset_create_relationships
    , entityset_name = entityset_name
    , master_entity = master_entity
    , master_idx = master_idx
    , debug = debug
  )[[1]]
}