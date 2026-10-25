# Assess Script Complexity

Reports the deepest brace nesting across the scripts. Deeply nested code
is hard for a reviewer to follow, so exceeding `config$max_script_depth`
is a low severity warn. Returns evidence with
`indicator_id = "R-REPRO-007"`.

## Usage

``` r
assess_script_depth(path, ctx = NULL, config = NULL)
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
d <- file.path(tempdir(), "sub007")
dir.create(d, showWarnings = FALSE)
writeLines("f <- function(x) x + 1", file.path(d, "a.R"))
ev <- suppressMessages(assess_script_depth(d))
ev$result
#> [1] "pass"
```
