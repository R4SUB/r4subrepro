# Tests for path_hygiene_report(), the descriptive companion to R-REPRO-002.

test_that("clean submission returns a zero-row tibble with the right columns", {
  d <- file.path(tempdir(), paste0("phr_clean_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines(c("library(dplyr)",
               "adsl <- read.csv(file.path('data', 'adsl.csv'))"),
             file.path(d, "a.R"))
  rep <- path_hygiene_report(d)
  expect_s3_class(rep, "tbl_df")
  expect_identical(names(rep),
                   c("file", "line", "type", "path", "suggestion"))
  expect_equal(nrow(rep), 0L)
  expect_type(rep$line, "integer")
})

test_that("flags a Windows drive path with file, line, type and suggestion", {
  d <- file.path(tempdir(), paste0("phr_win_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines(c("x <- 1",
               "adsl <- read.csv('C:/Users/me/study/data/adsl.csv')"),
             file.path(d, "analysis.R"))
  rep <- path_hygiene_report(d)
  expect_equal(nrow(rep), 1L)
  expect_equal(rep$file, "analysis.R")
  expect_equal(rep$line, 2L)
  expect_equal(rep$type, "windows_drive")
  expect_equal(rep$path, "C:/Users/me/study/data/adsl.csv")
  # Advisory rewrite keeps the tail from the "data" anchor onward.
  expect_equal(rep$suggestion, "data/adsl.csv")
})

test_that("classifies the four non-portable path categories", {
  d <- file.path(tempdir(), paste0("phr_cats_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines(c(
    "a <- read.csv('C:/study/adsl.csv')",
    "b <- read.csv('\\\\\\\\server\\\\share\\\\adae.csv')",
    "c <- readRDS('~/cache/model.rds')",
    "e <- read.csv('/home/me/study/adlb.csv')"
  ), file.path(d, "s.R"))
  rep <- path_hygiene_report(d)
  expect_setequal(rep$type,
                  c("windows_drive", "unc_share", "home_dir", "posix_absolute"))
  expect_equal(nrow(rep), 4L)
})

test_that("ignores portable relative paths and URLs", {
  d <- file.path(tempdir(), paste0("phr_url_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines(c(
    "u <- 'https://cran.r-project.org/package=dplyr'",
    "r <- read.csv('data/adsl.csv')",
    "p <- file.path('outputs', 'res.csv')"
  ), file.path(d, "s.R"))
  rep <- path_hygiene_report(d)
  expect_equal(nrow(rep), 0L)
})

test_that("suggestion falls back to the file name when no anchor directory", {
  d <- file.path(tempdir(), paste0("phr_base_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("adae <- read.csv('/home/me/study/adae.csv')",
             file.path(d, "s.R"))
  rep <- path_hygiene_report(d)
  expect_equal(rep$suggestion, "adae.csv")
})

test_that("does not change the R-REPRO-002 indicator result or count", {
  d <- file.path(tempdir(), paste0("phr_indic_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines(c("a <- read.csv('C:/study/adsl.csv')",
               "b <- read.csv('/home/me/adae.csv')"),
             file.path(d, "s.R"))
  ev_before <- suppressMessages(assess_path_hygiene(d))
  rep <- path_hygiene_report(d)
  ev_after  <- suppressMessages(assess_path_hygiene(d))
  expect_equal(ev_before$result, "fail")
  expect_equal(ev_after$result, ev_before$result)
  expect_equal(ev_after$metric_value, ev_before$metric_value)
  # The report names each offending path the indicator counted.
  expect_equal(nrow(rep), ev_before$metric_value)
})

test_that("errors on a missing directory", {
  expect_error(path_hygiene_report(file.path(tempdir(), "no_such_dir_xyz")))
})
