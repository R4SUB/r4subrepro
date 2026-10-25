# Assess Clean Run Evidence

Checks that the folder ships proof the analysis was run end to end in a
clean session, such as a
[`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html) capture or a
run log. Its absence is a low severity warn. Returns evidence with
`indicator_id = "R-REPRO-006"`.

## Usage

``` r
assess_clean_run_evidence(path, ctx = NULL, config = NULL)
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
d <- file.path(tempdir(), "sub006")
dir.create(d, showWarnings = FALSE)
writeLines("R version", file.path(d, "sessionInfo.txt"))
ev <- suppressMessages(assess_clean_run_evidence(d))
ev$result
#> [1] "pass"
```
