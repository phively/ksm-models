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