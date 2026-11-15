# Detailed Path-Hygiene Report

Produces a line-by-line report of the absolute or non-portable file
paths in a submission's scripts, as a companion to the
[`assess_path_hygiene()`](https://r4sub.github.io/r4subrepro/reference/assess_path_hygiene.md)
indicator (`R-REPRO-002`). Where that indicator returns a single
pass/fail evidence row with a count, this function returns a tidy table
naming every offending path: the file and line it appears on, the
category of non-portability, the path text itself, and an advisory
suggested relative-path rewrite.

## Usage

``` r
path_hygiene_report(path)
```

## Arguments

- path:

  Path to the submission's analysis code folder.

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) with one
row per offending path and the columns `file` (path relative to `path`,
with forward slashes), `line` (line number, integer), `type` (the
category of non-portability), `path` (the offending path text), and
`suggestion` (an advisory relative-path rewrite, or `NA` when none could
be derived). A submission with clean paths returns a zero-row tibble
with these columns.

## Details

This is a descriptive helper, not an indicator. It emits no R4SUB
evidence, carries no severity, and does not change the pass/fail or
score of
[`assess_path_hygiene()`](https://r4sub.github.io/r4subrepro/reference/assess_path_hygiene.md)
in any way. The suggested rewrites are advisory starting points for
making a path portable, not guaranteed replacements.

Each row's `type` is one of `"windows_drive"` (a drive-letter path such
as `C:/...`), `"unc_share"` (a `\\server\share` UNC path), `"home_dir"`
(a `~` home-directory reference), or `"posix_absolute"` (an absolute
POSIX path such as `/home/...`). Only quoted string literals are
inspected, and strings that look like URLs are ignored.

## See also

[`assess_path_hygiene()`](https://r4sub.github.io/r4subrepro/reference/assess_path_hygiene.md)
for the pass/fail indicator.

## Examples

``` r
d <- file.path(tempdir(), "sub_hygiene")
dir.create(d, showWarnings = FALSE)
writeLines(c(
  "adsl <- read.csv('C:/Users/me/study/data/adsl.csv')",
  "adae <- read.csv('/home/me/study/adae.csv')",
  "home <- readRDS('~/cache/model.rds')",
  "ok   <- read.csv('data/adlb.csv')"
), file.path(d, "analysis.R"))
path_hygiene_report(d)
#> # A tibble: 3 × 5
#>   file        line type           path                            suggestion   
#>   <chr>      <int> <chr>          <chr>                           <chr>        
#> 1 analysis.R     1 windows_drive  C:/Users/me/study/data/adsl.csv data/adsl.csv
#> 2 analysis.R     2 posix_absolute /home/me/study/adae.csv         adae.csv     
#> 3 analysis.R     3 home_dir       ~/cache/model.rds               model.rds    
```
