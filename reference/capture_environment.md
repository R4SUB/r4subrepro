# Capture the Computational Environment of a Session

Records the software environment of the running R session into a
structured, serializable snapshot: the R version, the platform and
operating system, the locale, and the attached and loaded packages with
their versions. A submission is only reproducible if a reviewer can
recreate the environment that produced it, so capturing that environment
alongside the data and outputs is a core reproducibility concern. This
complements
[`repro_manifest()`](https://r4sub.github.io/r4subrepro/reference/repro_manifest.md),
which hashes the data and output *files*, by recording the *software*
that produced them.

## Usage

``` r
capture_environment(info = NULL, file = NULL)
```

## Arguments

- info:

  A
  [`utils::sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html)-like
  object to capture from. When `NULL` (the default), the running session
  is captured with
  [`utils::sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html).
  Supplying `info` makes capture testable with a synthetic session.

- file:

  Optional path to write the snapshot to as JSON. When supplied, the
  snapshot is written there and the path is returned invisibly;
  otherwise the `repro_environment` object is returned.

## Value

An object of class `repro_environment`: a list with `r_version`,
`platform`, `os`, `locale`, a `packages`
[tibble](https://tibble.tidyverse.org/reference/tibble.html) (columns
`package`, `version`, `attached`), the counts `n_packages` and
`n_attached`, and `captured` (the capture time). When `file` is
supplied, the path to the written JSON snapshot is returned invisibly
instead. The JSON document carries an `env_type`, a `schema_version`,
the capture time, the source package and version, the R version,
platform, OS, locale, the package count, and a `packages` array. It has
a print method.

## Details

The snapshot is read entirely from
[`utils::sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html): the
attached non-base packages (`otherPkgs`) and the loaded-but-not-attached
packages (`loadedOnly`), each with the version
[`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html) reports.
Base packages are omitted because
[`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html) records no
version for them and they track the R version. Capture is robust when
optional fields are absent.

This is a descriptive/integrity helper, not an indicator. It emits no
R4SUB evidence, carries no severity, and does not change the pass/fail
or score of any indicator. Compare two snapshots with
[`compare_environments()`](https://r4sub.github.io/r4subrepro/reference/compare_environments.md).

## See also

[`compare_environments()`](https://r4sub.github.io/r4subrepro/reference/compare_environments.md)
to diff two snapshots, and
[`repro_manifest()`](https://r4sub.github.io/r4subrepro/reference/repro_manifest.md)
for the companion file-hash manifest.

## Examples

``` r
# Capture the current session
env <- capture_environment()
env$r_version
#> [1] "R version 4.6.2 (2026-10-29)"
env$packages
#> # A tibble: 50 × 3
#>    package  version attached
#>    <chr>    <chr>   <lgl>   
#>  1 R6       2.6.1   FALSE   
#>  2 askpass  1.2.1   FALSE   
#>  3 bslib    0.12.0  FALSE   
#>  4 cachem   1.1.0   FALSE   
#>  5 callr    3.8.0   FALSE   
#>  6 cli      3.6.6   FALSE   
#>  7 compiler 4.6.2   FALSE   
#>  8 curl     8.1.0   FALSE   
#>  9 desc     1.4.3   FALSE   
#> 10 digest   0.6.39  FALSE   
#> # ℹ 40 more rows

# Write a portable JSON snapshot
f <- capture_environment(file = file.path(tempdir(), "env.json"))
#> ✔ Wrote environment snapshot (51 packages) to /tmp/RtmpXgcl4F/env.json
file.exists(f)
#> [1] TRUE
```
