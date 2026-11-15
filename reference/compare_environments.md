# Compare Two Computational Environment Snapshots

Diffs two environment snapshots from
[`capture_environment()`](https://r4sub.github.io/r4subrepro/reference/capture_environment.md)
and reports what changed between them: whether the R version, platform,
operating system, or locale differ, and which packages were added,
removed, or changed version. This is how a reviewer, or the sponsor
before submission, checks that a reproduction environment matches the
one that produced the submitted results, and pinpoints the exact
software differences when results diverge.

## Usage

``` r
compare_environments(x, y, labels = c("x", "y"))
```

## Arguments

- x, y:

  Two environments to compare, each either a `repro_environment` object
  from
  [`capture_environment()`](https://r4sub.github.io/r4subrepro/reference/capture_environment.md)
  or a path to a snapshot JSON file written by it. `x` is the baseline
  and `y` the comparison.

- labels:

  Optional character vector of two short names for `x` and `y` used in
  the printed output and the version columns. Defaults to `c("x", "y")`.

## Value

An object of class `repro_environment_diff`: a list with
`r_version_changed`, `platform_changed`, `os_changed`, and
`locale_changed` (logical flags), each accompanied by `*_x` and `*_y`
values; a `packages`
[tibble](https://tibble.tidyverse.org/reference/tibble.html) with one
row per package across both snapshots (columns `package`, `status` - one
of `"unchanged"`, `"added"`, `"removed"`, `"version_changed"` -
`version_x`, and `version_y`); the counts `n_unchanged`, `n_added`,
`n_removed`, `n_changed`; `labels`; and `identical` (`TRUE` when the R
version and every package match, regardless of platform, OS, or locale).
It has a print method.

## Details

The comparison is directional: `x` is the baseline (for example the
recorded submission environment) and `y` is the comparison (for example
the reviewer's reproduction environment). A package present in `y` but
not `x` is `"added"`; one present in `x` but not `y` is `"removed"`; one
present in both with a different version is `"version_changed"`.

This is a descriptive/integrity helper, not an indicator. It emits no
R4SUB evidence and does not change the pass/fail or score of any
indicator. It reports the differences mechanically and applies no
threshold or judgement about whether a given change matters.

## See also

[`capture_environment()`](https://r4sub.github.io/r4subrepro/reference/capture_environment.md)
to capture a snapshot.

## Examples

``` r
# Two synthetic snapshots (a reproducer would pass real captures)
si1 <- list(
  R.version = list(version.string = "R version 4.4.1 (2024-06-14)"),
  platform  = "x86_64-w64-mingw32/x64",
  otherPkgs = list(dplyr = list(Package = "dplyr", Version = "1.1.4")))
si2 <- list(
  R.version = list(version.string = "R version 4.5.1 (2025-06-13)"),
  platform  = "x86_64-w64-mingw32/x64",
  otherPkgs = list(dplyr = list(Package = "dplyr", Version = "1.1.5")))
d <- compare_environments(capture_environment(si1), capture_environment(si2))
d$r_version_changed
#> [1] TRUE
d$packages
#> # A tibble: 1 × 4
#>   package status          version_x version_y
#>   <chr>   <chr>           <chr>     <chr>    
#> 1 dplyr   version_changed 1.1.4     1.1.5    
```
