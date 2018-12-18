# Log10 transformation after adding 1
log10plus1 <- function(x, inverse = FALSE) {
  if (inverse) {return(10^x - 1)}
  else return(log10(x + 1))
}
# scales::trans_new version
log10plus1_trans <- function(x) {
  scales::trans_new(
    'log10plus1'
    , transform = function(x) log10plus1(x, inverse = FALSE)
    , inverse = function(x) log10plus1(x, inverse = TRUE)
  )
}

# Negative square root function
neg_sqrt_trans <- function() scales::trans_new(
  'neg_sqrt'
  , function(x) {sign(x) * sqrt(abs(x))}
  , function(x) {sign(x) * x^2}
)

# glm confusion matrix
conf_matrix <- function(model, newdata = NULL, threshold = .5) {
  results <- data.frame(
    pred = predict(model, newdata = newdata, type = 'response') >= threshold
  )
  if (is.null(newdata)) {
    results$truth = model$y
  } else {
    results$truth = newdata[, 1] %>% unlist()
  }
  results_tbl <- table(truth = results$truth, prediction = results$pred)
  error <- (results_tbl[1, 2] + results_tbl[2, 1]) / sum(results_tbl)
  precision <- results_tbl[2, 2] / sum(results_tbl[, 2])
  sensitivity <- results_tbl[2, 2] / sum(results_tbl[2, ])
  return(
    list(
      # Confusion matrix counts
        conf_matrix = results_tbl
      # Confusion matrix percents
      , conf_matrix_pct = results_tbl / nrow(results)
      # Statistics
      , error = error
      , precision = precision
      , sensitivity = sensitivity
      , F1_score = (precision * sensitivity) / (precision + sensitivity)
    )
  )
}

# glmnet confusion matrix
conf_matrix_glmnet <- function(model, newdata = NULL, rv = NULL, threshold = .5) {
  results <- data.frame(
    predict(model, newdata = newdata, type = 'response'
            , s = 'lambda.1se') >= threshold
  ) %>% select(pred = X1)
  if (is.null(newdata)) {
    results$truth = model$y
  } else {
    results$truth = paste0('newdata$', rv) %>% parse(text = .) %>% eval()
  }
  results_tbl <- table(truth = results$truth, prediction = results$pred)
  error <- (results_tbl[1, 2] + results_tbl[2, 1]) / sum(results_tbl)
  precision <- results_tbl[2, 2] / sum(results_tbl[, 2])
  sensitivity <- results_tbl[2, 2] / sum(results_tbl[2, ])
  return(
    list(
      # Confusion matrix counts
        conf_matrix = results_tbl
      # Confusion matrix percents
      , conf_matrix_pct = results_tbl / nrow(results)
      # Statistics
      , error = error
      , precision = precision
      , sensitivity = sensitivity
      , F1_score = (precision * sensitivity) / (precision + sensitivity)
    )
  )
}

# ROC matrix generation
roc_matrix_gen <- function(model, data) {
  data.frame(
    X1 = predict(model, newdata = data, type = 'response')
    , y = (data[, 1] + 0) %>% unlist()
  ) %>% arrange(desc(X1)) %>%
    mutate(
      TPR = cumsum(y) / sum(y)
      , FPR = cumsum(y == 0) / sum(y == 0)
    ) %>%
    return()
}