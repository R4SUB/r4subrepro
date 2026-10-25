# Summarise Reproducibility Evidence

Produces a structured summary of reproducibility evidence, suitable for
printing or for passing to downstream reporting.

## Usage

``` r
reproducibility_summary(evidence, config = NULL)
```

## Arguments

- evidence:

  A validated evidence table from
  [`assess_reproducibility()`](https://r4sub.github.io/r4subrepro/reference/assess_reproducibility.md)
  or the individual assessment functions.

- config:

  A configuration from
  [`repro_config_default()`](https://r4sub.github.io/r4subrepro/reference/repro_config_default.md),
  used for the per-indicator weights in the overall score. When `NULL`
  the default configuration is used.

## Value

A `repro_result` list (class `"repro_result"`) with:

- study_id:

  The study identifier from the evidence.

- n_indicators:

  Number of distinct indicators assessed.

- overall_score:

  The weighted mean of the per-indicator scores (pass is 1, warn is 0.5,
  fail is 0), using the configuration weights.

- summary:

  A data.frame with one row per indicator: `indicator_id`,
  `indicator_name`, `result`, `severity`, and `score`.

- n_pass, n_fail, n_warn:

  Counts across indicators.

- evidence:

  The original evidence table.

## Examples

``` r
d <- file.path(tempdir(), "sub_sum")
dir.create(d, showWarnings = FALSE)
writeLines("{}", file.path(d, "renv.lock"))
writeLines("source('a.R')", file.path(d, "run.R"))
writeLines("x <- read.csv('data/adsl.csv')", file.path(d, "a.R"))
ev  <- suppressMessages(assess_reproducibility(d))
res <- reproducibility_summary(ev)
print(res)
#> 
#> ── R4SUB Reproducibility Assessment ──
#> 
#> Study: "sub_sum" | Indicators: 11
#> 
#> ! R-REPRO-001 Environment Lockfile Present: warn
#> u2713 R-REPRO-002 Path Hygiene: pass
#> u2713 R-REPRO-003 Single Entry Point: pass
#> u2713 R-REPRO-004 Hidden Setup Assumptions: pass
#> u2713 R-REPRO-005 Package Reproducibility Tiering: pass
#> ! R-REPRO-006 Clean Run Evidence: warn
#> u2713 R-REPRO-007 Script Complexity: pass
#> ! R-REPRO-009 Dual Verification: warn
#> u2717 R-REPRO-010 Analysis Data Reviewer's Guide: fail
#> u2713 R-REPRO-011 Windows Reviewability: pass
#> u2713 R-REPRO-012 Compiled-Code Toolchain: pass
#> 
#> ℹ Overall reproducibility score: 76.1% (7 pass, 3 warn, 1 fail)
```
