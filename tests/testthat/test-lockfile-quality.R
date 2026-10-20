# Tests for graded lockfile quality in assess_env_lockfile() (R-REPRO-001)

new_dir <- function(tag) {
  d <- file.path(tempdir(), paste0(tag, "_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE, recursive = TRUE)
  d
}

test_that("a version-pinned renv.lock passes", {
  d <- new_dir("lock_pass")
  writeLines(c('{ "R": { "Version": "4.4.1" },',
               '  "Packages": { "dplyr": { "Package": "dplyr", "Version": "1.1.4" } } }'),
             file.path(d, "renv.lock"))
  e <- suppressMessages(assess_env_lockfile(d))
  expect_equal(e$result, "pass")
  expect_equal(e$indicator_id, "R-REPRO-001")
  expect_equal(e$metric_value, 1)
})

test_that("an empty renv.lock stub warns", {
  d <- new_dir("lock_stub")
  writeLines("{}", file.path(d, "renv.lock"))
  e <- suppressMessages(assess_env_lockfile(d))
  expect_equal(e$result, "warn")
  expect_equal(e$severity, "medium")
})

test_that("a DESCRIPTION-only dependency list warns, not passes", {
  d <- new_dir("lock_desc")
  writeLines(c("Package: mystudy", "Version: 0.1.0",
               "Imports: dplyr (>= 1.0.0), ggplot2"),
             file.path(d, "DESCRIPTION"))
  e <- suppressMessages(assess_env_lockfile(d))
  expect_equal(e$result, "warn")
  expect_equal(e$severity, "medium")
})

test_that("no captured environment fails", {
  d <- new_dir("lock_none")
  writeLines("x <- 1", file.path(d, "a.R"))
  e <- suppressMessages(assess_env_lockfile(d))
  expect_equal(e$result, "fail")
  expect_equal(e$severity, "high")
})

test_that("a packrat lockfile passes", {
  d <- new_dir("lock_packrat")
  writeLines("PackratFormat: 1.4", file.path(d, "packrat.lock"))
  e <- suppressMessages(assess_env_lockfile(d))
  expect_equal(e$result, "pass")
})
