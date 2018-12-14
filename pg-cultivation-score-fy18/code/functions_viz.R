# Generic function to generate scatterplots of interest
scatterplotter <- function(data, x, y, color = NULL, ytrans = 'identity', ylabels = waiver()) {
  data %>%
    ggplot(aes_string(x = x, y = y, color = color)) +
    geom_point(alpha = .5) +
    geom_smooth(color = 'black') +
    geom_smooth(method = 'lm', color = 'red') +
    scale_y_continuous(trans = ytrans, breaks = c(0, 10^(0:12)), labels = ylabels)
}

# Generic function to plot cross-validated error metrics
histogrammer <- function(errordata, varname, h = .005, fill = 'gray') {
  data.frame(x = errordata[, varname]) %>%
  ggplot(aes(x = x)) +
    geom_histogram(aes(y = ..density..), alpha = .5, binwidth = h, fill = fill) +
    geom_density(alpha = .5) +
    geom_vline(aes(xintercept = mean(x), color = 'mean')) +
    geom_vline(aes(xintercept = median(x), color = 'median'), linetype = 'dashed') +
    labs(x = varname)
}

# Generic function to extract partial residuals for any model using residuals(..., type = 'partial')
extract_partials <- function(model, var.resp, var.expl) {
  resids <- data.frame(
    expl = model$model %>% data.frame() %>% select(var.expl) %>% unlist()
    , residuals(model, type = 'partial')
    , class = paste0('model$model$', var.resp, ' + 0') %>% parse(text = .) %>% eval() %>% as.factor()
  ) %>%
    select(
      expl
      , resids = var.expl
      , class
    ) %>% setNames(
      c(var.expl, 'resids', var.resp)
    )
}

# Generic function to plot calibration results
plot_calibration <- function(model, newdata, smooth.method = 'loess', title.label = NULL) {
  data.frame(
    class = (newdata[, 1] + 0) %>% unlist()
    , prediction = predict(model, newdata = newdata, type = 'response')
  ) %>%
    setNames(c('class', 'prediction')) %>%
  ggplot(aes(x = prediction, y = class)) +
    geom_point(aes(color = as.factor(class))) +
    geom_smooth(method = smooth.method) +
    geom_abline(slope = 1, intercept = 0) +
    labs(title = paste0(title.label, ' OOS smoother (', smooth.method, '), penalized coefficients'), color = 'class'
         , x = 'predicted probability'
         , y = 'observed probability')
}

# Create coefficients data frame
create_coefs <- function(model_list) {
  foreach(i = 1:length(model_list), .combine = 'rbind') %do% {
    tmp <- summary(model_list[[i]])$coefficients
    data.frame(tmp) %>%
    mutate(
      variable = rownames(tmp)
      , model = i
    ) %>% select(
      model
      , variable
      , beta.hat = Estimate
      , SE = Std..Error
      , t.val = t.value
      , Pr.t = Pr...t..
    ) %>% return()
  } %>% return()
}
# Plot R-squared
plot_r2 <- function(model_list, type = 'r.squared') {
  parser <- function(x) {
    tmpsum <- summary(x)
    paste0('tmpsum$', type) %>% parse(text = .) %>% eval() %>% return()
  }
  model_list %>%
  lapply(., function(x) parser(x)) %>% unlist() %>% data.frame(r.squared = .) %>%
    ggplot(aes(x = r.squared)) + 
    geom_density() +
    geom_vline(aes(xintercept = mean(r.squared)), color = 'blue', linetype = 'dashed', alpha = .5) +
    geom_rug(color = 'blue') +
    labs(title = bquote('Density plot of' ~ r^2 ~ 'results, mean' ~
        .(lapply(model_list, function(x) {summary(x)$r.squared}) %>% unlist() %>% mean() %>% round(3))
      )
      , x = bquote(r^2)
    )
}
# Plot cross-validated coefficients
plot_coefs <- function(model_list, conf_interval = 1 - p.sig) {
  crit_val <- qnorm({1 - conf_interval} / 2) %>% abs()
  coefs <- create_coefs(model_list)
  coefs %>% full_join(
    coefs %>% group_by(variable) %>%
      summarise(group.mean = mean(beta.hat), group.sd = sd(beta.hat))
    , by = c('variable', 'variable')
  ) %>%
  ggplot(aes(x = variable, y = beta.hat, color = factor(model))) +
  geom_segment(
    aes(
      xend = variable
      , y = group.mean - 2 * crit_val * group.sd
      , yend = group.mean + 2 * crit_val * group.sd
    ), color = 'gray', alpha = .25, size = 2) +
  geom_point() +
  geom_hline(yintercept = 0, alpha = .5) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = .5), axis.title.y = element_text(angle = 0, vjust = .5)) +
  labs(
    title = 'Coefficient estimates per cross-validation model'
    , y = bquote(hat(beta))
    , color = 'cross-validation sample'
  )
}
# Table of coefficient +/- counts
coef_pm_table <- function(model_list, pval) {
  create_coefs(model_list) %>%
  group_by(variable) %>%
  summarise(
    `+` = sum(sign(beta.hat) == 1 & Pr.t < pval)
    , `0` = sum(Pr.t >= pval)
    , `-` = sum(sign(beta.hat) < 0 & Pr.t < pval)
  )
}
# Compute predictions
calc_preds <- function(model_list, xval, yname) {
  yhats <- list()
  for (i in 1:length(model_list)) {
    yhats[[i]] <- data.frame(
      model = i
      , row = xval[[i]]
      , preds = model_list[[i]] %>% predict(newdata = mdat[xval[[i]], ])
      , truth = mdat[xval[[i]], yname] %>% unlist() %>% log10plus1()
    )
  }
  return(yhats)
}
calc_outsample_mse <- function(model_list, xval, yname) {
  calc_preds(model_list, xval, yname) %>%
    lapply(function(x) calc_mse(y = x$truth, yhat = x$preds)) %>%
    unlist()
}
# Plot MSEs by insample/outsample
plot_mses <- function(model_list, xval, truth) {
  mses <- data.frame(
    insample = model_list %>%
      lapply(function(x) calc_mse(y = model.frame(x)[, 1], yhat = predict(x))) %>%
      unlist()
    , outsample = calc_outsample_mse(model_list, xval, truth)
  ) %>% gather('type', 'MSE', 1:2)
  mses %>%
    ggplot(aes(x = MSE, color = type)) +
    geom_density() +
    geom_vline(
      xintercept = mses %>% filter(type == 'insample') %>% select(MSE) %>% unlist %>% mean()
      , color = 'red', linetype = 'dashed', alpha = .5
    ) +
    geom_vline(
      xintercept = mses %>% filter(type == 'outsample') %>% select(MSE) %>% unlist %>% mean()
      , color = 'darkcyan', linetype = 'dashed', alpha = .5
    ) +
    geom_rug() +
    labs(
      title = bquote('MSE across samples, means =' ~
          .(mses %>% group_by(type) %>% summarise(mean = mean(MSE)) %>%
              select(mean) %>% unlist() %>% round(3) %>% paste(collapse = ', ')
          )
        )
    )
}
# Merges predicted results into one large data frame each for insample and outsample
calc_resids <- function(model_list, xval, yname) {
  insample <- foreach(i = 1:length(model_list), .combine = 'rbind') %do% {
    data.frame(
      model = i
      , preds = model_list[[i]] %>% predict()
      , truth = model.frame(model_list[[i]])[, 1]
    ) %>% mutate(
      residuals = truth - preds
    )
  }
  preds <- calc_preds(model_list, xval, yname)
  outsample <- foreach(i = 1:length(model_list), .combine = 'rbind') %do% {
    preds[[i]]
  } %>% mutate(
    residuals = truth - preds
  )
  return(list(insample = insample, outsample = outsample))
}
# Plot standardized residuals; returns a list of ggplot objects $insample and $outsample
plot_resids <- function(model_list, xval, yname, filter = 'TRUE') {
  resids <- calc_resids(model_list, xval, yname)
  # Plot residuals vs fitted for in-sample data
  insample <- resids$insample %>% filter_(filter) %>%
    ggplot(aes(x = preds, y = residuals, color = factor(model))) +
    geom_point(alpha = .01) +
    geom_smooth(se = FALSE) +
    labs(title = 'In-sample residuals versus fitted', color = 'cross-validation sample')
  # Plot residuals vs fitted for out-of-sample data
  outsample <- resids$outsample %>% filter_(filter) %>%
    ggplot(aes(x = preds, y = residuals, color = factor(model))) +
    geom_point(alpha = .1) +
    geom_smooth(se = FALSE) +
    labs(title = 'Out-of-sample residuals versus fitted', color = 'cross-validation sample')
  return(list(insample = insample, outsample = outsample))
}
# Plot normal Q-Q visualization for residuals
plot_qq <- function(model_list, xval, yname, filter = 'TRUE') {
  resids <- calc_resids(model_list, xval, yname)
  # In-sample Q-Q plot with standardized residuals
  insample <- resids$insample %>% mutate(st.resid = residuals/sd(residuals)) %>% filter_(filter) %>%
    ggplot(aes(sample = st.resid, color = factor(model))) +
    geom_qq(alpha = .05) +
    geom_qq_line() +
    labs(title = 'In-sample Q-Q plot with standardized residuals'
         , color = 'cross-validation sample')
  # Out-of-sample Q-Q plot
  outsample <- resids$outsample %>% mutate(st.resid = residuals/sd(residuals)) %>% filter_(filter) %>%
    ggplot(aes(sample = st.resid, color = factor(model))) +
    geom_qq(alpha = .05) +
    geom_qq_line() +
    labs(title = 'Out-of-sample Q-Q plot with standardized residuals'
         , color = 'cross-validation sample')
  return(list(insample = insample, outsample = outsample))
}
# Compute partial residuals
calc_partial_resids <- function(model, inds, xname, df = NULL) {
  # Quick hack to get around update() environment, not really recommended
  scoped_xname <<- xname
  scoped_spline_df <<- df
  # Partial residuals data frame
  data.frame(
    x = mdat %>% filter(rownum %in% unlist(inds)) %>% select_(xname) %>% unlist()
    , y = model.frame(model)[, 1]
    , y.hat = if (!is.null(df)) {
      update(model, formula = . ~ ns(parse(text = scoped_xname) %>% eval(), df = scoped_spline_df)) %>% fitted()
    } else {
      update(model, formula = . ~ parse(text = scoped_xname) %>% eval()) %>% fitted()
    }
  ) %>% mutate(
    # Compute partial residuals
    y.partial.resid = if (!is.null(df)) {
      {model %>% residuals(type = 'partial')}[, paste0('ns(', parse(text = xname), ', df = ', df, ')')]
    } else {
      {model %>% residuals(type = 'partial')}[, xname]
    }
    # Regression on partial residuals
    , y.hat.partial = if (!is.null(df)) {
      lm(y.partial.resid ~ ns(x, df)) %>% fitted()
    } else {
      lm(y.partial.resid ~ x) %>% fitted()
    }
  ) %>% return()
}
# Boruta: create data frame from results
Borutadata <- function(boruta.results, excludes = NULL) {
  data.frame(Importance = boruta.results$ImpHistory) %>%
    gather('Variable', 'Importance') %>%
    # Remove Importance. from the front of every variable name
    mutate(Variable = gsub('Importance.', '', Variable)) %>%
    # Append decision to the data frame
    left_join(
      data.frame(
        Decision = boruta.results$finalDecision %>% relevel('Confirmed')
        , Variable = names(boruta.results$finalDecision)
      ) %>% mutate(Variable = as.character(Variable))
      , by = 'Variable'
    ) %>%
    # Label shadow variables Reference
    mutate(Decision = factor(Decision, levels = c(levels(Decision), 'Reference'))) %>%
    ReplaceValues(old.val = NA, new.val = 'Reference') %>%
    # Drop uninformative variables and -Inf rows
    filter(Variable %nin% excludes & Importance != -Inf) %>%
    # Return results
    return()
}
# Boruta: create plots from data frame
Borutaplotter <- function(boruta.results, title = 'Variable importances under Boruta algorithm', ytextsize = 6) {
  # Plot results
  ggplot(boruta.results, aes(x = reorder(Variable, Importance, FUN = median), y = Importance, fill = Decision)) +
    geom_boxplot(alpha = .3) +
    theme(panel.grid.minor = element_line(linetype = 'dotted')) +
    scale_fill_manual(values = c('green', 'yellow', 'red', 'black')) +
    labs(title = title, x = 'Variable', y = 'Importance') +
    theme(axis.text.y = element_text(size = ytextsize)) +
    coord_flip() %>%
    suppressMessages() %>%
    # Return results
    return()
}
# Plot correlations between a matrix of numeric variables
plot_corrs <- function(numeric.data, textsize = 3) {
  cors <- cor(numeric.data) %>% round(2)
  # Do not fill in diagonal
  diag(cors) <- NA
  # Plot results
  cors %>%
    melt(., na.rm = TRUE) %>%
    ggplot(aes(x = Var2, y = Var1, fill = value, label = value)) +
    geom_tile() +
    geom_text(size = textsize) +
    coord_fixed() +
    scale_fill_gradient2(low = 'blue', mid = 'white', high = 'red', limits = c (-1, 1)) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = .3)) %>%
  # Return results
  return()
}
