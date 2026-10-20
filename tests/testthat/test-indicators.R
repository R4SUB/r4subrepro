# Tests for the seven reproducibility indicators (R/repro_indicators.R)

test_that("env lockfile: good passes, bad fails", {
  good <- make_good_submission(); bad <- make_bad_submission()
  eg <- suppressMessages(assess_env_lockfile(good))
  eb <- suppressMessages(assess_env_lockfile(bad))
  expect_equal(eg$result, "pass")
  expect_equal(eg$indicator_id, "R-REPRO-001")
  expect_equal(eb$result, "fail")
  expect_equal(eb$severity, "high")
})

test_that("path hygiene: good passes, bad fails and counts hits", {
  good <- make_good_submission(); bad <- make_bad_submission()
  eg <- suppressMessages(assess_path_hygiene(good))
  eb <- suppressMessages(assess_path_hygiene(bad))
  expect_equal(eg$result, "pass")
  expect_equal(eb$result, "fail")
  expect_gte(eb$metric_value, 2)   # C:/ and /home/
})

test_that("path hygiene does not flag URLs", {
  d <- file.path(tempdir(), paste0("url_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("x <- 'https://cran.r-project.org/package=dplyr'",
             file.path(d, "a.R"))
  e <- suppressMessages(assess_path_hygiene(d))
  expect_equal(e$result, "pass")
})

test_that("entry point: good passes, bad fails", {
  good <- make_good_submission(); bad <- make_bad_submission()
  expect_equal(suppressMessages(assess_entry_point(good))$result, "pass")
  eb <- suppressMessages(assess_entry_point(bad))
  expect_equal(eb$result, "fail")
  expect_equal(eb$severity, "medium")
})

test_that("hidden setup: good passes, bad fails on Sys.setenv and .Rprofile", {
  good <- make_good_submission(); bad <- make_bad_submission()
  expect_equal(suppressMessages(assess_hidden_setup(good))$result, "pass")
  expect_equal(suppressMessages(assess_hidden_setup(bad))$result, "fail")
})

test_that("hidden setup: Sys.getenv alone is a warn", {
  d <- file.path(tempdir(), paste0("env_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("k <- Sys.getenv('HOME')", file.path(d, "a.R"))
  expect_equal(suppressMessages(assess_hidden_setup(d))$result, "warn")
})

test_that("proprietary packages: internal package is flagged, base is not", {
  good <- make_good_submission(); bad <- make_bad_submission()
  eg <- suppressMessages(assess_proprietary_pkgs(good))
  eb <- suppressMessages(assess_proprietary_pkgs(bad))
  expect_equal(eg$result, "pass")
  expect_equal(eb$result, "warn")
  expect_true(grepl("acmeinternal", eb$message))
})

test_that("proprietary packages: declaring in renv.lock excuses it", {
  d <- file.path(tempdir(), paste0("decl_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("library(acmeinternal)", file.path(d, "a.R"))
  writeLines('{"Packages": {"acmeinternal": {"Package": "acmeinternal"}}}',
             file.path(d, "renv.lock"))
  expect_equal(suppressMessages(assess_proprietary_pkgs(d))$result, "pass")
})

test_that("clean run evidence: good passes, bad warns", {
  good <- make_good_submission(); bad <- make_bad_submission()
  expect_equal(suppressMessages(assess_clean_run_evidence(good))$result, "pass")
  eb <- suppressMessages(assess_clean_run_evidence(bad))
  expect_equal(eb$result, "warn")
  expect_equal(eb$severity, "low")
})

test_that("script depth: good passes, bad warns and reports depth", {
  good <- make_good_submission(); bad <- make_bad_submission()
  expect_equal(suppressMessages(assess_script_depth(good))$result, "pass")
  eb <- suppressMessages(assess_script_depth(bad))
  expect_equal(eb$result, "warn")
  expect_gt(eb$metric_value, 6)
})

test_that("all evidence rows use the usability domain and r4subrepro source", {
  good <- make_good_submission()
  ev <- suppressMessages(assess_reproducibility(good))
  expect_true(all(ev$indicator_domain == "usability"))
  expect_true(all(ev$source_name == "r4subrepro"))
  expect_setequal(ev$indicator_id,
                  c(paste0("R-REPRO-00", 1:7), "R-REPRO-009", "R-REPRO-010",
                    "R-REPRO-011"))
})

test_that("assess_reproducibility binds the static indicators", {
  good <- make_good_submission()
  ev <- suppressMessages(assess_reproducibility(good))
  expect_equal(nrow(ev), 10L)
  expect_s3_class(ev, "data.frame")
})

test_that("a supplied run context is respected", {
  good <- make_good_submission()
  ctx <- suppressMessages(r4subcore::r4sub_run_context(study_id = "STUDY-XYZ"))
  ev <- suppressMessages(assess_reproducibility(good, ctx = ctx))
  expect_true(all(ev$study_id == "STUDY-XYZ"))
})

test_that("a missing directory is an informative error", {
  expect_error(assess_reproducibility(file.path(tempdir(), "does_not_exist_xyz")),
               "Directory not found")
})
