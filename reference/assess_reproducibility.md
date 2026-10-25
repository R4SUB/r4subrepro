# Assess Reproducibility of a Submission Folder

Runs the static reproducibility indicators over a submission's analysis
code folder and returns the combined R4SUB evidence table. The rows
carry `indicator_domain = "usability"`, so they flow directly into the
Submission Confidence Index alongside the other reviewer-experience
indicators.

## Usage

``` r
assess_reproducibility(
  path,
  ctx = NULL,
  config = repro_config_default(),
  include_execution = FALSE
)
```

## Arguments

- path:

  Path to the submission's analysis code folder.

- ctx:

  A run context from
  [`r4subcore::r4sub_run_context()`](https://r4sub.github.io/r4subcore/reference/r4sub_run_context.html).
  When `NULL` a default context is created from the folder name.

- config:

  A configuration from
  [`repro_config_default()`](https://r4sub.github.io/r4subrepro/reference/repro_config_default.md).

- include_execution:

  When `TRUE`, also runs
  [`assess_output_reproduction()`](https://r4sub.github.io/r4subrepro/reference/assess_output_reproduction.md)
  (`R-REPRO-008`), which executes the submission's entry point. Off by
  default so the scan stays static and never runs submission code
  unasked.

## Value

A validated, combined evidence table for indicators `R-REPRO-001`
through `R-REPRO-007`, `R-REPRO-009`, `R-REPRO-010`, `R-REPRO-011`, and
`R-REPRO-012`, plus `R-REPRO-008` when `include_execution = TRUE`.

## Examples

``` r
d <- file.path(tempdir(), "sub_all")
dir.create(d, showWarnings = FALSE)
writeLines("{}", file.path(d, "renv.lock"))
writeLines("source('a.R')", file.path(d, "run.R"))
writeLines("x <- read.csv('data/adsl.csv')", file.path(d, "a.R"))
ev <- suppressMessages(assess_reproducibility(d))
table(ev$result)
#> 
#> fail pass warn 
#>    1    7    3 
```
