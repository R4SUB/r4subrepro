# Tests for assess_dual_verification() and assess_sas_r_concordance() (R-REPRO-009)

test_that("dual verification: passes when a QC/comparison artifact is present", {
  d <- file.path(tempdir(), paste0("dv_good_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("x", file.path(d, "qc_compare_sas_r.rtf"))
  e <- suppressMessages(assess_dual_verification(d))
  expect_equal(e$result, "pass")
  expect_equal(e$indicator_id, "R-REPRO-009")
  expect_gte(e$metric_value, 1)
})

test_that("dual verification: warns (medium) when no verification evidence", {
  d <- file.path(tempdir(), paste0("dv_bad_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("library(dplyr)", file.path(d, "analysis.R"))
  e <- suppressMessages(assess_dual_verification(d))
  expect_equal(e$result, "warn")
  expect_equal(e$severity, "medium")
})

test_that("concordance: identical tables pass with rate 1", {
  a <- data.frame(id = 1:3, val = c(1, 2, 3))
  b <- data.frame(id = 1:3, val = c(1, 2, 3))
  e <- suppressMessages(assess_sas_r_concordance(a, b))
  expect_equal(e$result, "pass")
  expect_equal(e$metric_value, 1)
})

test_that("concordance: within-tolerance numerics still pass", {
  a <- data.frame(id = 1:2, val = c(1.0, 2.0))
  b <- data.frame(id = 1:2, val = c(1.0 + 1e-10, 2.0 - 1e-10))
  e <- suppressMessages(assess_sas_r_concordance(a, b, tol = 1e-8))
  expect_equal(e$result, "pass")
})

test_that("concordance: differing values fail (high) with a rate below 1", {
  a <- data.frame(id = 1:3, val = c(1, 2, 3))
  b <- data.frame(id = 1:3, val = c(1, 2, 99))
  e <- suppressMessages(assess_sas_r_concordance(a, b))
  expect_equal(e$result, "fail")
  expect_equal(e$severity, "high")
  expect_lt(e$metric_value, 1)
})

test_that("concordance: differing row counts warn rather than error", {
  a <- data.frame(id = 1:3, val = c(1, 2, 3))
  b <- data.frame(id = 1:2, val = c(1, 2))
  e <- suppressMessages(assess_sas_r_concordance(a, b))
  expect_equal(e$result, "warn")
})

test_that("concordance: keys align rows before comparison", {
  a <- data.frame(id = c(1, 2, 3), val = c(10, 20, 30))
  b <- data.frame(id = c(3, 1, 2), val = c(30, 10, 20))
  e <- suppressMessages(assess_sas_r_concordance(a, b, keys = "id"))
  expect_equal(e$result, "pass")
})

test_that("concordance: reads CSV paths", {
  d <- file.path(tempdir(), paste0("dv_csv_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  write.csv(data.frame(id = 1:2, val = c(5, 6)), file.path(d, "r.csv"),
            row.names = FALSE)
  write.csv(data.frame(id = 1:2, val = c(5, 6)), file.path(d, "s.csv"),
            row.names = FALSE)
  e <- suppressMessages(assess_sas_r_concordance(file.path(d, "r.csv"),
                                                 file.path(d, "s.csv")))
  expect_equal(e$result, "pass")
})

test_that("dual verification is part of the full assessment", {
  d <- file.path(tempdir(), paste0("dv_full_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("x", file.path(d, "a.R"))
  ev <- suppressMessages(assess_reproducibility(d))
  expect_true("R-REPRO-009" %in% ev$indicator_id)
})
