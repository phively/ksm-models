# Generic function to generate scatterplots of interest
scatterplotter <- function(data, x, y, color, trans) {
  data %>%
    ggplot(aes_string(x = x, y = y, color = color)) +
    geom_point(alpha = .5) +
    geom_smooth(color = 'black') +
    geom_smooth(method = 'lm', color = 'red') +
    scale_y_continuous(trans = trans, breaks = c(0, 10^(0:12)), labels = scales::dollar)
}

# Log10 transformation after adding 1
log10plus1_trans <- function(x) {
  scales::trans_new(
    'log10plus1'
    , transform = function(x) log10(x + 1)
    , inverse = function(x) {10^x - 1}
  )
}