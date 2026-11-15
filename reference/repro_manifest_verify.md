# Verify a Submission Against a File-Hash Manifest

Re-hashes the files currently in a submission folder and compares them
to a manifest captured earlier with
[`repro_manifest()`](https://r4sub.github.io/r4subrepro/reference/repro_manifest.md),
reporting which files are unchanged, modified, added, or removed. This
is how a reviewer confirms that the submission they received matches
what the sponsor recorded, and how a reproduction workflow confirms that
running the analysis did not alter the inputs.

## Usage

``` r
repro_manifest_verify(path, manifest, exclude = NULL)
```

## Arguments

- path:

  Path to the submission's analysis code folder to verify.

- manifest:

  Either a manifest tibble from
  [`repro_manifest()`](https://r4sub.github.io/r4subrepro/reference/repro_manifest.md)
  (with at least `file` and `hash` columns) or a path to a manifest JSON
  file written by
  [`repro_manifest()`](https://r4sub.github.io/r4subrepro/reference/repro_manifest.md).

- exclude:

  Optional character vector of regular expressions matched against each
  current file's relative path; matching files are ignored, as in
  [`repro_manifest()`](https://r4sub.github.io/r4subrepro/reference/repro_manifest.md).
  Use the same `exclude` here as when the manifest was captured.

## Value

An object of class `repro_manifest_check`: a list with `files` (a
[tibble](https://tibble.tidyverse.org/reference/tibble.html) of `file`,
`status`, `expected_hash`, `actual_hash`, one row per file across both
the manifest and the folder, where `status` is `"unchanged"`,
`"modified"`, `"added"`, or `"removed"`), the counts `n_total`,
`n_unchanged`, `n_modified`, `n_added`, `n_removed`, and `ok` (`TRUE`
when every manifested file is present and unchanged and nothing was
added). It has a print method.

## Details

This is an integrity helper, not an indicator. It emits no R4SUB
evidence and does not change the pass/fail or score of any indicator.
When the manifest was written into the folder being verified, that
manifest file is excluded from the comparison automatically so it is not
reported as an addition.

## See also

[`repro_manifest()`](https://r4sub.github.io/r4subrepro/reference/repro_manifest.md)
to capture a manifest.

## Examples

``` r
d <- file.path(tempdir(), "sub_verify")
dir.create(d, showWarnings = FALSE)
writeLines("source('a.R')", file.path(d, "run.R"))
writeLines("x <- 1", file.path(d, "a.R"))
mf <- repro_manifest(d)

# Unchanged folder verifies clean
chk <- repro_manifest_verify(d, mf)
chk$ok
#> [1] TRUE

# Modify a file and re-verify
writeLines("x <- 2", file.path(d, "a.R"))
repro_manifest_verify(d, mf)
#> 
#> ── R4SUB File Manifest Verification ──
#> 
#> Files checked: 2 | Algorithm: "md5"
#> ! 1 unchanged, 1 modified, 0 added, 0 removed.
#> modified: a.R
```
