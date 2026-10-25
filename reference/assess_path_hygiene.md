# Assess Path Hygiene

Scans the R and R Markdown scripts for absolute or operating system
specific file paths (Windows drive letters, UNC shares, home directory
references, and absolute POSIX paths). These break in a reviewer's
environment, so any hit is a high severity finding. Returns evidence
with `indicator_id = "R-REPRO-002"`.

## Usage

``` r
assess_path_hygiene(path, ctx = NULL, config = NULL)
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
d <- file.path(tempdir(), "sub002")
dir.create(d, showWarnings = FALSE)
writeLines("x <- read.csv('data/adsl.csv')", file.path(d, "a.R"))
ev <- suppressMessages(assess_path_hygiene(d))
ev$result
#> [1] "pass"
```
