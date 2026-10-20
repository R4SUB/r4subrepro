# Tests for config and reproducibility_summary (R/repro_config.R, R/print.R)

test_that("repro_config_default has weights summing to 1", {
  cfg <- repro_config_default()
  expect_s3_class(cfg, "repro_config")
  expect_equal(sum(unlist(cfg$weights)), 1)
  expect_true(cfg$max_script_depth >= 1)
})

test_that("resolve_config rejects a non-config", {
  expect_error(assess_env_lockfile(tempdir(), config = list(x = 1)),
               "repro_config")
})

test_that("summary scores a clean submission near the top", {
  good <- make_good_submission()
  ev  <- suppressMessages(assess_reproducibility(good))
  res <- reproducibility_summary(ev)
  expect_s3_class(res, "repro_result")
  expect_equal(res$n_indicators, 10L)
  expect_gte(res$overall_score, 0.9)
  expect_equal(res$n_fail, 0L)
})

test_that("summary scores a poor submission low", {
  bad <- make_bad_submission()
  ev  <- suppressMessages(assess_reproducibility(bad))
  res <- reproducibility_summary(ev)
  expect_lt(res$overall_score, 0.5)
  expect_gte(res$n_fail, 1L)
})

test_that("print returns its input invisibly", {
  good <- make_good_submission()
  ev  <- suppressMessages(assess_reproducibility(good))
  res <- reproducibility_summary(ev)
  out <- withVisible(print(res))
  expect_false(out$visible)
  expect_identical(out$value, res)
})

test_that("summary weights come from the config", {
  good <- make_good_submission()
  ev  <- suppressMessages(assess_reproducibility(good))
  res <- reproducibility_summary(ev, config = repro_config_default())
  expect_true(is.numeric(res$overall_score))
})
