# Assess Hidden Setup Assumptions

Flags dependencies that are invisible to a reviewer: `.Rprofile` or
`.Renviron` files in the folder, environment variables set in code, or
preloaded workspaces ([`load()`](https://rdrr.io/r/base/load.html) of an
`.RData` file). Setting the environment or loading a saved workspace is
a fail; only reading the environment is a warn. Returns evidence with
`indicator_id = "R-REPRO-004"`.

## Usage

``` r
assess_hidden_setup(path, ctx = NULL, config = NULL)
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
d <- file.path(tempdir(), "sub004")
dir.create(d, showWarnings = FALSE)
writeLines("library(dplyr)", file.path(d, "a.R"))
ev <- suppressMessages(assess_hidden_setup(d))
ev$result
#> [1] "pass"
```
