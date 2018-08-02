# Generic function to generate scatterplots of interest
scatterplotter <- function(data, x, y, color = NULL, ytrans = 'identity', ylabels = waiver()) {
  data %>%
    ggplot(aes_string(x = x, y = y, color = color)) +
    geom_point(alpha = .5) +
    geom_smooth(color = 'black') +
    geom_smooth(method = 'lm', color = 'red') +
    scale_y_continuous(trans = ytrans, breaks = c(0, 10^(0:12)), labels = ylabels)
}

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