# Assess Windows Reviewability

Flags non-portable constructs that can break when a reviewer runs the
code on Windows, which is the FDA reviewer environment. Beyond the
absolute paths that
[`assess_path_hygiene()`](https://r4sub.github.io/r4subrepro/reference/assess_path_hygiene.md)
already catches, this looks for shell-outs
([`system()`](https://rdrr.io/r/base/system.html)/[`system2()`](https://rdrr.io/r/base/system2.html)),
forking (`mclapply` and friends, which do not work on Windows), and
POSIX locations (`/dev/null`, `/tmp/`). Returns evidence with
`indicator_id = "R-REPRO-011"`.

## Usage

``` r
assess_windows_reviewability(path, ctx = NULL, config = NULL)
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
d <- file.path(tempdir(), "sub011")
dir.create(d, showWarnings = FALSE)
writeLines("x <- dplyr::filter(mtcars, mpg > 20)", file.path(d, "a.R"))
ev <- suppressMessages(assess_windows_reviewability(d))
ev$result
#> [1] "pass"
```
