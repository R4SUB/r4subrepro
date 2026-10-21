# Tests for package reproducibility tiering (R-REPRO-005)

mk <- function(scripts, lock = NULL) {
  d <- file.path(tempdir(), paste0("tier_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines(scripts, file.path(d, "a.R"))
  if (!is.null(lock)) writeLines(lock, file.path(d, "renv.lock"))
  d
}

test_that("all CRAN/known packages pass", {
  d <- mk("library(dplyr)")
  e <- suppressMessages(assess_proprietary_pkgs(d))
  expect_equal(e$result, "pass")
  expect_equal(e$indicator_id, "R-REPRO-005")
  expect_equal(e$metric_value, 0)
})

test_that("an undeclared package is a medium warn", {
  d <- mk("library(acmeinternal)")
  e <- suppressMessages(assess_proprietary_pkgs(d))
  expect_equal(e$result, "warn")
  expect_equal(e$severity, "medium")
  expect_true(grepl("undeclared", e$message))
  expect_true(grepl("acmeinternal", e$message))
})

test_that("a non-CRAN package declared from a GitHub source is a low warn", {
  d <- mk("library(acmeghpkg)",
          c('{ "Packages": {',
            '  "acmeghpkg": { "Package": "acmeghpkg", "Version": "0.1.0",',
            '                 "Source": "GitHub" } } }'))
  e <- suppressMessages(assess_proprietary_pkgs(d))
  expect_equal(e$result, "warn")
  expect_equal(e$severity, "low")
  expect_true(grepl("non-CRAN", e$message))
  expect_true(grepl("acmeghpkg", e$message))
})

test_that("a package declared from a repository source passes", {
  d <- mk("library(acmecran)",
          c('{ "Packages": {',
            '  "acmecran": { "Package": "acmecran", "Version": "1.0",',
            '                "Source": "Repository", "Repository": "CRAN" } } }'))
  e <- suppressMessages(assess_proprietary_pkgs(d))
  expect_equal(e$result, "pass")
})

test_that("undeclared severity dominates a non-CRAN declaration", {
  d <- mk(c("library(acmeghpkg)", "library(acmeinternal)"),
          c('{ "Packages": {',
            '  "acmeghpkg": { "Package": "acmeghpkg", "Source": "GitHub" } } }'))
  e <- suppressMessages(assess_proprietary_pkgs(d))
  expect_equal(e$result, "warn")
  expect_equal(e$severity, "medium")
  expect_equal(e$metric_value, 2)
})
