# Tests for repro_report() (R/repro_report.R)

test_that("repro_report returns valid JSON with the expected structure", {
  good <- make_good_submission()
  ev   <- suppressMessages(assess_reproducibility(good))

  js <- repro_report(ev, format = "json")
  expect_type(js, "character")
  expect_length(js, 1L)

  parsed <- jsonlite::fromJSON(js, simplifyVector = FALSE)
  expect_equal(parsed$report_type, "r4subrepro reproducibility report")
  expect_true(nzchar(parsed$schema_version))
  expect_true(grepl("decision-support", parsed$disclaimer, ignore.case = TRUE))
  expect_true(grepl("not an official submission artifact", parsed$disclaimer,
                    ignore.case = TRUE))
  expect_equal(parsed$source$name, "r4subrepro")
  expect_equal(parsed$counts$indicators, 11L)
  expect_length(parsed$indicators, 11L)

  ids <- vapply(parsed$indicators, function(i) i$indicator_id, character(1))
  expect_true("R-REPRO-001" %in% ids)
  first <- parsed$indicators[[1]]
  expect_true(all(c("indicator_id", "indicator_name", "result", "severity",
                    "message") %in% names(first)))
})

test_that("repro_report JSON score matches the summary score", {
  good <- make_good_submission()
  ev   <- suppressMessages(assess_reproducibility(good))
  res  <- reproducibility_summary(ev)

  parsed <- jsonlite::fromJSON(repro_report(res, format = "json"),
                               simplifyVector = FALSE)
  expect_equal(parsed$overall_score, res$overall_score, tolerance = 1e-9)
  expect_equal(parsed$counts$pass, res$n_pass)
  expect_equal(parsed$counts$fail, res$n_fail)
})

test_that("repro_report markdown includes the disclaimer and a table", {
  good <- make_good_submission()
  ev   <- suppressMessages(assess_reproducibility(good))

  md <- repro_report(ev, format = "markdown")
  expect_type(md, "character")
  expect_length(md, 1L)
  expect_match(md, "# R4SUB Reproducibility Report")
  expect_match(md, "decision-support", ignore.case = TRUE)
  expect_match(md, "not an official", ignore.case = TRUE)
  expect_match(md, "R-REPRO-001")
  expect_match(md, "Overall reproducibility score")
  expect_match(md, "| Indicator |", fixed = TRUE)
})

test_that("repro_report accepts both evidence tables and repro_result", {
  good <- make_good_submission()
  ev   <- suppressMessages(assess_reproducibility(good))
  res  <- reproducibility_summary(ev)

  from_ev  <- repro_report(ev, format = "json")
  from_res <- repro_report(res, format = "json")

  p1 <- jsonlite::fromJSON(from_ev, simplifyVector = FALSE)
  p2 <- jsonlite::fromJSON(from_res, simplifyVector = FALSE)
  expect_equal(p1$overall_score, p2$overall_score)
  expect_equal(length(p1$indicators), length(p2$indicators))
})

test_that("repro_report writes to a file and returns the path invisibly", {
  good <- make_good_submission()
  ev   <- suppressMessages(assess_reproducibility(good))

  f <- file.path(tempdir(), paste0("repro_", as.integer(runif(1, 1, 1e6)), ".json"))
  out <- withVisible(suppressMessages(repro_report(ev, format = "json", file = f)))
  expect_false(out$visible)
  expect_identical(out$value, f)
  expect_true(file.exists(f))
  parsed <- jsonlite::fromJSON(paste(readLines(f), collapse = "\n"),
                               simplifyVector = FALSE)
  expect_equal(parsed$report_type, "r4subrepro reproducibility report")
})

test_that("repro_report rejects an invalid x", {
  expect_error(repro_report(data.frame(a = 1)), "evidence table")
  expect_error(repro_report(42), "evidence table")
})

test_that("repro_report handles an na overall score without erroring", {
  # An evidence table whose only indicator is na-scored (output reproduction,
  # not run) yields an unavailable overall score; the report must still render.
  d <- file.path(tempdir(), paste0("repro_na_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("writeLines('1', 'outputs/res.txt')", file.path(d, "run.R"))
  ev <- suppressMessages(assess_output_reproduction(d, run = FALSE))

  js <- repro_report(ev, format = "json")
  parsed <- jsonlite::fromJSON(js, simplifyVector = FALSE)
  expect_null(parsed$overall_score)
  md <- repro_report(ev, format = "markdown")
  expect_match(md, "not available")
})
