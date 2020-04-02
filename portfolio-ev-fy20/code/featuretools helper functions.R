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