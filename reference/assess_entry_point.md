# Assess Single Entry Point

Checks that the folder provides one obvious script a reviewer can run to
reproduce the analysis (for example `run.R` or `main.R`). Returns
evidence with `indicator_id = "R-REPRO-003"`.

## Usage

``` r
assess_entry_point(path, ctx = NULL, config = NULL)
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
  When `NULL` the default configuration is used.

## Value

A validated evidence table.

## Examples

``` r
d <- file.path(tempdir(), "sub003")
dir.create(d, showWarnings = FALSE)
writeLines("source('a.R')", file.path(d, "run.R"))
ev <- suppressMessages(assess_entry_point(d))
ev$result
#> [1] "pass"
```
