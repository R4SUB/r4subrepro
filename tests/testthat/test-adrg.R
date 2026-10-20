# Tests for assess_adrg() and adrg_skeleton() (R-REPRO-010)

adrg_sections <- function() {
  c("# Analysis Data Reviewer's Guide",
    "## 1. Introduction", "### 1.1 Purpose",
    "### 1.2 Study Data Standards and Dictionary Inventory", "define.xml",
    "## 5. Analysis Dataset Descriptions", "ADSL",
    "## 6. Data Conformance Summary", "Pinnacle 21",
    "## 7. Submission of Programs",
    "### 7.5 Open-source R Analysis Packages", "dplyr",
    "## 8. Directory Structure", "eCTD module 5",
    "## 9. Reproducibility and Verification", "SAS vs R",
    "## Appendix: Instructions to Execute Analysis Programs in R", "install R")
}

test_that("adrg: fails (medium) when no guide is present", {
  d <- file.path(tempdir(), paste0("adrg_none_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("x <- 1", file.path(d, "a.R"))
  e <- suppressMessages(assess_adrg(d))
  expect_equal(e$result, "fail")
  expect_equal(e$severity, "medium")
  expect_equal(e$indicator_id, "R-REPRO-010")
})

test_that("adrg: passes when a complete markdown guide is present", {
  d <- file.path(tempdir(), paste0("adrg_full_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines(adrg_sections(), file.path(d, "adrg.md"))
  e <- suppressMessages(assess_adrg(d))
  expect_equal(e$result, "pass")
  expect_equal(e$metric_value, 1)
})

test_that("adrg: warns (medium) when sections are missing", {
  d <- file.path(tempdir(), paste0("adrg_partial_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines(c("# ADRG", "## Required inputs", "adsl.csv"),
             file.path(d, "adrg.md"))
  e <- suppressMessages(assess_adrg(d))
  expect_equal(e$result, "warn")
  expect_lt(e$metric_value, 1)
})

test_that("adrg: a binary guide is recognised as present and passes", {
  d <- file.path(tempdir(), paste0("adrg_pdf_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("binary placeholder", file.path(d, "adrg.pdf"))
  e <- suppressMessages(assess_adrg(d))
  expect_equal(e$result, "pass")
  expect_true(is.na(e$metric_value))
})

test_that("adrg_skeleton: writes a draft that assess_adrg accepts", {
  d <- file.path(tempdir(), paste0("adrg_gen_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines(c("library(dplyr)", "adsl <- read.csv('data/adsl.csv')"),
             file.path(d, "run.R"))
  f <- suppressMessages(adrg_skeleton(d))
  expect_true(file.exists(f))
  e <- suppressMessages(assess_adrg(d))
  expect_equal(e$result, "pass")
})

test_that("adrg_skeleton: records detected inputs and packages", {
  d <- file.path(tempdir(), paste0("adrg_gen2_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines(c("library(dplyr)", "adsl <- read.csv('data/adsl.csv')"),
             file.path(d, "run.R"))
  suppressMessages(adrg_skeleton(d))
  txt <- paste(readLines(file.path(d, "ADRG.md")), collapse = "\n")
  expect_true(grepl("data/adsl.csv", txt, fixed = TRUE))
  expect_true(grepl("dplyr", txt, fixed = TRUE))
})

test_that("adrg is part of the full assessment", {
  d <- file.path(tempdir(), paste0("adrg_full2_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE)
  writeLines("x <- 1", file.path(d, "a.R"))
  ev <- suppressMessages(assess_reproducibility(d))
  expect_true("R-REPRO-010" %in% ev$indicator_id)
})
