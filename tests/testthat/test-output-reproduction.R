# Tests for assess_output_reproduction() (R-REPRO-008)

make_repro_submission <- function(content = "1") {
  d <- file.path(tempdir(), paste0("repro_run_", as.integer(runif(1, 1, 1e6))))
  dir.create(file.path(d, "outputs"), recursive = TRUE, showWarnings = FALSE)
  writeLines("writeLines('1', file.path('outputs', 'res.txt'))",
             file.path(d, "run.R"))
  writeLines(content, file.path(d, "outputs", "res.txt"))
  d
}

test_that("na when execution is not attempted", {
  d <- make_repro_submission()
  e <- suppressMessages(assess_output_reproduction(d, run = FALSE))
  expect_equal(e$result, "na")
  expect_equal(e$indicator_id, "R-REPRO-008")
  expect_true(is.na(e$metric_value))
})

test_that("fail (high) when run requested but no entry point", {
  d <- file.path(tempdir(), paste0("repro_noentry_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("x <- 1", file.path(d, "a.R"))
  e <- suppressMessages(assess_output_reproduction(d, run = TRUE))
  expect_equal(e$result, "fail")
  expect_equal(e$severity, "high")
})

test_that("reproduces submitted outputs exactly (pass on Windows, warn elsewhere)", {
  skip_if_not_installed("callr")
  d <- make_repro_submission(content = "1")
  e <- suppressMessages(assess_output_reproduction(d, run = TRUE))
  # Outputs reproduce (match_rate 1); result is pass on Windows, warn elsewhere
  # because FDA reviewers execute on Windows.
  expect_equal(e$metric_value, 1)
  if (.Platform$OS.type == "windows") {
    expect_equal(e$result, "pass")
  } else {
    expect_equal(e$result, "warn")
  }
})

test_that("fail when the re-run produces different outputs", {
  skip_if_not_installed("callr")
  # Submitted output says "2" but the script writes "1": a mismatch.
  d <- make_repro_submission(content = "2")
  e <- suppressMessages(assess_output_reproduction(d, run = TRUE))
  expect_equal(e$result, "fail")
  expect_equal(e$severity, "high")
  expect_lt(e$metric_value, 1)
})

test_that("warn when the script errors", {
  skip_if_not_installed("callr")
  d <- file.path(tempdir(), paste0("repro_err_", as.integer(runif(1, 1, 1e6))))
  dir.create(file.path(d, "outputs"), recursive = TRUE, showWarnings = FALSE)
  writeLines("stop('boom')", file.path(d, "run.R"))
  writeLines("1", file.path(d, "outputs", "res.txt"))
  e <- suppressMessages(assess_output_reproduction(d, run = TRUE))
  expect_equal(e$result, "fail")
  expect_equal(e$severity, "high")
})

test_that("the submission folder is not modified by the run", {
  skip_if_not_installed("callr")
  d <- make_repro_submission(content = "2")
  before <- tools::md5sum(file.path(d, "outputs", "res.txt"))
  suppressMessages(assess_output_reproduction(d, run = TRUE))
  after <- tools::md5sum(file.path(d, "outputs", "res.txt"))
  expect_equal(unname(before), unname(after))
})

test_that("include_execution appends R-REPRO-008 to the full assessment", {
  d <- make_repro_submission()
  ev <- suppressMessages(assess_reproducibility(d, include_execution = TRUE))
  expect_true("R-REPRO-008" %in% ev$indicator_id)
  ev2 <- suppressMessages(assess_reproducibility(d))
  expect_false("R-REPRO-008" %in% ev2$indicator_id)
})
