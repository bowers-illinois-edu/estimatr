context("S3")
n <- 10
dat <- data.frame(
  x = rep(0:1, times = 5),
  p = 0.5,
  z = rnorm(n),
  y = rnorm(n)
)

lmbo <- lm_robust(y ~ z + as.factor(x), data = dat)
lmfo <- lm_robust(y ~ z, data = dat, fixed_effects = ~ x)

test_that("tidy, summary, and print work", {

  expect_is(
    tidy(NULL),
    "data.frame"
  )

  # Might need to force this test of tidy.default

  d <- date()
  expect_warning(
    estimatr:::tidy.default(d),
    "using as.data.frame"
  )

  ## lm_robust
  lmo <- lm_robust(y ~ x, data = dat, se_type = "classical")

  capture_output(
    summary(lmo)
  )

  capture_output(
    summary(lmfo)
  )

  expect_output(
    print(summary(lmfo)),
    "proj\\. model"
  )

  expect_is(
    tidy(lmo),
    "data.frame"
  )

  expect_is(
    tidy(lmfo),
    "data.frame"
  )


  expect_equal(
    nrow(tidy(lm_robust(y ~ x, data = dat, se_type = "classical"))),
    2
  )

  expect_equal(
    nrow(tidy(lmfo)),
    1
  )

  capture_output(
    expect_equivalent(
      coef(summary(lmo)),
      print(lmo)
    )
  )

  capture_output(
    expect_equivalent(
      coef(summary(lmfo)),
      print(lmfo)
    )
  )

  # works with multiple outcomes
  lmrmo <- lm_robust(cbind(y, x) ~ z, data = dat, se_type = "classical")
  lmmo <- lm(cbind(y, x) ~ z, data = dat)
  slmmo <- summary(lmmo)

  expect_equivalent(
    as.matrix(tidy(lmrmo)[, c("term", "outcome")]),
    cbind(
      rep(c("(Intercept)", "z"), times = 2),
      rep(c("y", "x"), each = 2)
    )
  )

  expect_equal(
    dimnames(vcov(lmrmo)),
    list(
      c("y:(Intercept)", "y:z", "x:(Intercept)", "x:z"),
      c("y:(Intercept)", "y:z", "x:(Intercept)", "x:z")
    )
  )

  expect_equal(
    coef(lmrmo),
    coef(lmmo)
  )

  capture_output(
    expect_equal(
      rownames(print(lmrmo)),
      rownames(vcov(lmrmo))
    )
  )

  expect_equal(
    predict(lmrmo, newdata = dat),
    predict(lmmo)
  )

  expect_error(
    predict(lmrmo, newdata = dat, se.fit = TRUE),
    "Can't set `se.fit` == TRUE with multivariate outcome"
  )

  expect_error(
    slmrmo <- summary(lmrmo),
    NA
  )

  lmroy <- lm_robust(y ~ z, data = dat, se_type = "classical")
  lmrox <- lm_robust(x ~ z, data = dat, se_type = "classical")

  # Only difference is name on fstatistic!
  expect_equivalent(
    slmrmo$`Response y`,
    summary(lmroy)
  )
  expect_equivalent(
    slmrmo$`Response x`,
    summary(lmrox)
  )

  expect_equal(
    lapply(slmrmo, function(x) coef(x)[, c(1, 2, 3)]),
    lapply(slmmo, function(x) coef(x)[, c(1, 2, 4)])
  )

  expect_equivalent(
    confint(lmrmo)[1:2,],
    confint(lmroy)
  )

  expect_equivalent(
    confint(lmrmo)[3:4,],
    confint(lmrox)
  )

  ## lm_lin
  lmlo <- lm_lin(y ~ x, ~ z, data = dat)
  expect_is(
    tidy(lmlo),
    "data.frame"
  )


  capture_output(
    expect_equivalent(
      coef(summary(lmlo)),
      print(lmlo)
    )
  )

  ## horvitz_thompson
  ht <- horvitz_thompson(y ~ x, condition_prs = p, data = dat)
  expect_is(
    tidy(ht),
    "data.frame"
  )

  expect_equivalent(
    as.matrix(tidy(ht)[, c("estimate", "std.error", "p.value", "ci.lower", "ci.upper", "df")]),
    coef(summary(ht))
  )


  capture_output(
    expect_equivalent(
      coef(summary(ht)),
      print(ht)
    )
  )

  ## difference_in_means
  dim <- difference_in_means(y ~ x, data = dat)
  expect_is(
    tidy(dim),
    "data.frame"
  )

  summary(dim)$coefficients

  capture_output(
    expect_equivalent(
      coef(summary(dim)),
      print(dim)
    )
  )

  # rank deficient
  dat$z2 <- dat$z
  lmro <- lm_robust(y ~ z + z2 + x, data = dat)
  tidy(lmro)

  # instrumental variables S3 methods are in the IV test, owing to
  # the AER dependency
  # iv_robust
})


test_that("vcov works", {

  # not identical due to < 1e-15 diffs
  expect_equal(
    vcov(lm_robust(y ~ x, data = dat, se_type = "classical")),
    vcov(lm(y ~ x, data = dat))
  )

  expect_equal(
    vcov(lmbo)["z", "z"],
    vcov(lmfo)["z", "z"]
  )

  expect_error(
    vcov(lm_lin(y ~ x, ~ z, data = dat)),
    NA
  )

  expect_error(
    vcov(lm_robust(y ~ x, data = dat, return_vcov = FALSE)),
    "return_vcov = TRUE"
  )

  expect_error(
    vcov(horvitz_thompson(y ~ x, condition_prs = p, data = dat)),
    "supported|horvitz_thompson"
  )


  expect_error(
    vcov(difference_in_means(y ~ x, data = dat)),
    "supported|difference_in_means"
  )

  # rank deficient
  dat$z2 <- dat$z
  lmro <- lm_robust(y ~ z + z2 + x, data = dat)
  expect_equivalent(
    dim(vcov(lmro)),
    c(3, 3)
  )

  # Instrumental variables
  library(AER)
  ivo <- ivreg(y ~ x | z, data = dat)

})


test_that("coef and confint work", {

  lmo <- lm_robust(y ~ x, data = dat)
  expect_equivalent(
    coef(lmo),
    lmo$coefficients
  )

  expect_equivalent(
    coef(lmfo),
    lmfo$coefficients
  )

  expect_equivalent(
    coef(lmbo)["z"],
    coef(lmfo)["z"]
  )

  expect_equivalent(
    confint(lmo),
    cbind(lmo$ci.lower, lmo$ci.upper)
  )

  expect_equivalent(
    confint(lmfo),
    cbind(lmfo$ci.lower, lmfo$ci.upper)
  )

  expect_equal(
    confint(lmbo, parm = "z"),
    confint(lmfo, parm = "z")
  )

  expect_equal(
    confint(lmbo, parm = "z", level = 0.8),
    confint(lmfo, parm = "z", level = 0.8)
  )

  lm2o <- lm_robust(y ~ x + z, data = dat)
  expect_equivalent(
    coef(lm2o)[2],
    lm2o$coefficients["x"]
  )

  expect_equivalent(
    confint(lm2o)[2, , drop = FALSE],
    confint(lm2o, parm = "x")
  )

  expect_equivalent(
    confint(lmo, parm = "x", level = 0.90),
    with(
      lm_robust(y ~ x, data = dat, alpha = 0.10),
      cbind(ci.lower[2], ci.upper[2])
    )
  )

  lmlo <- lm_lin(y ~ x, ~ z, data = dat, se_type = "HC3")
  expect_equivalent(
    confint(lmlo),
    cbind(lmlo$ci.lower, lmlo$ci.upper)
  )

  dim <- difference_in_means(y ~ x, data = dat)
  expect_equivalent(
    coef(dim),
    dim$coefficients
  )
  expect_equivalent(
    confint(dim),
    cbind(dim$ci.lower, dim$ci.upper)
  )

  ht <- horvitz_thompson(y ~ x, condition_prs = p, data = dat)
  expect_equivalent(
    coef(ht),
    ht$coefficients
  )
  expect_equivalent(
    confint(ht),
    cbind(ht$ci.lower, ht$ci.upper)
  )

  # rank deficient
  dat$z2 <- dat$z
  lmro <- lm_robust(y ~ z + z2 + x, data = dat)
  confint(lmro)
  coef(lmro)
  capture.output(
    expect_equal(
      nobs(lmro),
      nobs(summary(lmro))
    )
  )
})

test_that("predict works", {
  set.seed(42)
  n <- 10
  dat <- data.frame(
    x = rep(0:1, times = 5),
    w = runif(n),
    z = rnorm(n),
    cl = as.factor(sample(letters[1:3], size = n, replace = T)),
    y = rnorm(n)
  )

  lm_out <- lm(y ~ z * x + cl, data = dat)
  lmr_out <- lm_robust(y ~ z * x + cl, data = dat, se_type = "classical")

  expect_equivalent(
    predict(lm_out, dat),
    predict(lmr_out, dat)
  )

  # various specifications
  expect_equivalent(
    predict(lm_out, dat, se.fit = T, interval = "confidence")[c(1, 2)],
    predict(lmr_out, dat, se.fit = T, interval = "confidence")[c(1, 2)]
  )

  expect_equivalent(
    predict(lm_out, dat, se.fit = T, interval = "prediction")[c(1, 2)],
    predict(lmr_out, dat, se.fit = T, interval = "prediction")[c(1, 2)]
  )

  # missingness
  n <- 11
  new_dat <- data.frame(
    x = rep(0:1, times = c(5, 6)),
    w = runif(n),
    z = rnorm(n),
    cl = as.factor(sample(letters[1:3], size = n, replace = T)),
    y = rnorm(n)
  )
  # remove one level to make sure works with missing levels
  new_dat <- new_dat[new_dat$cl == "a", ]
  new_dat[1, "x"] <- NA

  expect_equivalent(
    predict(lm_out, new_dat),
    predict(lmr_out, new_dat)
  )

  # various specifications
  expect_equivalent(
    predict(lm_out, new_dat, se.fit = T, interval = "confidence")[c(1, 2)],
    predict(lmr_out, new_dat, se.fit = T, interval = "confidence")[c(1, 2)]
  )

  expect_equivalent(
    predict(lm_out, new_dat, se.fit = T, interval = "prediction")[c(1, 2)],
    predict(lmr_out, new_dat, se.fit = T, interval = "prediction")[c(1, 2)]
  )

  # weights
  lm_out <- lm(y ~ z * x + cl, data = dat, weights = w)
  lmr_out <- lm_robust(y ~ z * x + cl, data = dat, se_type = "classical", weights = w)

  expect_equivalent(
    predict(lm_out, dat),
    predict(lmr_out, dat)
  )

  expect_equivalent(
    predict(lm_out, dat, se.fit = T, interval = "confidence")[c(1, 2)],
    predict(lmr_out, dat, se.fit = T, interval = "confidence")[c(1, 2)]
  )

  expect_warning(
    plmo <- predict(lm_out, dat, se.fit = T, interval = "prediction")[c(1, 2)],
    "Assuming constant prediction variance"
  )
  expect_warning(
    plmro <- predict(lmr_out, dat, se.fit = T, interval = "prediction")[c(1, 2)],
    "Assuming constant prediction variance"
  )
  expect_equivalent(
    plmo,
    plmro
  )

  # Now with missingness and newdat

  expect_equivalent(
    predict(lm_out, new_dat),
    predict(lmr_out, new_dat)
  )


  # mimic lm behavior with missing weights (can't get prediction intervals)
  new_dat$w[3] <- NA
  # various specifications
  expect_equivalent(
    predict(lm_out, new_dat, se.fit = T, interval = "confidence", weights = ~ w)[c(1, 2)],
    predict(lmr_out, new_dat, se.fit = T, interval = "confidence", weights = w)[c(1, 2)]
  )

  expect_equivalent(
    predict(lm_out, new_dat, se.fit = T, interval = "prediction", weights = ~w)[c(1, 2)],
    predict(lmr_out, new_dat, se.fit = T, interval = "prediction", weights = w)[c(1, 2)]
  )

  # other arguments
  expect_equivalent(
    predict(lm_out, new_dat, se.fit = T, interval = "prediction", pred.var = 2.3)[c(1, 2)],
    predict(lmr_out, new_dat, se.fit = T, interval = "prediction", pred.var = 2.3)[c(1, 2)]
  )

  # lm_lin
  n <- 11
  new_dat <- data.frame(
    x = rep(0:1, times = c(5, 6)),
    z = rnorm(n),
    cl = as.factor(sample(letters[1:3], size = n, replace = TRUE)),
    y = rnorm(n)
  )

  lml_out <- lm_lin(y ~ x, covariates = ~ z + cl, data = dat, se_type = "classical")

  dat$z_bar <- dat$z - mean(dat$z)
  dat$clb <- as.numeric(dat$cl == "b")
  dat$clc <- as.numeric(dat$cl == "c")
  dat$clb_bar <- dat$clb - mean(dat$clb)
  dat$clc_bar <- dat$clc - mean(dat$clc)

  lm_int_out <- lm(y ~ x + x * z_bar + x * clb_bar + x * clc_bar, data = dat)

  # have to scale new data by old mean values!
  # now predict does this for you! ok.emoji

  new_dat$z_bar <- new_dat$z - mean(dat$z)
  new_dat$clb <- as.numeric(new_dat$cl == "b")
  new_dat$clc <- as.numeric(new_dat$cl == "c")
  new_dat$clb_bar <- new_dat$clb - mean(dat$clb)
  new_dat$clc_bar <- new_dat$clc - mean(dat$clc)

  # not identical due to some numerical difference, presumably due to the way I save the means from lm_lin
  expect_equivalent(
    predict(lml_out, new_dat, se.fit = TRUE, interval = "confidence")[c(1, 2)],
    predict(lm_int_out, new_dat, se.fit = TRUE, interval = "confidence")[c(1, 2)]
  )

  # working with rank deficient X
  head(dat)
  dat$z2 <- dat$z

  lm_out <- lm(y ~ z * x + z2 + cl, data = dat)
  lmr_out <- lm_robust(y ~ z * x + z2 + cl + z, data = dat, se_type = "classical")

  suppressWarnings({
    expect_equivalent(
      predict(lm_out, dat),
      predict(lmr_out, dat)
    )

    # various specifications
    expect_equivalent(
      predict(lm_out, dat, se.fit = T, interval = "confidence")[c(1, 2)],
      predict(lmr_out, dat, se.fit = T, interval = "confidence")[c(1, 2)]
    )

    expect_equivalent(
      predict(lm_out, dat, se.fit = T, interval = "prediction")[c(1, 2)],
      predict(lmr_out, dat, se.fit = T, interval = "prediction")[c(1, 2)]
    )
  })
})

test_that("predict works with fixed effects", {
  ro <- lm_robust(mpg ~ hp + vs + factor(cyl), data = mtcars)
  rfo <- lm_robust(mpg ~ hp + vs, fixed_effects = ~ cyl, data = mtcars)
  lo <- lm(mpg ~ hp + vs + factor(cyl), data = mtcars)

  plo <- predict(lo, newdata = mtcars)

  expect_equal(
    predict(ro, newdata = mtcars),
    predict(rfo, newdata = mtcars)
  )

  expect_error(
    predict(rfo, newdata = mtcars, se.fit = TRUE),
    "Can't set `se.fit`|TRUE with `fixed_effects`"
  )

  mtcars2 <- data.frame(
    mpg = 1:3,
    hp = rnorm(3),
    vs = rbinom(3, 1, 0.5),
    cyl = c(4, 2, 4)
  )

  expect_error(
    predict(ro, newdata = mtcars2),
    "factor factor\\(cyl\\) has new levels 2"
  )

  expect_error(
    predict(rfo, newdata = mtcars2),
    "Can't have new levels in `newdata` `fixed_effects` variable, such as: cyl2"
  )

  mtcars3 <- data.frame(
    mpg = 1:3,
    hp = rnorm(3),
    vs = rbinom(3, 1, 0.5),
    cyl = c(4, 6, 4)
  )

  expect_equal(
    predict(ro, newdata = mtcars3),
    predict(rfo, newdata = mtcars3)
  )

  ## Weights
  row <- lm_robust(mpg ~ 0 + hp + vs + factor(cyl), weights = wt, data = mtcars)
  rfow <- lm_robust(mpg ~ hp + vs, fixed_effects = ~ cyl, weights = wt, data = mtcars)
  low <- lm(mpg ~ hp + vs + factor(cyl), weights = wt, data = mtcars)

  plow <- predict(low, newdata = mtcars)
  prow <- predict(row, newdata = mtcars)
  prfow <- predict(rfow, newdata = mtcars)

  expect_error(
    predict(rfow, newdata = mtcars, se.fit = TRUE),
    "Can't set `se.fit`|TRUE with `fixed_effects`"
  )

  expect_equal(
    prow,
    prfow
  )

  expect_equal(
    prow,
    plow
  )

  expect_equivalent(
    row$fitted.values,
    low$fitted.values
  )

  expect_equal(
    row$fitted.values,
    rfow$fitted.values
  )

  mtcars2 <- data.frame(
    mpg = 1:3,
    hp = rnorm(3),
    vs = rbinom(3, 1, 0.5),
    cyl = c(4, 2, 4)
  )

  expect_error(
    predict(row, newdata = mtcars2),
    "factor factor\\(cyl\\) has new levels 2"
  )

  expect_error(
    predict(rfow, newdata = mtcars2),
    "Can't have new levels in `newdata` `fixed_effects` variable, such as: cyl2"
  )

  mtcars3 <- data.frame(
    mpg = 1:3,
    hp = rnorm(3),
    vs = rbinom(3, 1, 0.5),
    cyl = c(4, 6, 4)
  )

  expect_equal(
    predict(row, newdata = mtcars3),
    predict(rfow, newdata = mtcars3)
  )

  ## Clustered
  roc <- lm_robust(mpg ~ 0 + hp + vs + factor(cyl), clusters = carb, data = mtcars)
  rfoc <- lm_robust(mpg ~ hp + vs, fixed_effects = ~ cyl, clusters = carb, data = mtcars)

  proc <- predict(roc, newdata = mtcars)
  prfoc <- predict(rfoc, newdata = mtcars)

  expect_equal(
    roc$fitted.values,
    rfoc$fitted.values
  )

  expect_equivalent(
    roc$fitted.values,
    lo$fitted.values # not weighted, just lm predictions
  )

  expect_equal(
    proc,
    prfoc
  )

  expect_equal(
    prfoc,
    plo
  )

  ## Clustered, weights
  rocw <- lm_robust(mpg ~ 0 + hp + vs + factor(cyl), weights = wt, clusters = carb, data = mtcars, se_type = "stata")
  rfocw <- lm_robust(mpg ~ hp + vs, fixed_effects = ~ cyl, weights = wt, clusters = carb, data = mtcars, se_type = "stata")

  procw <- predict(rocw, newdata = mtcars)
  prfocw <- predict(rfocw, newdata = mtcars)

  expect_equal(
    rocw$fitted.values,
    rfocw$fitted.values
  )

  expect_equivalent(
    rocw$fitted.values,
    low$fitted.values # not weighted, just lm predictions
  )

  expect_equal(
    procw,
    prfocw
  )

  expect_equal(
    prfocw,
    plow
  )

  ## Fails with two fixed effects
  rfocw <- lm_robust(mpg ~ hp + vs, fixed_effects = ~ cyl + carb, data = mtcars)
  expect_error(
    predict(rfocw, newdata = mtcars),
    "Can't use `predict.lm_robust` with more than one set of `fixed_effects`"
  )

})

test_that("predict.iv_robust works with fixed effects", {
  skip_if_not_installed("AER")

  library(AER)

  ro <- iv_robust(mpg ~ hp + factor(cyl) | vs + factor(cyl), data = mtcars)
  rfo <- iv_robust(mpg ~ hp | vs, fixed_effects = ~ cyl, data = mtcars)
  io <- ivreg(mpg ~ hp + factor(cyl) | vs + factor(cyl), data = mtcars)

  pio <- predict(io, newdata = mtcars)
  expect_equal(
    ro$fitted.values,
    rfo$fitted.values
  )

  expect_equivalent(
    rfo$fitted.values,
    io$fitted.values
  )

  expect_equal(
    predict(ro, newdata = mtcars),
    predict(rfo, newdata = mtcars)
  )

  expect_equal(
    pio,
    predict(rfo, newdata = mtcars)
  )

  mtcars2 <- data.frame(
    mpg = 1:3,
    hp = rnorm(3),
    vs = rbinom(3, 1, 0.5),
    cyl = c(4, 2, 4)
  )

  expect_error(
    predict(ro, newdata = mtcars2),
    "factor factor\\(cyl\\) has new levels 2"
  )

  expect_error(
    predict(rfo, newdata = mtcars2),
    "Can't have new levels in `newdata` `fixed_effects` variable, such as\\: cyl2"
  )

  mtcars3 <- data.frame(
    mpg = 1:3,
    hp = rnorm(3),
    vs = rbinom(3, 1, 0.5),
    cyl = c(4, 6, 4)
  )

  expect_equal(
    predict(ro, newdata = mtcars3),
    predict(rfo, newdata = mtcars3)
  )

  expect_equal(
    predict(io, newdata = mtcars3),
    predict(rfo, newdata = mtcars3)
  )

  ## Weights
  row <- iv_robust(mpg ~ hp + factor(cyl) | vs + factor(cyl), weights = wt, data = mtcars)
  rfow <- iv_robust(mpg ~ hp | vs, fixed_effects = ~ cyl, weights = wt, data = mtcars)
  iow <- ivreg(mpg ~ hp + factor(cyl) | vs + factor(cyl), weights = wt, data = mtcars)

  piow <- predict(iow, newdata = mtcars)
  prow <- predict(row, newdata = mtcars)
  prfow <- predict(rfow, newdata = mtcars)

  expect_equal(
    prow,
    prfow
  )

  expect_equal(
    prow,
    piow
  )

  expect_equivalent(
    rfow$fitted.values,
    iow$fitted.values
  )

  expect_equal(
    row$fitted.values,
    rfow$fitted.values
  )

  mtcars2 <- data.frame(
    mpg = 1:3,
    hp = rnorm(3),
    vs = rbinom(3, 1, 0.5),
    cyl = c(4, 2, 4)
  )

  expect_error(
    predict(row, newdata = mtcars2),
    "factor factor\\(cyl\\) has new levels 2"
  )

  expect_error(
    predict(rfow, newdata = mtcars2),
    "Can't have new levels in `newdata` `fixed_effects` variable, such as: cyl2"
  )

  mtcars3 <- data.frame(
    mpg = 1:3,
    hp = rnorm(3),
    vs = rbinom(3, 1, 0.5),
    cyl = c(4, 6, 4)
  )

  expect_equal(
    predict(row, newdata = mtcars3),
    predict(rfow, newdata = mtcars3)
  )

  ## Clustered
  roc <- iv_robust(mpg ~ hp + factor(cyl) | vs + factor(cyl), clusters = carb, data = mtcars)
  rfoc <- iv_robust(mpg ~ hp | vs, fixed_effects = ~ cyl, clusters = carb, data = mtcars)

  proc <- predict(roc, newdata = mtcars)
  prfoc <- predict(rfoc, newdata = mtcars)

  expect_equal(
    roc$fitted.values,
    rfoc$fitted.values
  )

  expect_equivalent(
    rfoc$fitted.values,
    io$fitted.values # not weighted, just lm predictions
  )

  expect_equal(
    proc,
    prfoc
  )

  expect_equal(
    prfoc,
    pio
  )

  ## Clustered, weights
  rocw <- iv_robust(mpg ~ hp + factor(cyl) | vs + factor(cyl), clusters = carb, weights = wt, data = mtcars, se_type = "stata")
  rfocw <- iv_robust(mpg ~ hp | vs, fixed_effects = ~ cyl, clusters = carb, weights = wt, data = mtcars, se_type = "stata")

  procw <- predict(rocw, newdata = mtcars)
  prfocw <- predict(rfocw, newdata = mtcars)

  expect_equal(
    rocw$fitted.values,
    rfocw$fitted.values
  )

  expect_equivalent(
    rocw$fitted.values,
    iow$fitted.values # not weighted, just lm predictions
  )

  expect_equal(
    procw,
    prfocw
  )

  expect_equal(
    prfocw,
    piow
  )

  ## Fails with two fixed effects
  rfocw <- iv_robust(mpg ~ hp | vs, fixed_effects = ~ cyl + carb, data = mtcars)
  expect_error(
    predict(rfocw, newdata = mtcars),
    "Can't use `predict.lm_robust` with more than one set of `fixed_effects`"
  )

})
