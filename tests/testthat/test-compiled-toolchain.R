# Tests for assess_compiled_toolchain() (R-REPRO-012)

test_that("a submission with no native code passes", {
  d <- file.path(tempdir(), paste0("ct_none_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("x <- dplyr::filter(mtcars, mpg > 20)", file.path(d, "a.R"))
  e <- suppressMessages(assess_compiled_toolchain(d))
  expect_equal(e$result, "pass")
  expect_equal(e$indicator_id, "R-REPRO-012")
  expect_equal(e$metric_value, 0)
})

test_that("native source without a documented toolchain warns", {
  d <- file.path(tempdir(), paste0("ct_src_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("double f(double x) { return x; }", file.path(d, "fast.cpp"))
  writeLines("x <- 1", file.path(d, "a.R"))
  e <- suppressMessages(assess_compiled_toolchain(d))
  expect_equal(e$result, "warn")
  expect_equal(e$severity, "medium")
  expect_gte(e$metric_value, 1)
  expect_true(grepl("Rtools", e$message))
})

test_that("native source with a documented toolchain passes", {
  d <- file.path(tempdir(), paste0("ct_doc_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("double f(double x) { return x; }", file.path(d, "fast.cpp"))
  writeLines(c("# Setup", "Install Rtools matching your R version before building."),
             file.path(d, "README.md"))
  e <- suppressMessages(assess_compiled_toolchain(d))
  expect_equal(e$result, "pass")
  expect_gte(e$metric_value, 1)
})

test_that("an inline sourceCpp() call is detected", {
  d <- file.path(tempdir(), paste0("ct_inline_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines(c("library(Rcpp)", "sourceCpp('fast.cpp')"), file.path(d, "a.R"))
  e <- suppressMessages(assess_compiled_toolchain(d))
  expect_equal(e$result, "warn")
})

test_that("compiled toolchain is part of the full assessment", {
  d <- file.path(tempdir(), paste0("ct_full_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("x <- 1", file.path(d, "a.R"))
  ev <- suppressMessages(assess_reproducibility(d))
  expect_true("R-REPRO-012" %in% ev$indicator_id)
})
