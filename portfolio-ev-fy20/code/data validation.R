##### Tests and failed counter
tests <- 0
passed <- 0

##### Function to print results
print_results <- function(test_result, output) {
  if(test_result) {
    cat(output, '\n')
  } else {
    message(output)
  }
}

##### Check whether household IDs are unique
cat('===== Checking for unique records... =====', '\n')
test_result <- nrow(catracks$households) == catracks$households %>% select(HOUSEHOLD_ID) %>% unique() %>% nrow()
output <- paste('All households unique :', test_result)
print_results(test_result, output)
tests <- tests + 1
passed <- passed + test_result

##### Check whether every record has a time_index
cat('===== Checking for valid start dates... =====', '\n')

# Helper function
chk_time_index <- function(data, name) {
  time_index <- attr(data, 'time_index')
  ti <- ensym(time_index)
  test_result <- data %>% filter(is.na(!!ti)) %>% nrow() == 0
  output <- paste(name, time_index, ':', test_result)
  print_results(test_result, output)
  assign('tests', tests + 1, envir = .GlobalEnv)
  assign('passed', passed + test_result, envir = .GlobalEnv)
}

mapply(FUN = chk_time_index, catracks, names(catracks))

##### Results
failed <- tests - passed
cat('\n', passed, 'of', tests, 'tests passed', '\n')
if(failed == 0) {cat(' All tests successful!')}
if(failed > 0) {message(' WARNING, ', failed, ' tests failed')}