# Build two synthetic submission folders used across the tests.

make_good_submission <- function() {
  d <- file.path(tempdir(), paste0("repro_good_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE, recursive = TRUE)
  dir.create(file.path(d, "data"), showWarnings = FALSE)

  writeLines(c(
    '{ "R": { "Version": "4.5.1" },',
    '  "Packages": { "dplyr": { "Package": "dplyr", "Version": "1.1.4" } } }'
  ), file.path(d, "renv.lock"))

  writeLines(c(
    "source('load.R')",
    "source('analysis.R')"
  ), file.path(d, "run.R"))

  writeLines(c(
    "library(dplyr)",
    "adsl <- read.csv('data/adsl.csv')"
  ), file.path(d, "load.R"))

  writeLines(c(
    "result <- adsl",
    "if (nrow(result) > 0) {",
    "  message('ok')",
    "}"
  ), file.path(d, "analysis.R"))

  writeLines(c("R version 4.5.1", "attached packages: dplyr"),
             file.path(d, "sessionInfo.txt"))

  # Independent verification evidence (R-REPRO-009).
  writeLines("SAS vs R comparison: all values match",
             file.path(d, "qc_compare_sas_r.rtf"))

  # A complete ADRG covering the required sections (R-REPRO-010).
  writeLines(c(
    "# Analysis Data Reviewer's Guide",
    "## 1. Introduction", "### 1.1 Purpose",
    "### 1.2 Study Data Standards and Dictionary Inventory", "define.xml",
    "## 5. Analysis Dataset Descriptions", "ADSL",
    "## 6. Data Conformance Summary", "Pinnacle 21",
    "## 7. Submission of Programs",
    "### 7.5 Open-source R Analysis Packages", "dplyr",
    "## 8. Directory Structure", "eCTD module 5",
    "## 9. Reproducibility and Verification", "SAS vs R",
    "## Appendix: Instructions to Execute Analysis Programs in R", "install R"
  ), file.path(d, "adrg.md"))

  d
}

make_bad_submission <- function() {
  d <- file.path(tempdir(), paste0("repro_bad_", as.integer(runif(1, 1, 1e6))))
  dir.create(d, showWarnings = FALSE, recursive = TRUE)

  # No renv.lock, no entry point, no run evidence.
  writeLines(c(
    "library(dplyr)",
    "library(acmeinternal)",
    "Sys.setenv(MYVAR = 'x')",
    "system('rm -rf /tmp/scratch')",
    "adsl <- read.csv('C:/Users/me/study/adsl.csv')",
    "adae <- read.csv('/home/me/study/adae.csv')",
    "deep <- function(x) {",
    "  if (x > 0) {",
    "    for (i in 1:x) {",
    "      while (i > 0) {",
    "        repeat {",
    "          tryCatch({",
    "            if (TRUE) {",
    "              i <- i - 1",
    "            }",
    "          }, error = function(e) NULL)",
    "          break",
    "        }",
    "        i <- i - 1",
    "      }",
    "    }",
    "  }",
    "}"
  ), file.path(d, "messy.R"))

  writeLines("Sys.setenv(SECRET = 'y')", file.path(d, ".Rprofile"))
  d
}
