# Capture a File-Hash Manifest of a Submission

Records an integrity manifest of every file in a submission's analysis
code folder: its path (relative to the folder, with forward slashes),
size in bytes, and MD5 hash. The manifest lets a reviewer confirm that
the files they received are byte-for-byte the files the sponsor hashed,
and lets a reproduction run confirm that nothing in the folder changed.
Hashing uses [`tools::md5sum()`](https://rdrr.io/r/tools/md5sum.html),
the same mechanism the output-reproduction check
([`assess_output_reproduction()`](https://r4sub.github.io/r4subrepro/reference/assess_output_reproduction.md))
already uses, so the manifest is deterministic and needs no network
access.

## Usage

``` r
repro_manifest(path, file = NULL, exclude = NULL)
```

## Arguments

- path:

  Path to the submission's analysis code folder.

- file:

  Optional path to write the manifest to as JSON. When supplied, the
  manifest is written there and the path is returned invisibly;
  otherwise the manifest tibble is returned.

- exclude:

  Optional character vector of regular expressions matched against each
  file's relative path. Any file whose path matches is left out of the
  manifest (for example `"\\.log$"` to skip run logs).

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) with one
row per file and the columns `file` (relative path, forward slashes),
`bytes` (size, numeric), `algo` (the hash algorithm, `"md5"`), and
`hash` (the lowercase MD5 digest). When `file` is supplied, the path to
the written JSON manifest is returned invisibly instead. The JSON
document carries a `manifest_type`, a `schema_version`, the generation
time, the algorithm, the source package and version, the folder name,
the file count, and a `files` array.

## Details

This is an integrity helper, not an indicator. It emits no R4SUB
evidence, carries no severity, and does not change the pass/fail or
score of any indicator. Verify a folder against a manifest with
[`repro_manifest_verify()`](https://r4sub.github.io/r4subrepro/reference/repro_manifest_verify.md).

## See also

[`repro_manifest_verify()`](https://r4sub.github.io/r4subrepro/reference/repro_manifest_verify.md)
to check a folder against a manifest.

## Examples

``` r
d <- file.path(tempdir(), "sub_manifest")
dir.create(file.path(d, "data"), recursive = TRUE, showWarnings = FALSE)
writeLines("source('a.R')", file.path(d, "run.R"))
writeLines("x <- read.csv('data/adsl.csv')", file.path(d, "a.R"))
writeLines("usubjid,age\n01,55", file.path(d, "data", "adsl.csv"))

# As a tibble
repro_manifest(d)
#> # A tibble: 3 × 4
#>   file          bytes algo  hash                            
#>   <chr>         <dbl> <chr> <chr>                           
#> 1 a.R              31 md5   629d9c62abc37a13b6627e297ecfa89a
#> 2 data/adsl.csv    18 md5   929c31d1525ecfb112d9cbc10788ed64
#> 3 run.R            14 md5   0b2b1f27969de6de065a65a25dd109f5

# Written to a JSON file
mf <- repro_manifest(d, file = file.path(d, "manifest.json"))
#> ✔ Wrote file manifest (3 files) to /tmp/RtmpXgcl4F/sub_manifest/manifest.json
file.exists(mf)
#> [1] TRUE
```
